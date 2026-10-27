---
name: lodestone-tech-direction
description: Lodestone engine and pipeline decisions - Godot 4, 2D hand-drawn Banner Saga look, no AI-generated final art
metadata:
  type: project
  modified: 2026-10-25T19:59:43.180Z
---

- Engine: Godot 4 (GDScript), 2D hand-drawn look like The Banner Saga (Eyvind Earle layered parallax). NOT Unreal/3D. Decided by Brandon 2026-10-25.
- Combat view: 2D isometric grid with height levels (FFT-style), hand-drawn sprites.
- Art rule: Brandon draws every final mark. Claude builds tools that multiply his drawings (shaders, palette-swap, paper-doll assembly, parallax, procedural placement). No AI image gen for final art.
- Workflow plan (2026-10-25 guide): manager session plus per-system sessions, docs/decisions.md with [USER]/[AI] tags ([USER] wins), CLAUDE.md with the no-copy rule, data-driven Resources, graybox first.
- Budget: near-free besides Claude plan (Krita, Godot, Coding-Solo godot-mcp, jsfxr/ChipTone, Audacity, Laigter).
- Guide published as artifact "Lodestone Studio Playbook".

**Why:** Brandon wants bespoke, cohesive, non-slop art he controls, on a cheap budget.
**How to apply:** Default to 2D Godot solutions; never propose AI-generated sprites; keep placeholders caveman-speak per [[MEMORY]].
