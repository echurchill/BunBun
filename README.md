# BunBun

Prototype 0.4 of an original, Boogie Bunnies-inspired birthday game for Beth.

Open `BunBun.xcodeproj`, select the `BunBun` scheme, and run on an iPhone or iPhone simulator. Tap or drag across a purple box on either side to launch through that row, or touch the invisible launch region below a column to launch upward. This build includes the provisional level loop plus red bomb bunnies, purple row/column bunnies, cascading special effects, a four-shot guided opening, progress decay, retuned fall pressure, and generated prototype bunny animation.

The source is split into:

- `BunBun/Game`: pure Swift rules with no presentation dependencies.
- `BunBun/Presentation`: SpriteKit and SwiftUI rendering/input.
- `BunBun/Resources`: runtime copies of the blue master sprite sheets. Presentation code derives the other gameplay colors while preserving the eyes and highlights.
- `BunBunTests`: matching, chain, special-effect, geometry, pressure, and Classic-turn tests.

The generated source artwork remains untouched in `Mockup Images`. Prototype 0.4 now uses ten eight-frame sheets: staggered personality-driven idle, aim reaction, match celebration, nervous board advancement, distinct bomb and line anticipation, safe rescue, and three dance-party loops.

See `BunBun_Gameplay_Specification.md` for the reconstructed mechanics, explicit prototype assumptions, and birthday roadmap. See `BunBun_Art_Animation_Options.md` for researched character-art, sourcing, licensing, and future 3D presentation options; `BunBun_Animation_TODO.md` for the working sprite-generation pipeline; `BunBun_Music_TODO.md` for the low-cost music strategy; and `BunBun_Prototype_0.5_Work_Plan.md` for the next implementation milestone.
