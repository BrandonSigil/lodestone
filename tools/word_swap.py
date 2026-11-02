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


def export():
    _, rows = read_rows()
    used = usage([k for _, k, _ in rows])
    data = []
    for _, k, t in rows:
        prefix = "TAGDESC" if k.startswith("TAGDESC_") else k.split("_")[0]
        data.append({
            "k": k, "t": t, "s": SECTIONS.get(prefix, "Other"),
            "u": used[k][:3], "r": is_rules(k),
            "l": bool(re.search(r"lorem|ipsum", t, re.I)), "f": FORMAT.findall(t),
        })
    ROWS.parent.mkdir(parents=True, exist_ok=True)
    ROWS.write_text(json.dumps({"rows": data}, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{len(data)} lines -> {ROWS.relative_to(ROOT)}")


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
