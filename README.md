# BunBun

Prototype 0.1 of an original, Boogie Bunnies-inspired birthday game for Beth.

Open `BunBun.xcodeproj`, select the `BunBun` scheme, and run on an iPhone simulator. The first build uses colored circles and a simple three-sided launcher visualization while the rules are validated.

The source is split into:

- `BunBun/Game`: pure Swift rules with no presentation dependencies.
- `BunBun/Presentation`: SpriteKit and SwiftUI rendering/input.
- `BunBunTests`: matching, chain, geometry, and Classic-turn tests.

See `BunBun_Gameplay_Specification.md` for the reconstructed mechanics, explicit prototype assumptions, and birthday roadmap.
