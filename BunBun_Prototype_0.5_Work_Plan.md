# BunBun Prototype 0.5 Work Plan

**Working milestone:** Levels and Campaign Foundation  
**Depends on:** Prototype 0.4 special-bunny and tuned single-level loop  
**Status:** Implemented in the prototype; physical-device campaign tuning remains

## Goal

Turn the current hard-coded prototype into a small, replayable sequence of data-driven levels without beginning final artwork production.

Prototype 0.5 should prove that BunBun can support a birthday-game campaign: distinct levels, controlled difficulty progression, completion flow, and saved progress. It should preserve the existing pure Swift rules and keep SpriteKit responsible only for presentation and input.

## Player-facing result

The build should contain three short levels:

1. **Bunny Lab** — the current guided introduction to launching, advancement, pressure, dance parties, and both specials.
2. **Moonlight Meadow** — fewer prepared matches, denser arrivals, and special combinations that reward planning.
3. **Dance Rehearsal** — a dance-focused level with faster meter charging, stronger pressure, and a celebratory prototype finale.

Names and visual themes are provisional. All three levels may continue using colored placeholder bunnies and simple geometric backgrounds.

## Architecture work

### 1. Add a pure Swift `LevelDefinition`

Move level-specific values out of `PrototypeLevel` and `GameState` where practical. A level definition should own:

- Stable identifier and display name.
- Starting board.
- Supplied-bunny sequence or deterministic generator.
- Arrival-row generator and seed.
- Launches per advancement.
- Progress target and decay.
- Fall progress penalty and danger penalty.
- Match and special-effect rewards.
- Dance charge and party duration.
- Optional tutorial prompts.
- Presentation metadata such as placeholder palette or theme identifier, without importing SpriteKit.

`GameState` should consume a definition or a rules-value object rather than relying entirely on static global constants.

### 2. Add a pure Swift `CampaignState`

Track:

- Current level.
- Unlocked levels.
- Best score per level.
- Completion state.
- Optional best danger/progress statistics for later achievements.

The model should be `Codable` so it can be saved without coupling game rules to `UserDefaults` or another storage technology.

### 3. Add a small persistence boundary

Create a protocol-based save interface owned outside the rules layer. The first implementation may use `UserDefaults`, but tests should use an in-memory store.

Do not put file-system, SpriteKit, or SwiftUI calls inside `CampaignState` or `GameState`.

### 4. Replace prototype globals gradually

Keep compatibility helpers only as long as needed to avoid a large, risky rewrite. Move one category at a time:

1. Meter and danger values.
2. Shot supply.
3. Arrival rows.
4. Starting board and tutorial prompts.

## Presentation work

### Level selection

- Add a simple native level-selection screen or overlay.
- Show the three levels in order.
- Lock later levels until the previous level is completed.
- Display the best score for completed levels.
- Include a reset-progress control behind a confirmation step.

### Transitions

- Replace the current restart-only win panel with `Next Level`, `Replay`, and `Levels` actions.
- Preserve the gentle loss language and add `Retry` and `Levels` actions.
- Add a short placeholder transition between levels.

### Level identity

- Give each level a distinct background color treatment, arrival pattern, and short subtitle.
- Continue using temporary art.
- Do not purchase or integrate final bunny models during 0.5.

## Level-design targets

### Bunny Lab

- Preserve the validated four-shot opening from Prototype 0.4.
- Keep the current forgiving danger tuning.
- Aim for a first successful completion in roughly 10–18 launches, subject to physical-device playtesting.

### Moonlight Meadow

- Remove explicit lane-by-lane tutorial prompts.
- Start with fewer immediate matches.
- Use slightly denser or less regular arrival rows.
- Require at least one thoughtful use of a special bunny.
- Aim for roughly 15–25 launches.

### Dance Rehearsal

- Make dance-party timing central to scoring and completion.
- Supply specials in combinations that can cascade.
- Increase advancement pressure without making one fall fatal.
- End with a larger placeholder celebration that previews the eventual birthday finale.

These launch ranges are playtest targets, not hard timers or forced turn limits.

## Automated tests

Add coverage for:

- Loading each level definition produces a valid, match-free starting state unless the level explicitly allows otherwise.
- Level-specific tuning reaches `GameState` correctly.
- Seeded arrival generation is deterministic.
- Completing a level unlocks exactly the next level.
- Losing does not unlock a level.
- Best scores only improve.
- Campaign encoding and decoding round-trips without data loss.
- Corrupt or missing save data falls back safely to a new campaign.
- The final level does not attempt to unlock an invalid next index.

Existing matching, chain, special, and pressure tests must continue passing.

## Playtest checklist

On a physical iPhone:

- Complete all three levels in sequence.
- Force a loss and retry.
- Leave and relaunch the app to verify saved unlocks and scores.
- Replay an earlier level and improve its score.
- Check that every level can be completed without relying on a hidden next-bunny preview.
- Record approximate launch count, elapsed time, falls, special activations, and dance parties per attempt.
- Note whether difficulty changes feel intentional rather than merely more crowded.

## Explicit non-goals

Prototype 0.5 will not include:

- Final bunny artwork or a live 3D renderer.
- Final music, voice, or polished sound design.
- The complete birthday narrative or final message.
- Cooperative play.
- Arcade or Endless modes.
- Cloud saves, Game Center, achievements, monetization, or analytics.
- A large content-authoring editor.

## Completion criteria

Prototype 0.5 is complete when:

- Three data-driven levels can be selected and played.
- Winning unlocks the next level and persists across launches.
- Each level has measurably different rules or content rather than only a different title.
- Win, loss, retry, replay, and return-to-levels flows work on a physical iPhone.
- All rules and campaign tests pass.
- The game still builds without changing or clearing the configured Apple development team.
- The gameplay specification records physical-device findings and any tuning changes.

## Implementation record — September 25, 2026

- Added pure Swift `LevelDefinition`, `GameRules`, `CampaignState`, and deterministic arrival patterns.
- Migrated Bunny Lab without changing its opening sequence or Prototype 0.4 tuning.
- Added Moonlight Meadow and Dance Rehearsal with distinct boards, supplied shots, arrival density, pressure, progress, and dance values.
- Added protocol-based campaign persistence, safe corrupt-data fallback, unlocks, completion, and best scores.
- Added a native SwiftUI level picker plus Next Level, Replay, Retry, Levels, and confirmed reset flows.
- Added separate placeholder color treatments and short level-introduction transitions.
- Added native iPad support, responsive tablet board/HUD sizing, and constrained large-screen menu width.
- Declared all four iPad orientations while keeping iPhone play portrait-only.
- Added an automatic end-of-run playtest summary for launches, falls, special activations, dance parties, elapsed time, and final score.
- Verified the level picker and gameplay on iPhone and on a 13-inch iPad simulator in portrait and landscape. A direct side-box match succeeded in iPad landscape.
- Expanded the suite from 21 to 28 passing tests.

## Post-0.5 environment and campaign expansion — September 26, 2026

- Expanded the campaign from three to six levels while retaining data-driven rules and sequential unlocking.
- Grouped the levels into three pairs that deliberately share Desert Camp, Forest Camp, and Snow Camp backgrounds.
- Generated one creek-free Forest Camp master, then derived desert and snow edits with matching geometry and an empty lower compositing band.
- Replaced the red hazard line with a theme-banked animated creek whose current reflects danger.
- Added safe inner-tube exits for bunnies that reach the creek.
- Reduced the permanent grid and added aim-path glow, target lift, and a subtle side-dependent formation lean.
- Added subtle code-driven ambient light glimmers, with a denser and faster lighting pass during dance parties.
- Added the shared background thumbnails to the level picker so paired stages are visually related.

The remaining completion gate is hands-on playtesting of all three levels on physical iPhone and iPad hardware, followed by tuning from the recorded launch counts, falls, specials, and dance parties.

## Apple TV feasibility milestone — September 26, 2026

- Added a separate `BunBun TV` tvOS application target and shared scheme while preserving the iPhone/iPad target and development team.
- Reused every gameplay model, level definition, campaign type, animation sheet, background, and SpriteKit presentation source instead of forking the game.
- Added a native focus-driven tvOS level picker and a 16:9 gameplay layout with television-scale HUD text, meters, board cells, launcher feedback, and viewing-distance margins.
- Mapped Siri Remote directional input to the reconstructed three-sided launcher: Left/Right changes side and Up/Down changes lane.
- Mapped Select to launch and to the appropriate Continue/Replay/Retry action after a run, Play/Pause to scene pause, and Menu to the level picker.
- Added an on-screen remote-control reminder and explicit current side/lane label.
- Verified the tvOS target builds for Apple TV 4K Simulator and visually checked the 1920×1080 native-focus level menu.
- Kept television campaign persistence local to the tvOS bundle for now. Cross-device progress is a possible later iCloud or Game Center task, not a prerequisite for audio work.

Remaining television checks are hands-on remote navigation, a complete level playthrough, and final viewing-distance tuning on an unlocked simulator or physical Apple TV. App Store icons and Top Shelf artwork are release work, not part of this feasibility milestone.

## Adaptive audio vertical slice — September 26, 2026

- Added a presentation-only `AudioDirector` shared by the iPhone/iPad and Apple TV targets.
- Added four synchronized music stems that crossfade with danger and dance-party state without restarting the loop.
- Added preloaded cues for launches, blocks, matches, chains, both special types, advancement, creek rescues, dance starts, wins, and gentle losses.
- Added persistent master mute plus independent music and effects volume controls to the level picker.
- Added a deterministic Swift audio generator, all generated WAV resources, and a full-mix listening preview.
- Kept every game-rule type audio-free and documented a filename/timing contract for replacing the procedural sketch with final production stems.
- Verified successful iOS and tvOS builds, resource embedding, Apple TV simulator launch, remote level selection, a scoring match, and active Core Audio playback queues.

Remaining audio work is subjective listening and mix tuning on physical iPhone, iPad, and Apple TV speakers; longer fatigue testing; gapless-loop confirmation; and selection or production of the final licensed score.

## Recommended implementation order

1. Introduce `LevelDefinition` and migrate Bunny Lab with no intended behavior change.
2. Parameterize `GameState` tuning.
3. Add campaign state and tests.
4. Add persistence and tests.
5. Add level selection and completion navigation.
6. Author Moonlight Meadow and Dance Rehearsal.
7. Run simulator regression tests.
8. Play all levels on a physical iPhone and record tuning findings.
