# BunBun

Prototype 0.3 of an original, Boogie Bunnies-inspired birthday game for Beth.

Open `BunBun.xcodeproj`, select the `BunBun` scheme, and run on an iPhone or iPhone simulator. Tap a launcher rail, then tap or drag across a lane. This build adds a complete provisional level loop with progress, danger, bunny falls, dance parties, 2× scoring, win/loss states, and animated colored placeholders.

The source is split into:

- `BunBun/Game`: pure Swift rules with no presentation dependencies.
- `BunBun/Presentation`: SpriteKit and SwiftUI rendering/input.
- `BunBunTests`: matching, chain, geometry, and Classic-turn tests.

See `BunBun_Gameplay_Specification.md` for the reconstructed mechanics, explicit prototype assumptions, and birthday roadmap.
