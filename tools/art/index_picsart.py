#!/usr/bin/env python3
"""Index every Picsart output in one place: art/picsart/out/INDEX.md.

Groups files by batch (their subfolder, or the name before the version suffix for loose files), with size,
date and whether git tracks them. Run after a generation batch:
    python3 tools/art/index_picsart.py
Standard library only.
"""
import datetime
import os
import re
import subprocess

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "art", "picsart", "out")


def tracked_set() -> set:
    res = subprocess.run(["git", "-C", ROOT, "ls-files", "art/picsart/out"], capture_output=True, text=True)
    return set(res.stdout.split("\n"))


def batch_of(rel: str) -> str:
    parts = rel.split("/")
    if len(parts) > 1:
        return parts[0]
    stem = re.sub(r"(_v\d+.*|_raw|_clipped|_compare|-\d+k)?\.png$", "", parts[0])
    return stem


def main() -> None:
    tracked = tracked_set()
    rows = []
    for dirpath, _dirs, files in os.walk(OUT):
        for name in files:
            if name in ("INDEX.md", ".DS_Store"):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, OUT)
            st = os.stat(full)
            rows.append({
                "batch": batch_of(rel),
                "path": rel,
                "kb": st.st_size // 1024,
                "date": datetime.date.fromtimestamp(st.st_mtime).isoformat(),
                "tracked": "yes" if ("art/picsart/out/" + rel) in tracked else "no",
            })
    rows.sort(key=lambda r: (r["batch"], r["path"]))
    lines = [
        "# Picsart outputs",
        "",
        "Every generated picture, grouped by batch. Generated on this Mac; git ignores the folder.",
        "The batch log with prompts and approval status is docs/art/ART-LOG.md.",
        "",
        f"{len(rows)} files, {sum(r['kb'] for r in rows) // 1024} MB.",
        "",
        "| Batch | File | KB | Date | In git |",
        "| --- | --- | ---: | --- | --- |",
    ]
    for r in rows:
        lines.append(f"| {r['batch']} | {r['path']} | {r['kb']} | {r['date']} | {r['tracked']} |")
    with open(os.path.join(OUT, "INDEX.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"indexed {len(rows)} files into {os.path.relpath(os.path.join(OUT, 'INDEX.md'), ROOT)}")


if __name__ == "__main__":
    main()
