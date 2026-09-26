# BunBun Background Art

**Created:** September 26, 2026  
**Generation path:** OpenAI built-in image generation  
**Status:** Prototype production art; retain source and generation notes for provenance review

## Environment strategy

BunBun uses a small set of memorable environments across multiple levels. Each square plate is composed for aspect-fill cropping on portrait iPhone and portrait or landscape iPad. Important scenery stays near the perimeter while the central playfield remains darker and quieter.

| Environment | Resource | Levels |
| --- | --- | --- |
| Carrot Workshop | `BackgroundCarrotWorkshop.png` | Bunny Lab, Carrot Works |
| Moonlit Garden | `BackgroundMoonlitGarden.png` | Moonlight Meadow, Firefly Falls |
| Birthday Pavilion | `BackgroundBirthdayPavilion.png` | Dance Rehearsal, Birthday Bash |

SpriteKit adds subtle glimmering lights separately from the raster artwork. Normal play illuminates a small deterministic subset. Dance parties increase the count, brightness, color variety, and tempo without modifying the image files.

## Final prompt set

All three prompts used the `stylized-concept` use case and requested an original visual identity, environment-only imagery, safe portrait/landscape crops, a quiet central playfield, and no characters, game pieces, interface, text, logos, watermark, or imitation of existing game artwork.

### Carrot Workshop

An original whimsical carrot-powered workshop and research conservatory at a playful rabbit-sized scale, with rounded brass pipes, glowing carrot-energy tanks, curved teal machinery, warm wood, observation windows, and greenhouse foliage around the perimeter. Friendly polished 3D animated-film rendering with teal, cobalt, brass, orange, and leaf green lighting.

### Moonlit Garden

An original enchanted moonlit garden clearing with oversized flowers, curling leafy arches, rounded stones, fireflies, waterfall mist, and whimsical mushrooms around the perimeter. Friendly polished 3D animated-film rendering with midnight blue, turquoise, violet, soft pink, and warm firefly light.

### Birthday Pavilion

An original festive birthday dance pavilion with rounded art-deco arches, curtains, strings of bulbs, balloon-like decorations, small speakers, and a starry lakeside view. Friendly polished 3D animated-film rendering with deep plum, purple, coral, warm gold, and cyan accents.

## Production notes

- Keep backgrounds free of baked-in grids, bunnies, particles, labels, and UI.
- Preserve square masters; crop at runtime instead of maintaining device-specific copies.
- Keep the code-driven dark overlay so bright scenery cannot reduce board readability.
- Treat generated plates as prototype production material until final commercial-use terms and provenance are archived with the release.
