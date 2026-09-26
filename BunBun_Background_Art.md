# BunBun Background Art

**Created:** September 26, 2026  
**Generation path:** OpenAI built-in image generation  
**Status:** Prototype production art; retain source and generation notes for provenance review

## Environment strategy

BunBun uses one creek-free master composition and two environment edits derived from it. This keeps the camera, horizon, quiet central playfield, and empty lower hazard band consistent across all six levels. SpriteKit draws the actual stream over that lower band, so no active raster plate contains baked-in water that could collide with the gameplay hazard.

| Environment | Resource | Levels |
| --- | --- | --- |
| Desert Camp | `BackgroundDesertCamp.png` | Bunny Lab, Carrot Works |
| Forest Camp | `BackgroundForestCamp.png` | Moonlight Meadow, Firefly Falls |
| Snow Camp | `BackgroundSnowyWoodland.png` | Dance Rehearsal, Birthday Bash |

The earlier Carrot Workshop, Moonlit Garden, and Birthday Pavilion plates remain in the repository as unused concept explorations. The first attempted natural plates were rejected before commit because the forest and snow scenes contained water at the lower edge.

SpriteKit adds the creek, moving highlights, danger-dependent current, aiming glow, and subtle ambient lights separately. Normal play illuminates a small deterministic subset. Dance parties increase the light count, brightness, color variety, and tempo without modifying the image files.

## Final prompt set

All images used the `stylized-concept` mode and OpenAI's built-in image generator.

### Forest Camp master

Create an original cozy forest camping glade as the master for later variants. Use a square, front-facing elevated composition with a broad flat grassy clearing occupying the central 70 percent. Keep trees, ferns, mossy stones, wildflowers, a small tent, blankets, lanterns, and logs at the perimeter and upper corners. Preserve a completely unobstructed horizontal band across the lower 25 percent for a SpriteKit stream. Friendly polished 3D animated-film rendering, warm late-afternoon light, and a calm low-contrast playfield. Dry land only: no water, creek, river, pond, waterfall, shoreline, bridge, ditch, trench, path, gap, hole, dark horizontal stripe, characters, pieces, grid, UI, text, logos, or watermark.

### Desert Camp edit

Edit the Forest Camp master while preserving its exact camera, perspective, horizon, open center, lower hazard band, and perimeter-prop geometry. Convert the setting to warm sand and packed earth, sandstone formations, mesas, shrubs, cacti, and dry grasses; adapt the camping props naturally. Use golden late-afternoon light with coral, terracotta, ochre, muted teal, and sage. Retain the same no-water, no-gap, no-character, no-grid, and no-UI constraints.

### Snow Camp edit

Edit the Forest Camp master while preserving its exact camera, perspective, horizon, open center, lower hazard band, and perimeter-prop geometry. Convert the setting to smooth level snow, rounded snow-covered evergreens, frosted shrubs, pinecones, and icy rocks; adapt the camping props naturally. Use blue winter twilight, lavender shadows, and warm lantern accents. Retain the same no-water, no-crevice, no-gap, no-character, no-grid, and no-UI constraints.

## Production notes

- Keep backgrounds free of baked-in streams, hazards, grids, bunnies, particles, labels, and UI.
- Generate one approved master first, then edit it into new biomes to preserve gameplay composition.
- Preserve square masters; crop at runtime instead of maintaining device-specific copies.
- Keep the code-driven dark overlay so bright scenery cannot reduce board readability.
- Treat generated plates as prototype production material until final commercial-use terms and provenance are archived with the release.
