# Key art sampler: vision grade rubric

Used by a fresh reviewer (an agent with no prompt and no history) to grade one sampler picture: three isometric panels, one character per panel. Give the reviewer the key character picture and the sampler picture only. Do not give it the prompt, the version name or the other grades.

Score each criterion from 1 to 5. Write one line of evidence per score, naming what you see. A 5 is the look Brandon approved; a 3 is recognisable but off; a 1 is wrong.

| Criterion | What a 5 looks like | What a 1 looks like |
|---|---|---|
| structure | Jointed figure: visible neck, separate arms with hands, a waist or belt, two legs with boots. Reads as a person, like the key character. | Blob, snowman or dough shape. Arms fused into the body, no legs or no neck. |
| scale | Up to two blocks tall on the platform, and well under a third of the panel height. Never dominates the terrain. | Taller than two blocks, or a third of the panel height or more. Dwarfs the terrain. |
| camera | Strict 2:1 isometric. Platforms and walls share the same diagonal and vertical edges. | Perspective, a horizon, sloped floors that do not match each other, or a flat top-down view. |
| line | Heavy hand-inked outlines, wobbly, one weight per shape. Matches the key character's outlines. | Hairline outlines, even uniform outlines, or no outlines. |
| finish | Watercolour wash with paper grain and slight off-register colour. Matches the terrain. | Clean vector gloss, gradients, cel shading or stipple texture. |
| personality | One readable quirk per figure (posture, hat, staff, scarf) and a silhouette you could name. | Generic, faceless, or indistinguishable from the other figures. |
| fit | The character belongs in the same world as the three terrains. Nothing pulls against the palette or the simplicity of the scene. | Looks pasted on, or fights the terrain for attention. |

## Pass rule

A picture passes when structure, camera and scale are each 4 or higher. The other criteria are advice for the art director, not a gate.

## Output

Return only this JSON, nothing else:

```json
{
  "structure": 1-5, "scale": 1-5, "camera": 1-5, "line": 1-5,
  "finish": 1-5, "personality": 1-5, "fit": 1-5,
  "evidence": {"structure": "...", "scale": "...", "camera": "...", "line": "...", "finish": "...", "personality": "...", "fit": "..."},
  "pass": true or false
}
```
