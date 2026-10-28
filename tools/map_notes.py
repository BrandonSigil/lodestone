#!/usr/bin/env python3
"""List everything Brandon has named or annotated in the map maker, across every map.

Placeholder blobs (what art is still owed), interactables with their ids, events and notes, and props that
carry an id or a note. This is what Claude reads when Brandon says "door_01 on goblin_cave_01 should..." or
"make art for the Lich king throne blob".

Usage: python3 tools/map_notes.py [map name filter]
"""
import glob
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
ART = os.path.join(ROOT, "art", "source", "battle")


def main() -> None:
    want = sys.argv[1] if len(sys.argv) > 1 else ""
    files = sorted(glob.glob(os.path.join(ROOT, "data", "explore", "*.json")) + glob.glob(os.path.join(ROOT, "data", "maps", "*.json")))
    for path in files:
        kind = "explore" if os.sep + "explore" + os.sep in path else "maps"
        name = os.path.splitext(os.path.basename(path))[0]
        if want and want not in name:
            continue
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        grid = data.get("grid") or data.get("map") or {}
        lines = []
        for p in grid.get("props", []):
            cell = "%d,%d" % tuple(p["cell"])
            if p.get("blob"):
                art = "art found" if os.path.exists(os.path.join(ART, p["sprite"] + ".png")) else "art owed: art/source/battle/%s.png" % p["sprite"]
                lines.append("  blob  %-24s %s  %dx%d  %s%s" % ('"%s"' % p.get("name", ""), cell, p["foot"][0], p["foot"][1], art,
                                                            ("\n        note: " + p["note"]) if p.get("note") else ""))
            elif p.get("id") or p.get("note"):
                lines.append("  prop  %-24s %s  %s%s" % (p.get("id", "-"), cell, p["sprite"], ("\n        note: " + p["note"]) if p.get("note") else ""))
        for t in data.get("things", []):
            if not (t.get("note") or kind == "explore"):
                continue
            extra = (" -> %s at %s" % (t.get("to"), t.get("at"))) if t.get("kind") == "enter" and t.get("to") else ""
            lines.append("  %-5s %-24s %d,%d  event %s%s%s" % (t.get("kind", "?"), t.get("id", "?"), t["cell"][0], t["cell"][1],
                                                        t.get("event") or "(none)", extra, ("\n        note: " + t["note"]) if t.get("note") else ""))
        if lines:
            print("%s/%s" % (kind, name))
            print("\n".join(lines))
            print()


if __name__ == "__main__":
    main()
