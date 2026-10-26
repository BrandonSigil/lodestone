# Art pipeline

How Lodestone's art gets made. Brandon decided this route on 2026-10-26 (see `docs/decisions.md`).

The idea: Brandon draws a small set of samples in his style, we train a style model (a LoRA) on only those drawings, and he then makes scenes and parts in Krita by sketching while the model paints in his style. He paints over the results, and code finishes them in the game.

Never train on other artists' work. The reference artists (Yvan Duque, Natalie Andrewson and the thread images) are mood references only.

## Step 1. Install (Brandon, about 30 minutes, mostly downloads)
1. Install Krita 5.2 or newer from https://krita.org.
2. Download the latest `krita_ai_diffusion-*.zip` from https://github.com/Acly/krita-ai-diffusion/releases. Do not unzip it.
3. In Krita: Tools > Scripts > Import Python Plugin from File, pick the zip, then restart Krita.
4. Settings > Dockers > tick **AI Image Generation**. The docker appears on the side.
5. Click the gear in the docker > Connection > **Local Managed Server** > choose an install folder > **Install**. Tick the SDXL workloads (they fit an 8 GB card). Skip Flux for now; it is slow on 8 GB.
6. Wait for the downloads (about 10 to 20 GB), then click **Launch**. The docker says connected.

Help: https://docs.interstice.cloud/installation and https://docs.interstice.cloud/common-issues

## Step 2. First test (Brandon, 15 minutes)
1. New document, 1600 x 900.
2. In the docker, switch the mode to **Live**.
3. Type a short description, e.g. `flat folk-art illustration, snowy village at dusk, gumdrop mountains, warm lit windows`.
4. Paint big flat color shapes: sky, mountains, ground, a few dark house blocks. Watch the right side update.
5. Play with the strength slider: low keeps your shapes, high lets the model invent.
6. Save anything interesting to `C:\Users\Brand\Claude\lodestone-art\tests\`. Claude can read that folder.

This test uses the default model, so it will look generic. That is fine; it is a test of control, not style.

## Step 3. Style samples (Brandon)
Draw 20 to 30 images in the Lodestone style, all in the same hand. Rough is fine, but each should be finished enough to show color, edges and texture.
- 6 to 8 pieces (characters) in different hats, props and colors
- 4 to 6 buildings and props (cottage, well, cart, tent, wall section)
- 4 to 6 landscapes (home field, pine forest, snow pass, the Wall, one strange region)
- 3 to 4 close-ups of texture and marks (grass fans, stamped dots, a cloud)
- 2 to 3 frame and ornament pieces (border stamps, a quilt square)

Save them as PNG, at least 1024 px on the long side, in `C:\Users\Brand\Claude\lodestone-art\samples\`.

## Step 4. Training set (Claude)
Claude reads the samples, crops and resizes them to 1024 px, and writes one short caption per image starting with the trigger word `lodestonestyle` (e.g. `lodestonestyle, a cottage with a straw roof, dusk`). Output goes to `lodestone-art\training\`.

## Step 5. Train the style model (Brandon runs, Claude sets up)
- Free, local: OneTrainer (https://github.com/Nerogar/OneTrainer) with an SDXL LoRA preset for 8 GB cards. Expect a few hours; run it overnight. Claude writes the config.
- Paid fallback if the card struggles: an online LoRA trainer, usually a few dollars per run.
- Result: one `.safetensors` file. Put it in the plugin's LoRA folder (Krita docker > gear > Styles > open folder).

## Step 6. Make art (Brandon directs, model paints)
- In Krita, make a Style preset that uses the SDXL model plus the Lodestone LoRA and the trigger word.
- Scenes: sketch flat shapes in Live mode, regenerate until it reads, then paint over by hand.
- Pieces: draw each part (head, hat, body, pack, prop) on its own layer on a flat background, so code can assemble and recolor them.
- Never generate animation frames. Code animates the cut-out parts.
- Battle map tiles: generate only on top of the templates in `art/templates/battle-maps/` with their line art and depth as control layers, then clip and paint over (proposed, see `docs/art/battle-maps.md`). Never a freehand tileset.

## Step 7. Into the game (Claude)
- Exports go to `game/art/source/` (scenes as parallax layers, parts as separate PNGs).
- Code locks each region's palette, adds grain and light, recolors parts per character, and animates them in Godot.
- Every new asset is checked by screenshot against the style bible.
