# BunBun

Prototype 0.5 of an original, Boogie Bunnies-inspired birthday game for Beth.

Open `BunBun.xcodeproj` and select the `BunBun` scheme for iPhone or iPad, or `BunBun TV` for Apple TV. On touch devices, choose an unlocked level, then tap or drag across an outlined launcher spot on either side to launch through that row, or touch the invisible launch region below a column to launch upward. This build includes twelve data-driven levels, persistent campaign progress and best scores, level-specific tuning, red bomb bunnies, purple row/column bunnies, cascading special effects, progress pressure, dance parties, generated prototype bunny animation, a rendered creek with live composited current and rescues, reusable generated environment backgrounds with code-driven motion, adaptive prototype music and sound effects, and an initial native Apple TV presentation.

The source is split into:

- `BunBun/Game`: pure Swift rules with no presentation dependencies.
- `BunBun/Game/LevelDefinition.swift`: the twelve level definitions, deterministic arrivals, shared environment themes, supplied shots, and per-level tuning.
- `BunBun/Game/CampaignState.swift`: Codable unlock, completion, and best-score state.
- `BunBun/App/CampaignPersistence.swift`: the protocol-based save boundary and `UserDefaults` implementation.
- `BunBun/Presentation`: SpriteKit and SwiftUI rendering/input.
- `BunBun/Presentation/AudioDirector.swift`: synchronized adaptive music stems, event cues, audio-session behavior, and preference handling.
- `BunBun/Resources`: runtime copies of the blue master sprite sheets. Presentation code derives the other gameplay colors while preserving the eyes and highlights.
- `BunBun/Resources/Audio`: four synchronized music stems and eleven gameplay cues. The full-mix listening preview lives in `Tools/AudioPreview` so it never ships in the app bundle.
- `Tools/make_audio_assets.swift`: deterministic source generator for every prototype WAV, so the placeholder score can be revised without an external service.
- `BunBunTests`: matching, chain, special-effect, geometry, pressure, Classic-turn, level-definition, campaign, and persistence tests.

The level picker and game board adapt separately for phones and tablets. The app target supports both iPhone and iPad, including portrait and landscape layouts; the iPad board uses larger cells and HUD spacing while retaining the same rules and direct edge controls.

The separate `BunBun TV` target reuses the same rules, campaign, artwork, SpriteKit scene, and SwiftUI level picker. It presents a native focus-driven level menu and a 16:9 gameplay layout designed for viewing distance. During play, Left/Right changes launcher side, Up/Down changes lane, Select launches, Play/Pause pauses or resumes, and Menu returns to the level picker. At the end of a run, Select advances to the next level or replays/retries as appropriate. Apple TV currently has its own local campaign save because it uses a separate bundle identifier; shared progress can be added later with iCloud/Game Center if desired.

The twelve levels are grouped into four three-level environment sets: Sunset Camp (Bunny Lab, Carrot Works, Sunset Shuffle), Springtime Camp (Meadow Warmup, Riverside Romp, Campfire Cadence), Moonlit Camp (Moonlight Meadow, Firefly Falls, Midnight Encore), and Winter Camp (Dance Rehearsal, Snowflake Shuffle, Birthday Bash). All four share one composition with a deliberately empty lower band; SpriteKit places a transparent rendered creek there, clips its board-facing shoreline nearly straight, and overlays moving highlights whose speed and glow respond to danger. Bunnies that reach it splash into bright inner tubes and safely float out to the right. The board uses faint ground markers and outline-only side launchers instead of a heavy grid, and side aiming adds a soft path glow, target lift, and subtle formation lean. Data-driven environmental profiles add drifting dust in the desert, stars, lantern glow, friendly tree eyes, relocating fireflies, a tent-side campfire, and smoke in the forest, and snow plus ice glints in winter. These effects become livelier during dance parties.

The generated source artwork remains untouched in `Mockup Images`. Prototype 0.5 uses ten eight-frame sheets: staggered personality-driven idle, aim reaction, match celebration, nervous board advancement, distinct bomb and line anticipation, safe rescue, and three dance-party loops.

The current audio is an original, procedurally synthesized prototype rather than final production music. Its 116-BPM four-layer loop grows more urgent with danger and adds a synchronized dance arrangement during 2× parties. The level picker includes persistent mute, music-volume, and effects-volume controls. See `BunBun_Music_TODO.md` for its implementation record and the path toward a richer GarageBand or licensed AI-assisted final score.

See `BunBun_Gameplay_Specification.md` for the reconstructed mechanics, explicit prototype assumptions, and birthday roadmap. See `BunBun_Art_Animation_Options.md` for researched character-art, sourcing, licensing, and future 3D presentation options; `BunBun_Animation_TODO.md` for the working sprite-generation pipeline; `BunBun_Background_Art.md` for the generated environment strategy and prompt record; `BunBun_Music_TODO.md` for the low-cost music strategy; and `BunBun_Prototype_0.5_Work_Plan.md` for the current implementation record.
