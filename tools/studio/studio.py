#!/usr/bin/env python3
"""Lodestone studio: run one asset through its art pipeline from one page.

    ~/.lodestone/venv/bin/python tools/studio/studio.py            # http://127.0.0.1:8765
    ~/.lodestone/venv/bin/python tools/studio/studio.py --fake     # synthetic grids, no Picsart calls

A job is one asset going through one pipeline, one stage at a time:
  grid     Picsart draws a round. This is the only paid step; the page says what it costs.
           Every round is sent with the key art (docs/art/characters/00-reference-sheet.png) as
           image 1, and the style lock is the last thing in the prompt so edits cannot break it.
           An edit round also gets the round it changes as image 2.
  review   you rate the round 1 to 5 against the key art, then approve it, ask for edits, or refine.
           A round rated under 4 refines automatically when you send it (no notes needed).
           Rounds stop at MAX_ROUNDS per job. Every round costs credits; nothing is drawn without a click.
  slicing  the approved grid is cut into one picture per figure, each shown at 48 px (automatic).
  pick     you choose the figure the asset should be.
  added    the pick is written to art/characters/<asset>/reference.png with brief.json.

Jobs live in art/picsart/out/studio/<job>/ (job.json, grid_v<n>.png, prompt_v<n>.txt, figs/, sheet.png).
The studio writes nothing into game/. Turning the reference into sprite sheets (tools/art/char_sheet.py
--cut) is the next paid step and is not run from here yet.
"""

import argparse
import io
import json
import re
import sys
import threading
import time
import unicodedata
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

import numpy as np
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "art"))
from silhouette_check import INK, PAPER, cells, compose, figure, shrink  # noqa: E402
from sampler_check import BANDS, check as sampler_check  # noqa: E402

HERE = Path(__file__).resolve().parent
JOBS = REPO / "art" / "picsart" / "out" / "studio"
CHARS = REPO / "art" / "characters"
LOCK = threading.Lock()
FAKE = False

PIPELINES = {
    "character-single": {
        "label": "Character concept: one character, one picture",
        "prompt": "art/prompts/sheet-character-single.txt",
        "model": "gpt-image-2.5-sunburst",
        "resolution": "1K",
        "aspect": "3:4",
        "cols": 1,
        "rows": 1,
        "lines": 1,
    },
    "character-concept": {
        "label": "Character concept: 8 options on one grid",
        "prompt": "art/prompts/sheet-character-concepts.txt",
        "model": "gpt-image-2.5-sunburst",
        "resolution": "1K",
        "aspect": "3:2",
        "cols": 4,
        "rows": 2,
        "lines": 8,
    },
}
STAGES = ["grid", "review", "slicing", "pick", "added"]
KEY_ART = REPO / "docs" / "art" / "characters" / "00-reference-sheet.png"
MAX_ROUNDS = 4
REFINE_BELOW = 4  # a round rated under this refines by itself when sent
REFINE_NOTE = "Closer to the key art: fix the proportions, camera and flat print finish to match image 1."
STYLE_LOCK = ("STYLE LOCK (applies to every round, after any edits): image 1 is the key art. Match its camera, "
              "proportions and finish: a chibi figure about 2.3 heads tall, big round head, small body; 2:1 "
              "dimetric orthographic camera looking down about 30 degrees, no perspective; flat simple print, one "
              "flat colour per material plus one shadow tone, ink outline #373335, no gradients or painted texture; "
              "cream paper #eae8d6, no floor, scenery or text. Edits change costume, colours, pose and details only. "
              "Camera and proportion always follow image 1.")


class StudioError(Exception):
    def __init__(self, message, code=400):
        super().__init__(message)
        self.code = code


def now():
    return datetime.now().strftime("%H:%M:%S")


def job_dir(job_id):
    return JOBS / job_id


def load_job(job_id):
    path = job_dir(job_id) / "job.json"
    if not path.exists():
        raise StudioError("No job called " + job_id, 404)
    return json.loads(path.read_text(encoding="utf-8"))


def update(job_id, change):
    """Apply change(job) under the lock and save. Never call from inside another update()."""
    with LOCK:
        job = load_job(job_id)
        change(job)
        job["updated"] = time.time()
        (job_dir(job_id) / "job.json").write_text(json.dumps(job, indent=2) + "\n", encoding="utf-8")
        return job


def log(job, text):
    job["log"].append("%s  %s" % (now(), text))


def brief_lines(text, pipe):
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    if len(lines) != pipe["lines"]:
        raise StudioError("The brief needs %d lines, one per character. It has %d." % (pipe["lines"], len(lines)))
    return lines


def build_prompt(pipe, lines, notes):
    """The prompt file with its numbered character lines replaced by this brief, plus any edits."""
    src = (REPO / pipe["prompt"]).read_text(encoding="utf-8").split("\n")
    slots = [i for i, l in enumerate(src) if re.match(r"^\d+: \[", l)]
    if len(slots) != pipe["lines"]:
        raise StudioError("The prompt file has %d character slots, expected %d" % (len(slots), pipe["lines"]), 500)
    briefed = ["%d: %s" % (n, re.sub(r"^\d+:\s*", "", l)) for n, l in enumerate(lines, 1)]
    body = src[: slots[0]] + briefed + src[slots[-1] + 1:]
    prompt = "\n".join(body)
    if notes:
        prompt += ("\n\nART DIRECTOR'S EDITS FOR THIS ROUND (apply them to the matching numbered lines above; "
                   "everything else stays as briefed): " + notes)
    return prompt + "\n\n" + STYLE_LOCK


def fake_grid(pipe, lines):
    """A synthetic grid for testing the flow. Not art, and never sent anywhere."""
    img = Image.new("RGB", (1536, 1024), PAPER)
    draw = ImageDraw.Draw(img)
    cw, ch = 1536 // pipe["cols"], 1024 // pipe["rows"]
    colours = [(92, 130, 96), (158, 92, 70), (70, 110, 140), (170, 140, 60),
               (120, 90, 140), (90, 120, 120), (160, 110, 120), (110, 110, 80)]
    for i in range(len(lines)):
        cx = (i % pipe["cols"]) * cw + cw // 2
        feet = (i // pipe["cols"] + 1) * ch - ch // 10
        body_w, body_h = cw * (0.22 + 0.03 * (i % 3)), ch * (0.28 + 0.04 * (i % 2))
        head_r = ch * (0.10 + 0.01 * (i % 4))
        top = feet - body_h
        draw.rounded_rectangle((cx - body_w / 2, top, cx + body_w / 2, feet), radius=12,
                               fill=colours[i % len(colours)], outline=INK, width=5)
        draw.ellipse((cx - head_r, top - 2 * head_r, cx + head_r, top), fill=(236, 200, 160),
                     outline=INK, width=5)
        if i % 2:
            draw.polygon([(cx - head_r, top - 1.6 * head_r), (cx, top - 3.4 * head_r),
                          (cx + head_r, top - 1.6 * head_r)], fill=colours[(i + 3) % len(colours)], outline=INK)
    return img


def draw_round(job_id):
    """Worker: draw the newest round with Picsart (or the fake grid)."""
    try:
        job = load_job(job_id)
        pipe = PIPELINES[job["pipeline"]]
        rnd = job["rounds"][-1]
        prompt = build_prompt(pipe, job["lines"], rnd["notes"])
        folder = job_dir(job_id)
        (folder / ("prompt_v%d.txt" % rnd["n"])).write_text(prompt, encoding="utf-8")
        if FAKE:
            update(job_id, lambda j: log(j, "Fake mode: drawing a synthetic round, nothing is sent"))
            img, charged = fake_grid(pipe, job["lines"]), 0
        else:
            import requests
            from picsart_render import api_key, generate, upload
            key = api_key()
            refs = [upload(key, Image.open(KEY_ART))]
            if rnd.get("base"):
                refs.append(upload(key, Image.open(folder / ("grid_v%d.png" % rnd["base"]))))
            update(job_id, lambda j: log(j, "Sending round %d to Picsart (%s, %s, %s, %d reference%s). "
                                         "This takes a minute or two."
                                         % (rnd["n"], pipe["model"], pipe["resolution"], pipe["aspect"],
                                            len(refs), "" if len(refs) == 1 else "s")))
            params = {"prompt": prompt, "aspectRatio": pipe["aspect"], "resolution": pipe["resolution"],
                      "count": 1, "imageUrls": refs}
            urls, charged = generate(key, pipe["model"], params)
            img = Image.open(io.BytesIO(requests.get(urls[0], timeout=120).content))
        name = "grid_v%d.png" % rnd["n"]
        img.convert("RGB").save(folder / name)

        def done(j):
            j["rounds"][-1].update(grid=name, charged=charged)
            j["stage"], j["busy"], j["error"] = "review", False, None
            log(j, "Round %d is ready (%dx%d). Approve it or ask for edits." % (rnd["n"], img.width, img.height))
        update(job_id, done)
    except (SystemExit, Exception) as err:
        fail(job_id, err)


def slice_grid(job_id):
    """Worker: cut the approved round into figures and build the 48 px check sheet."""
    try:
        job = load_job(job_id)
        pipe = PIPELINES[job["pipeline"]]
        folder = job_dir(job_id)
        name = job["rounds"][-1]["grid"]
        img = Image.open(folder / name).convert("RGB")
        (folder / "figs").mkdir(exist_ok=True)
        update(job_id, lambda j: log(j, "Slicing %s into %d figures" % (name, pipe["lines"])))
        figs, found = [], []
        for n, cell in enumerate(cells(img, pipe["cols"], pipe["rows"]), 1):
            fig = figure(cell)
            if fig is None:
                found.append({"n": n, "ok": False})
                update(job_id, lambda j, n=n: log(j, "Figure %d: nothing found in its cell" % n))
                continue
            fig.save(folder / "figs" / ("fig_%d.png" % n))
            small = shrink(fig, 48)
            ink = round(float((np.asarray(small.getchannel("A")) > 127).mean()) * 100)
            figs.append((n, small))
            found.append({"n": n, "ok": True, "w": fig.width, "h": fig.height, "ink": ink})
            update(job_id, lambda j, n=n, fig=fig, ink=ink: log(
                j, "Figure %d: cut to %dx%d, %d%% ink at 48 px" % (n, fig.width, fig.height, ink)))
        if not figs:
            raise StudioError("No figures found. Check that the grid is %d x %d." % (pipe["cols"], pipe["rows"]), 500)
        compose(figs, 48, 4).save(folder / "sheet.png")

        def done(j):
            j["figures"], j["stage"], j["busy"], j["error"] = found, "pick", False, None
            log(j, "Sheet ready. Pick the figure this character should be.")
        update(job_id, done)
    except (SystemExit, Exception) as err:
        fail(job_id, err)


def fail(job_id, err):
    message = str(err) or type(err).__name__

    def stop(j):
        j["busy"], j["error"] = False, message
        log(j, "Stopped: " + message)
    update(job_id, stop)


def pick_figure(job_id, n):
    job = load_job(job_id)
    if job["stage"] != "pick":
        raise StudioError("Figures can only be picked at the pick step")
    if not any(f["n"] == n and f["ok"] for f in job["figures"]):
        raise StudioError("Figure %s is not a cut figure in this job" % n)
    out = CHARS / job["asset"]
    out.mkdir(parents=True, exist_ok=True)
    Image.open(job_dir(job_id) / "figs" / ("fig_%d.png" % n)).save(out / "reference.png")
    brief = {"asset": job["asset"], "pipeline": job["pipeline"], "lines": job["lines"],
             "round": job["rounds"][-1]["n"], "picked_figure": n, "job": job_id}
    (out / "brief.json").write_text(json.dumps(brief, indent=2) + "\n", encoding="utf-8")

    def added(j):
        j["stage"], j["picked"] = "added", n
        log(j, "Figure %d written to art/characters/%s/reference.png and brief.json" % (n, job["asset"]))
    update(job_id, added)


def start(target, job_id):
    threading.Thread(target=target, args=(job_id,), daemon=True).start()


def summary(job):
    return {"id": job["id"], "asset": job["asset"], "pipeline": job["pipeline"], "stage": job["stage"],
            "busy": job["busy"], "error": job["error"], "rounds": len(job["rounds"]),
            "updated": job.get("updated", 0)}


def job_list():
    if not JOBS.exists():
        return []
    jobs = [load_job(p.name) for p in JOBS.iterdir() if (p / "job.json").exists()]
    return sorted((summary(j) for j in jobs), key=lambda s: -s["updated"])


SAMPLER_DIR = REPO / "art" / "picsart" / "out" / "key-art-sampler"
SAMPLER_NAME = re.compile(r"^key-art-sampler_v\d+\.png$")
GRADE_KEYS = ("structure", "scale", "camera", "line", "finish", "personality", "fit")
GATE_KEYS = ("structure", "scale", "camera")  # the pass rule in art/prompts/sampler-grade-rubric.md


def sampler_picture(name):
    if not SAMPLER_NAME.match(name) or not (SAMPLER_DIR / name).is_file():
        raise StudioError("No sampler picture called " + name, 404)
    return SAMPLER_DIR / name


def sampler_sidecar(name, kind):
    return SAMPLER_DIR / kind / (name[:-len(".png")] + ".json")


def read_sidecar(name, kind):
    path = sampler_sidecar(name, kind)
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else None


def sampler_check_run(name):
    result = sampler_check(sampler_picture(name))
    path = sampler_sidecar(name, "checks")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def sampler_grade_save(name, body):
    sampler_picture(name)
    grade = {}
    for key in GRADE_KEYS:
        value = body.get(key)
        if not isinstance(value, int) or isinstance(value, bool) or not 1 <= value <= 5:
            raise StudioError("Score %s must be a whole number from 1 to 5" % key)
        grade[key] = value
    evidence = body.get("evidence") or {}
    grade["evidence"] = {key: str(evidence.get(key, ""))[:400] for key in GRADE_KEYS}
    grade["pass"] = all(grade[key] >= 4 for key in GATE_KEYS)
    grade["source"] = str(body.get("source", "fresh reviewer"))[:80]
    path = sampler_sidecar(name, "grades")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(grade, indent=2) + "\n", encoding="utf-8")
    return grade


def sampler_list():
    names = sorted(SAMPLER_DIR.glob("key-art-sampler_v*.png"),
                   key=lambda p: int(re.search(r"_v(\d+)", p.name).group(1)))
    rows = []
    for path in names:
        checks, grade = read_sidecar(path.name, "checks"), read_sidecar(path.name, "grades")
        checks_ok = bool(checks) and all(v is True for v in checks["pass"].values() if v is not None)
        rows.append({"name": path.name, "checks": checks, "grade": grade,
                     "ready": checks_ok and bool(grade and grade["pass"])})
    return rows


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send_body(self, code, data, ctype):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def send_json(self, code, obj):
        self.send_body(code, json.dumps(obj).encode("utf-8"), "application/json")

    def read_json(self):
        length = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(length) or b"{}")

    def do_GET(self):
        path = urlparse(self.path).path
        try:
            if path == "/":
                return self.send_body(200, (HERE / "index.html").read_bytes(), "text/html; charset=utf-8")
            if path == "/sampler":
                return self.send_body(200, (HERE / "sampler.html").read_bytes(), "text/html; charset=utf-8")
            if path == "/api/sampler":
                return self.send_json(200, {"pictures": sampler_list(), "bands": BANDS, "gate": list(GATE_KEYS)})
            if path.startswith("/sampler-img/"):
                return self.send_body(200, sampler_picture(path.split("/")[2]).read_bytes(), "image/png")
            if path == "/api/state":
                return self.send_json(200, {"pipelines": {k: v["label"] for k, v in PIPELINES.items()},
                                            "pipelineLines": {k: v["lines"] for k, v in PIPELINES.items()},
                                            "jobs": job_list(), "fake": FAKE, "maxRounds": MAX_ROUNDS})
            if path == "/key-art.png":
                return self.send_body(200, KEY_ART.read_bytes(), "image/png")
            if path.startswith("/api/jobs/"):
                return self.send_json(200, load_job(path.split("/")[3]))
            if path.startswith("/files/"):
                target = (JOBS / path[len("/files/"):]).resolve()
                if JOBS.resolve() in target.parents and target.is_file():
                    return self.send_body(200, target.read_bytes(), "image/png")
            self.send_json(404, {"error": "not found"})
        except StudioError as err:
            self.send_json(err.code, {"error": str(err)})

    def do_POST(self):
        path = urlparse(self.path).path
        try:
            body = self.read_json()
            if path.startswith("/api/sampler/"):
                parts = path.split("/")  # ["", "api", "sampler", <name>, <action>]
                if len(parts) == 5 and parts[4] == "check":
                    return self.send_json(200, sampler_check_run(parts[3]))
                if len(parts) == 5 and parts[4] == "grade":
                    return self.send_json(200, sampler_grade_save(parts[3], body))
                return self.send_json(404, {"error": "not found"})
            if path == "/api/jobs":
                return self.send_json(200, create_job(body))
            parts = path.split("/")
            if len(parts) == 5 and parts[1:3] == ["api", "jobs"]:
                job_id, action = parts[3], parts[4]
                if action == "review":
                    return self.send_json(200, review(job_id, body))
                if action == "pick":
                    pick_figure(job_id, int(body.get("n", 0)))
                    return self.send_json(200, load_job(job_id))
                if action == "retry":
                    return self.send_json(200, retry(job_id))
                if action == "rate":
                    return self.send_json(200, rate(job_id, body))
            self.send_json(404, {"error": "not found"})
        except StudioError as err:
            self.send_json(err.code, {"error": str(err)})
        except (ValueError, KeyError, TypeError) as err:
            self.send_json(400, {"error": str(err)})


def working_title(name):
    """The internal file id for a character name: lower_snake, unique against art/characters/.
    The name itself is never saved or sent anywhere; only this slug is."""
    folded = unicodedata.normalize("NFKD", str(name)).encode("ascii", "ignore").decode("ascii")
    slug = re.sub(r"[^a-z0-9]+", "_", folded.lower()).strip("_")
    if not slug or not slug[0].isalpha():
        raise StudioError("Start the character name with a letter (letters and digits only, the rest becomes _)")
    candidate, n = slug, 2
    while (CHARS / candidate).exists():
        candidate, n = "%s_%d" % (slug, n), n + 1
    return candidate


def create_job(body):
    asset = working_title(body.get("name", ""))
    pipe = PIPELINES.get(body.get("pipeline"))
    if pipe is None:
        raise StudioError("Unknown pipeline")
    lines = brief_lines(str(body.get("brief", "")), pipe)
    job_id = "%s-%s" % (asset, datetime.now().strftime("%Y%m%d-%H%M%S"))
    job_dir(job_id).mkdir(parents=True)
    job = {"id": job_id, "asset": asset, "pipeline": body["pipeline"], "lines": lines,
           "rounds": [{"n": 1, "notes": "", "grid": None, "charged": None, "match": None, "base": None}],
           "stage": "grid", "busy": True, "error": None, "figures": [], "picked": None,
           "log": [], "updated": time.time()}
    log(job, "Job started: %d characters, round 1" % len(lines))
    (job_dir(job_id) / "job.json").write_text(json.dumps(job, indent=2) + "\n", encoding="utf-8")
    start(draw_round, job_id)
    return job


def rate(job_id, body):
    """Rate a round 1 to 5 against the key art. The rating is the only input to the refine step."""
    n, stars = int(body.get("n", 0)), int(body.get("stars", 0))
    if not 1 <= stars <= 5:
        raise StudioError("Rate the round from 1 to 5")
    job = load_job(job_id)
    if job["stage"] != "review" or job["busy"]:
        raise StudioError("Rate a round while the job is waiting for a review", 409)
    if not any(r["n"] == n and r["grid"] for r in job["rounds"]):
        raise StudioError("Round %s has no picture to rate" % n)

    def set_match(j):
        for r in j["rounds"]:
            if r["n"] == n:
                r["match"] = stars
        log(j, "Round %d rated %d of 5 against the key art" % (n, stars))
    return update(job_id, set_match)


def review(job_id, body):
    job = load_job(job_id)
    if job["stage"] != "review" or job["busy"]:
        raise StudioError("This job is not waiting for a review", 409)
    if body.get("decision") == "approve":
        update(job_id, lambda j: (j.update(stage="slicing", busy=True), log(j, "Round %d approved" % j["rounds"][-1]["n"])))
        start(slice_grid, job_id)
    elif body.get("decision") == "edit":
        if len(job["rounds"]) >= MAX_ROUNDS:
            raise StudioError("This job has used its %d rounds. Approve the closest one, or start a new brief." % MAX_ROUNDS, 409)
        last = job["rounds"][-1]
        notes = str(body.get("notes", "")).strip()
        if last.get("match") is not None and last["match"] < REFINE_BELOW:
            notes = (REFINE_NOTE + " " + notes).strip()
        if not notes:
            raise StudioError("Rate the round, or say what to change, before asking for edits")

        def next_round(j):
            n = len(j["rounds"]) + 1
            j["rounds"].append({"n": n, "notes": notes, "grid": None, "charged": None,
                                "match": None, "base": last["n"]})
            j.update(stage="grid", busy=True)
            log(j, "Round %d will use round %d as image 2 and these edits: %s" % (n, last["n"], notes))
        update(job_id, next_round)
        start(draw_round, job_id)
    else:
        raise StudioError("Decision must be approve or edit")
    return load_job(job_id)


def retry(job_id):
    job = load_job(job_id)
    if not job["error"] or job["busy"]:
        raise StudioError("Nothing to retry", 409)
    update(job_id, lambda j: (j.update(busy=True, error=None), log(j, "Retrying")))
    start(draw_round if job["stage"] == "grid" else slice_grid, job_id)
    return load_job(job_id)


def main():
    global FAKE
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--fake", action="store_true", help="synthetic grids, no Picsart calls")
    args = ap.parse_args()
    FAKE = args.fake
    JOBS.mkdir(parents=True, exist_ok=True)
    for summary_row in job_list():
        if summary_row["busy"]:
            update(summary_row["id"], lambda j: (j.update(busy=False, error="The studio restarted during this step; retry it"),
                                                  log(j, "Studio restarted during a step")))
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print("Lodestone studio at http://127.0.0.1:%d%s" % (args.port, "  (fake mode: no Picsart calls)" if FAKE else ""))
    server.serve_forever()


if __name__ == "__main__":
    main()
