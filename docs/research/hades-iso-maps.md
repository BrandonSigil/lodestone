# Hades look for battle maps: research and proposals

Status: **research, 2026-10-27.** Nothing here is a decision. Items marked **[AI]** are proposals; items marked **Question** need Brandon's call and get a `[USER]` or `[AI]` line in `docs/decisions.md` only after he answers.

Source quality: the Hades (2020) sources are interviews and credits, with almost no technical content. Sources for Hades II were nearly empty in search (the CreativeBloq piece returned headline only; Game Informer is a video with no transcript). Anything about the Hades II room backdrops below is **unverified**: it comes from play observation, not a source.

## 1. What Hades actually does (sourced)

- **Pen and ink over paint.** The team first planned a painterly look, then switched to pen and ink when tone changed in preproduction. Jen Zee says pen and ink was much faster for the asset count. Influences named: Mike Mignola and Fred Taylor. ([MCV/DEVELOP, 2021](https://mcvuk.com/business-news/behind-the-art-of-hades-we-value-artistic-integrity-and-excellence-in-artistic-craft-at-supergiant-however-were-first-and-foremost-a-game-design-lead-team/))
- **Production scale and tools.** About 1,400 environment textures and 68 models. 2D assets in Photoshop; 3D in Maya, post in After Effects. (MCV/DEVELOP, same source)
- **Shadows.** Pure black is used on characters and, per Pointnthink's reading, also on environments. Shadows also shift hue. ([Pointnthink](https://www.pointnthink.fr/en/the-art-of-hades-en/)) This conflicts with our rule R5 (no black). See Question 2.
- **Saturated touches on flat areas.** Bright, sometimes acidic highlights follow silhouettes, and saturated spots break up large flat fields. (Pointnthink)
- **Line.** A fan study of Hades portraits finds fixed-width line with no taper, one saturated focus colour per character, and hue-shifted terminator lines. ([Kymira](https://kymira.bearblog.dev/style-study-hades/)) This is a character study, not environments, but it matches our B14 line-weight rule.
- **Arena edge.** One source says the edge of each arena is plunged into total darkness (Pointnthink, Asphodel section). This is the only sourced fact about the edge of a fight space, and it is the strongest match to the idea of a backdrop around the floor.
- **Credits.** Joanne Tran is the environment artist for the underworld regions; Jen Zee is art director. ([Supergiant on X](https://x.com/supergiantgames/status/1310980505978855425), [Kotaku](https://kotaku.com/the-art-of-hades-1845420064))

Not found in any source: how the room backdrop is painted, how the floor boundary is built, and any camera or projection details. Hades' camera is a fixed, angled view with no quarter-turn; that is from play, not a source.

## 2. The ring around the map (your observation)

What you described: the playable isometric floor sits inside a larger painted scene that keeps going past its edge (columns, statues, gates, distant architecture), instead of an island on a flat gradient. Against the FFT-style island on blue gradient, that is a better stage because the floor reads as a lit place inside a world.

Consequences for us:

1. **The ring fights the island-on-paper staging.** The current direction (decisions, 2026-10-26 `[USER]`: "a floating island on cream paper") and the battle-map doc's section 1 both put the island on paper with no horizon. A painted ring changes that. **Question 1: keep the island on paper, or move to a painted ring?** Recommended: ring for the Earth-side regions, paper kept for the tester and the sandbox.
2. **Our camera turns in quarter steps** (decisions, 2026-10-26, `Q`). A painted ring that reads well from one angle breaks from another. Options:
   - **[AI] Four backdrop plates**, one per quarter turn, swapped with the camera. Costs four times the paint.
   - **[AI] A ring that is symmetric on four sides** (same architecture repeated at each corner, rotated). Cheaper, but the repetition shows.
   - **[AI] A lower ring, 2 to 3 levels tall, that reads as ground-level scenery** and never shows its face at a steep angle.
   Recommend the third first: it is the least work and it matches B4's rule that nothing walkable straddles a cell.
3. **Edge treatment.** Use the sourced darkness at the rim: the floor's last cells fade into a dark tint of the region's hue (style bible R5: a deep tint, never black), with the ring's architecture sitting in that dark. This also solves the "island cliffs drop into the paper" problem from B9.
4. **Fixed, not parallax.** Orthographic camera (B2) means the backdrop should not parallax on its own; it moves only with the quarter turns. Keep the ring as one flat layer behind the board, under the riso grain.

## 3. Handpainted look: what to adapt

Our rules already match much of Hades' method (pen-line discipline, flat planes, saturated accents). What to change or add:

- **[AI] Pen line on stone, paint on top.** Keep B14's line weights. Put ink-pen joint lines on stone blocks (a Mignola-style hatch on the shade face, not a gradient), and keep the fill flat. This is the one change that gets the "drawn" look without rendering. It supports R4 (marks, not rendering).
- **[AI] Hue-shifted shadows, not black.** Shade faces shift toward the region's cool hue and drop value (B11, B12 already say this). Keep the value numbers; do not add black. See Question 2 for the exception.
- **[AI] Saturated accent per material.** One saturated spot per top (a flower patch, lichen, a lit brazier). Hades does this on flat fields. Matches R8 and B20.
- **[AI] Silhouette-following highlights.** The bright rim on tops (B20) should follow the top's outline, not a flat band. Cheap to paint on the top sprites.
- **[AI] Hand-cut edges only where they read.** Hades is sharp on silhouettes. Keep F1 wobble on moss lips and props, but keep block edges straight (B15 already says this).

## 4. Walls around maps

Three separate jobs: the rim of the playable board, the walls inside a map, and walls that block the view of the pieces.

**Rim (the edge of the board).** Already in the decisions: stacked rock columns below the base, falling stones, mist (2026-10-27). Add:
- **[AI] Cliff pieces that tile.** Hand-drawing one long cliff smears. Draw each cliff as a set of modular pieces whose left and right edges match, plus corner and end caps (general practice seen in search snippets; the full posts were not read, and none is Hades-specific). Use alpha fades on the top and bottom of the cliff strip so it blends into the ground.
- **[AI] A dark ring behind the rim** (section 2 above), so the rim reads as the edge of a lit stage.

**Interior walls (ruin walls, interior back walls).** Already rules: ruin walls impassable and block sight two levels (decisions 2026-10-26); interiors use two-level back walls and one-level front walls (2026-10-27). Add:
- **[AI] Stone courses one level tall** (B6). Count-able height is the readability win.
- **[AI] Wall caps with moss lips** (B15) so every wall edge shares the top-sprite language.

**Walls that hide pieces (camera occlusion).** The research found the standard methods, none Hades-specific:
- Opacity fade on the occluding wall (gamedev.net; Unreal forum asks for a partial fade to 25 to 50 percent, not a hard hide).
- Dithered overdraw: redraw the occluded piece with a dither shader on top (a Unity devlog seen in search; not read in full).
- Radial cutaway: the wall is clear where the leader stands and turns opaque a set distance away, with a dithered edge (Allegro and Godot threads; Fab listing modelled on large AAA camera systems).

**[AI] Recommendation:** use the radial dithered cutaway, centred on the leader, and fall back to a plain fade for pieces other than the leader. It fits B26 (foreground occluders fade near a hidden piece) and it keeps the paper-grain look, since dithering is a pattern, not a blur. **Question 3: dithered or soft fade?**

**Caution from sources:** a single-tile corridor walled on both sides blocks all sight in a tactics map. Check line of sight for every wall piece before it goes in the sampler.

## 5. Questions for Brandon

1. **Island on paper or painted ring?** (Section 2.) This changes the `[USER]` battle-map look and the paper card in `game/`.
2. **Black shadows?** Hades uses pure black on characters and environments; R5 and B12 forbid it. Keep the ban, or allow black only on pieces and the deepest cave cells?
3. **Wall cutaway: dither or soft fade?** (Section 4.)
4. **Backdrop turns:** four plates, a symmetric ring, or a low ring that never shows its face? (Section 2, point 2.)

## 6. Proposed next steps (none started)

1. Paint one proof-of-concept on `maps/sampler/sampler.ora` in Krita: a cliff rim, a dark edge tint, and a low painted ring. Test it at the 90-degree turns (this is the same test that answers Question 4).
2. Make a modular cliff piece set (four pieces, matched edges, caps) and a radial cutaway in the sandbox, then screenshot with a piece behind a wall.
3. Once Brandon answers Questions 1 to 4, record the answers in `docs/decisions.md` and update `docs/art/battle-maps.md` (B-rules) and `docs/style-bible.md` section 13 if the Hades-style line work is adopted.

## Sources

- [MCV/DEVELOP: Behind the art of Hades (2021)](https://mcvuk.com/business-news/behind-the-art-of-hades-we-value-artistic-integrity-and-excellence-in-artistic-craft-at-supergiant-however-were-first-and-foremost-a-game-design-lead-team/)
- [Pointnthink: The Art of Hades](https://www.pointnthink.fr/en/the-art-of-hades-en/)
- [Kymira: Style study, Hades](https://kymira.bearblog.dev/style-study-hades/)
- [Kotaku: The Art of Hades (2020)](https://kotaku.com/the-art-of-hades-1845420064)
- [DualShockers: The Art of Hades (2020)](https://www.dualshockers.com/the-art-of-hades/)
- [Supergiant Games on X: Hades environment artist credit](https://x.com/supergiantgames/status/1310980505978855425)
- [Gamedev.net: Hide objects blocking player view](https://www.gamedev.net/tutorials/programming/general-and-gameplay-programming/hide-objects-blocking-player-view-r3215)
- [Tony Cooper: Fading walls (itch.io devlog)](https://tonycooper.itch.io/penitence/devlog/385977/fading-walls)
- [GameDev.net: Isometric art](https://gamedev.net/blogs/entry/1605586-isometric-art) (search snippet only, not read in full)
- Search snippets only, not read in full: Allegro forum isometric wall thread, Godot Q&A on dithered cutouts, Unreal forum "Wall Visibility", Fab camera punchout listing.
