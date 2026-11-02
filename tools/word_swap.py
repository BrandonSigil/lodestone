#!/usr/bin/env python3
"""Word Swap: Brandon's page for replacing placeholder text (docs/systems/word-swap.md).

  word_swap.py export          game/text/placeholder.csv -> tools/word-swap/rows.json (what the page lists)
  word_swap.py apply SWAPS     write Brandon's sent lines into placeholder.csv; SWAPS is a folder of
                               ArtifactData JSON dumps (swaps/<KEY>.json) or one JSON list of {key, new}

Only the swapped lines change; every other line of the CSV stays byte for byte.
"""
import csv
import io
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV = ROOT / "game/text/placeholder.csv"
ROWS = ROOT / "tools/word-swap/rows.json"
SCAN = ["game/scripts", "game/data", "game/scenes"]

# Key prefix -> the section name the page shows. Labels for Brandon, not game text.
SECTIONS = {
    "GAME": "Title", "UI": "Menus and buttons", "LOG": "Logs", "TIP": "Tooltips",
    "EV": "Road events", "OPT": "Choices", "CHECK": "Checks", "TALK": "Talk", "BOND": "Friends talk",
    "MAYOR": "Mayor", "QUEST": "Quests", "SHOP": "Shop", "TEAM": "Party",
    "CHAR": "Characters", "CLASS": "Classes", "JOB": "Jobs", "EVO": "Class paths",
    "ENEMY": "Foes", "FOE": "Foe kinds",
    "SKILL": "Ability names", "DESC": "Ability rules", "ACT": "Actions", "TRAIT": "Traits",
    "TAG": "Statuses", "TAGDESC": "Status rules", "MOD": "Stats", "ELEM": "Elements", "FIELD": "Field effects",
    "MORALE": "Morale", "BOON": "Boons", "UNLOCK": "Unlocks",
    "ITEM": "Items", "CITEM": "Fight items", "RES": "Supplies", "SLOT": "Supplies", "GRADE": "Grades",
    "EX": "Exploring", "CONTAINER": "Containers", "FISH": "Fishing", "MEAL": "Meals",
    "VIL": "Village", "BUILDING": "Village", "RESTORE": "Village", "WN": "World map", "MAP": "World map",
}
FORMAT = re.compile(r"%(?:[-+ 0#]*\d*(?:\.\d+)?[sdif])")


def read_rows():
    """[(line index, key, text)] for every data line, with stray unquoted commas folded back into the text."""
    lines = CSV.read_text(encoding="utf-8").split("\n")
    out = []
    for i, line in enumerate(lines[1:], start=1):
        if not line.strip():
            continue
        cells = next(csv.reader([line]))
        out.append((i, cells[0], ",".join(cells[1:])))
    return lines, out


def is_rules(key):
    # Rules text is plain English by Brandon's call (CLAUDE.md); everything else is a placeholder.
    return key.startswith(("DESC_", "TAGDESC_", "TIP_")) or key.endswith("_DESC")


def usage(keys):
    found = {k: [] for k in keys}
    pat = re.compile(r"\b(" + "|".join(sorted(map(re.escape, keys), key=len, reverse=True)) + r")\b")
    for folder in SCAN:
        for f in sorted((ROOT / folder).rglob("*")):
            if f.suffix not in (".gd", ".tres", ".tscn", ".csv", ".json") or not f.is_file():
                continue
            name = f.stem.replace("_", " ")
            for k in set(pat.findall(f.read_text(encoding="utf-8", errors="ignore"))):
                if name not in found[k]:
                    found[k].append(name)
    return found


# Story and dialogue stay Brandon's ([USER] 2026-11-02); names go with them. Everything else is game text we write.
SPEECH = ("TALK_", "BOND_", "MAYOR_", "QUEST_", "SHOP_", "TEAM_")
NAMES = ("CHAR_", "ENEMY_", "WN_", "VIL_", "BUILDING_", "GAME_TITLE", "MAP_TITLE")
EVENT_TABLES = [("events.csv", "Road events (old trail)"), ("travel_events.csv", "Road events"),
                ("explore_events.csv", "Exploring")]
CHECK_WORDS = {"sneak": "Sneak", "nerve": "Nerve", "persuade": "Talk", "tame": "Animals", "masonry": "Masonry",
               "wayfind": "Wayfinding", "forage": "Forage"}
EFFECT_WORDS = {
    "open": "opens it", "noise": "makes noise", "remove": "it's used up", "ambushed": "foes get the first move",
    "dismiss": "closes the box", "sneak_attack": "you start the fight with a sneak hit", "exit": "leaves the map",
    "pacify": "the foes calm down", "reveal": "shows something hidden", "sleep": "everyone rests",
    "pass": "you get through", "fight": "a fight starts",
}


def effect_words(spec):
    out = []
    for tok in filter(None, (spec or "").split(";")):
        name, _, val = tok.partition(":")
        if name in EFFECT_WORDS:
            out.append(EFFECT_WORDS[name])
        elif name in ("food", "gold", "medicine", "wood", "metal", "rope", "herb", "fish", "ingredient", "rare"):
            out.append(f"{val} {name}")
        elif name == "hp_one":
            out.append(f"one member {val} HP")
        elif name == "hp_all":
            out.append(f"everyone {val} HP")
        elif name == "morale":
            out.append(f"everyone {val} morale")
        elif name == "combat":
            out.append(f"a fight ({val.replace('_', ' ')})")
        elif name == "dist":
            out.append(f"{val} road distance")
        elif name == "day":
            out.append(f"{val} day")
        elif name in ("unlock", "flag"):
            out.append(f"remembers {val.replace('_', ' ')}")
        elif name in ("invite", "rescue"):
            out.append(f"{name}s {val.replace('_', ' ')}")
        else:
            out.append(tok.replace("_", " "))
    return ", ".join(out)


def need_words(spec):
    out = []
    for tok in filter(None, (spec or "").split(";")):
        name, _, val = tok.partition(":")
        val = val.replace("_", " ")
        out.append({"skill": f"needs someone with {val}", "class": f"needs a {val}", "item": f"needs a {val}",
                    "noitem": f"only without a {val}", "flag": f"only after {val}", "noflag": f"only before {val}",
                    "party": f"only with {val} in the party", "noparty": f"only without {val} in the party",
                    "talk": "only once talking is earned"}.get(name, tok))
    return ", ".join(out)


def dialogues():
    out = []
    for fname, where in EVENT_TABLES:
        for r in csv.DictReader((ROOT / "game/data" / fname).open(newline="", encoding="utf-8")):
            opts = []
            for i in range(1, 6):
                key = r.get(f"opt{i}_key")
                if not key:
                    continue
                check, dc = r.get(f"opt{i}_check") or "none", r.get(f"opt{i}_dc") or "0"
                roll = "" if check in ("none", "fight") else f"roll {CHECK_WORDS.get(check, check)} against {dc}"
                win, lose = effect_words(r.get(f"opt{i}_win")), effect_words(r.get(f"opt{i}_lose"))
                does = (f"{roll}. Pass: {win or 'nothing'}. Fail: {lose or 'nothing'}" if roll
                        else (win or "nothing happens"))
                opts.append({"k": key, "need": need_words(r.get(f"opt{i}_need")), "does": does})
            out.append({"id": r["id"], "where": where, "k": r["text_key"], "o": opts,
                        "p": bool(r.get("portrait")), "box": r.get("box") or ""})
    return out


def group(key, story_keys):
    if key in story_keys or key.startswith(SPEECH):
        return "story"
    if key.startswith(NAMES):
        return "name"
    return "game"


def export():
    _, rows = read_rows()
    used = usage([k for _, k, _ in rows])
    talks = dialogues()
    story_keys = {d["k"] for d in talks} | {o["k"] for d in talks for o in d["o"]}
    data = []
    for _, k, t in rows:
        prefix = "TAGDESC" if k.startswith("TAGDESC_") else k.split("_")[0]
        data.append({
            "k": k, "t": t, "s": SECTIONS.get(prefix, "Other"),
            "u": used[k][:3], "r": is_rules(k), "g": group(k, story_keys),
            "l": bool(re.search(r"lorem|ipsum", t, re.I)), "f": FORMAT.findall(t),
        })
    ROWS.parent.mkdir(parents=True, exist_ok=True)
    ROWS.write_text(json.dumps({"rows": data, "talks": talks}, ensure_ascii=False, separators=(",", ":")),
                    encoding="utf-8")
    print(f"{len(data)} lines, {len(talks)} dialogues -> {ROWS.relative_to(ROOT)}")


def csv_line(key, text):
    buf = io.StringIO()
    csv.writer(buf, lineterminator="").writerow([key, text])
    return buf.getvalue()


def load_swaps(src):
    p = Path(src)
    docs = [json.loads(f.read_text()) for f in sorted(p.rglob("*.json"))] if p.is_dir() else json.loads(p.read_text())
    swaps = []
    for d in docs:
        d = d.get("data", d)
        if d.get("status", "sent") == "sent" and d.get("key") and isinstance(d.get("new"), str):
            swaps.append((d["key"], d["new"]))
    return swaps


def apply(src):
    lines, rows = read_rows()
    where = {k: (i, t) for i, k, t in rows}
    done, bad = [], []
    for key, new in load_swaps(src):
        new = " ".join(new.split())  # one line in the table
        if key not in where:
            bad.append(f"{key}: no such key")
            continue
        i, old = where[key]
        if sorted(FORMAT.findall(new)) != sorted(FORMAT.findall(old)):
            bad.append(f"{key}: the % marks changed ({FORMAT.findall(old)} -> {FORMAT.findall(new)})")
            continue
        lines[i] = csv_line(key, new)
        done.append(key)
    CSV.write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({"applied": done, "refused": bad}, indent=1))


if __name__ == "__main__":
    if sys.argv[1:2] == ["export"]:
        export()
    elif sys.argv[1:2] == ["apply"] and len(sys.argv) == 3:
        apply(sys.argv[2])
    else:
        sys.exit(__doc__)
