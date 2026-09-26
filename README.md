# BunBun

Prototype 0.5 of an original, Boogie Bunnies-inspired birthday game for Beth.

Open `BunBun.xcodeproj`, select the `BunBun` scheme, and run on an iPhone, iPad, or simulator. Choose an unlocked level, then tap or drag across an outlined launcher spot on either side to launch through that row, or touch the invisible launch region below a column to launch upward. This build includes six data-driven levels, persistent campaign progress and best scores, level-specific tuning, red bomb bunnies, purple row/column bunnies, cascading special effects, progress pressure, dance parties, generated prototype bunny animation, a composited animated creek, and reusable generated environment backgrounds with code-driven motion.

The source is split into:

- `BunBun/Game`: pure Swift rules with no presentation dependencies.
- `BunBun/Game/LevelDefinition.swift`: the six level definitions, deterministic arrivals, shared environment themes, supplied shots, and per-level tuning.
- `BunBun/Game/CampaignState.swift`: Codable unlock, completion, and best-score state.
- `BunBun/App/CampaignPersistence.swift`: the protocol-based save boundary and `UserDefaults` implementation.
- `BunBun/Presentation`: SpriteKit and SwiftUI rendering/input.
- `BunBun/Resources`: runtime copies of the blue master sprite sheets. Presentation code derives the other gameplay colors while preserving the eyes and highlights.
- `BunBunTests`: matching, chain, special-effect, geometry, pressure, Classic-turn, level-definition, campaign, and persistence tests.

The level picker and game board adapt separately for phones and tablets. The app target supports both iPhone and iPad, including portrait and landscape layouts; the iPad board uses larger cells and HUD spacing while retaining the same rules and direct edge controls.

The six levels are grouped into three two-level environment sets: Desert Camp, Midnight Forest Camp, and Snow Camp. A fourth Day Forest Camp plate is retained as the source master and is ready for a future level pair. All four share one composition with a deliberately empty lower band; SpriteKit adds the moving creek there at runtime. Bunnies that reach it splash into bright inner tubes and safely float out to the right. The board uses faint ground markers and outline-only side launchers instead of a heavy grid, and side aiming adds a soft path glow, target lift, and subtle formation lean. Data-driven environmental profiles add drifting dust in the desert, stars, lantern glow, friendly tree eyes, relocating fireflies, a tent-side campfire, and smoke in the forest, and snow plus ice glints in winter. These effects become livelier during dance parties.

The generated source artwork remains untouched in `Mockup Images`. Prototype 0.4 now uses ten eight-frame sheets: staggered personality-driven idle, aim reaction, match celebration, nervous board advancement, distinct bomb and line anticipation, safe rescue, and three dance-party loops.

See `BunBun_Gameplay_Specification.md` for the reconstructed mechanics, explicit prototype assumptions, and birthday roadmap. See `BunBun_Art_Animation_Options.md` for researched character-art, sourcing, licensing, and future 3D presentation options; `BunBun_Animation_TODO.md` for the working sprite-generation pipeline; `BunBun_Background_Art.md` for the generated environment strategy and prompt record; `BunBun_Music_TODO.md` for the low-cost music strategy; and `BunBun_Prototype_0.5_Work_Plan.md` for the current implementation record.
