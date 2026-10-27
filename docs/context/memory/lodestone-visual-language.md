---
name: lodestone-visual-language
description: Where and how Lodestone visual ideation happens (style lab artifact, code-drawn visuals, Brandon directs)
metadata:
  type: project
  modified: 2026-10-26T00:38:50.531Z
---

- 2026-10-26 Brandon now wants AI to build much of the visual work while he directs and shapes it. Code-drawn visuals only (shapes, shaders, palettes, stamps); still no image-gen models. This relaxes the earlier "Brandon draws all final art" rule in [[lodestone-tech-direction]]; CLAUDE.md's art rule needs Brandon's own edit (the auto-mode classifier blocks Claude from editing CLAUDE.md).
- Home for visual ideation: the project thread "Shape the Lodestone visual language", around the published "Lodestone Style Lab" artifact https://claude.ai/artifact/Q3D7yYdUAeS9eEs7cS5XsK (source in repo at docs/style-lab/index.html; ref thumbnails embedded only in the artifact, not the repo).
- Draft 1 proposes rules R1-R10, five region palettes blended by strangeness, fixed piece colors, and three bottom-frame candidates (A embroidered band, B quilt row, C foreground sill). Recorded as [AI] in docs/decisions.md and style-bible.md, PR #1 (draft).
- Workflow borrowed from github.com/sevenevesai/riso-windowseat: rule first, hardest picture first, everything a pure function of seed, screenshot checks, write down weaknesses.

- 2026-10-26 Brandon said he doesn't like how the game looks yet. Style lab draft 2 (merged PR #3) names gaps F1-F6 (perfect edges, no single light, uniform grain, one-horizon layout, plain pawns, loud UI) with a before/after village. Pending his pick: richer code only / hybrid where he draws ~30 grayscale parts (recommended) / he paints scene plates. Brandon allows push+merge without asking for now.
- 2026-10-26 Brandon rejected code-only art ("not the route") and asked how AI-built games get good art. Proposed: style LoRA trained on ~15-30 of HIS drawings (not the reference artists), Krita AI Diffusion (free, local, 6GB+ NVIDIA) sketch-to-image, paint-over, code does palette lock/grain/recolor/cutout animation; no gen for anim frames or tilesets. Asked his GPU. This would drop the [USER] 'no AI-generated art ships' rule; record only once he confirms.
- 2026-10-26 Brandon chose the AI pipeline ("let's do it"); recorded [USER] in decisions.md, guide in docs/art-pipeline.md (PR #4). He drops samples/tests in C:\Users\Brand\Claude\lodestone-art\{tests,samples} (approved device folder). Next: he installs Krita + plugin, draws 20-30 samples; Claude builds captions (trigger word lodestonestyle) and a OneTrainer SDXL LoRA config. CLAUDE.md art rule still says never generate art; Claude is blocked from editing CLAUDE.md, Brandon must.

**Why:** Brandon wants cohesive, non-slop visuals he controls without drawing everything himself.
**How to apply:** Change rules or palettes on the style lab and republish the same artifact; port to Godot only after Brandon marks a rule his.
