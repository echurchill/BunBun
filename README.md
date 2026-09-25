# BunBun

Prototype 0.4 of an original, Boogie Bunnies-inspired birthday game for Beth.

Open `BunBun.xcodeproj`, select the `BunBun` scheme, and run on an iPhone or iPhone simulator. Tap a launcher rail, then tap or drag across a lane. This build includes the provisional level loop plus red bomb bunnies, purple row/column bunnies, cascading special effects, a four-shot guided opening, progress decay, retuned fall pressure, and generated prototype bunny animation.

The source is split into:

- `BunBun/Game`: pure Swift rules with no presentation dependencies.
- `BunBun/Presentation`: SpriteKit and SwiftUI rendering/input.
- `BunBun/Resources`: runtime copies of the blue master sprite sheets. Presentation code derives the other gameplay colors while preserving the eyes and highlights.
- `BunBunTests`: matching, chain, special-effect, geometry, pressure, and Classic-turn tests.

The generated source artwork remains untouched in `Mockup Images`. Prototype 0.4 uses four eight-frame sheets: staggered idle, match celebration, nervous board advancement, and the dance-party loop.

See `BunBun_Gameplay_Specification.md` for the reconstructed mechanics, explicit prototype assumptions, and birthday roadmap. See `BunBun_Art_Animation_Options.md` for researched character-art, animation, sourcing, licensing, and future 3D presentation options. See `BunBun_Prototype_0.5_Work_Plan.md` for the next implementation milestone.
