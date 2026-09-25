# BunBun Gameplay Specification

**Prototype:** 0.4 — Special Bunnies and Level Tuning
**Platform:** iPhone  
**Technology:** Swift + SpriteKit  
**Gift date:** December 23, 2026  
**Project name:** BunBun (working title)

## Purpose

BunBun is an original birthday game for Beth inspired by the feel and puzzle rules of *Boogie Bunnies*. It is not intended to reuse the original game's name, characters, art, music, level designs, or other assets. Prototype 0.1 exists to answer one question: **does the board play the way Eddie and Beth remember?**

This document keeps three categories separate:

1. Reconstructed behavior — mechanics supported by the earlier research.
2. Prototype interpretation — details needed to make a playable build where the historical evidence is incomplete.
3. BunBun ideas — improvements and birthday-specific presentation that are not claims about the original.

## 1. Confirmed or reconstructed Boogie Bunnies behavior

### Core loop

1. The player receives a colored bunny.
2. The player aims from the left, right, or bottom edge of the formation.
3. The bunny travels into a row or column and is placed against the formation.
4. A player-caused group of at least three same-color bunnies clears.
5. Movement after a clear can create further clears, producing a chain reaction.
6. In Classic mode, the marching formation advances after every three launches.
7. The player continues clearing bunnies while preventing the formation from overwhelming the hazard edge.

### Board geometry

- The marching formation has **10 ordinary vertical lanes**.
- There are **two outside lanes**, one on each side, for a total of 12 playable columns.
- Newly arriving marching bunnies use the 10 ordinary lanes; they do not naturally spawn in the outside lanes.
- Launched bunnies can occupy the outside lanes, so those lanes are strategically useful but can become clogged.
- The player can fire from three sides: **left, right, and bottom**.
- Firing horizontally through a completely empty row can send the bunny all the way through the board, discarding it.
- Historical descriptions indicate special edge/wrap behavior around the front row. Its exact geometry and placement rules still need hands-on validation and are not frozen for Prototype 0.1.

### Matching and chains

- A match contains **three or more orthogonally connected bunnies of one color**.
- Straight groups and L-shaped groups count.
- Diagonal contact alone does not count.
- A clear can move the remaining formation and create another match; repeated clears form a chain.
- Merely marching three same-color bunnies into an adjacent arrangement does **not** automatically clear them. Resolution begins with a player placement or with movement during an already active chain.

### Pressure and progression

- Classic mode is turn based: the formation advances once per three launches.
- Arcade and Endless modes use time pressure, but they are outside Prototype 0.1.
- Bunnies can fall into the pit without causing an immediate one-bunny game over.
- Clears add to a level-progress meter; falls reduce progress, and historical descriptions also mention progress decay.
- Filling the progress meter completes a level.

### Dance party and scoring

- Successful play fills a dance meter.
- Filling it triggers a dance party.
- Matches during a dance party receive a 2× score multiplier.
- Dance parties are part of the game's identity and eventual reward loop, not merely a decorative animation.

### Special bunnies

- Contemporary coverage says matching three red bunnies removes the bunnies around them.
- The same coverage says matching three purple bunnies removes every bunny in a row or column, regardless of color.
- A later retrospective independently describes red bunnies removing nearby dancers and purple bunnies clearing their rows and columns.
- The surviving descriptions do not settle the exact red blast radius, how the purple direction is selected, or whether one special can activate another. Those details remain prototype interpretations.

Sources:

- [GameSpot hands-on preview, October 11, 2007](https://www.gamespot.com/articles/boogie-bunnies-hands-on/1100-6180794/)
- [The Game Hoard retrospective, June 24, 2024](https://thegamehoard.com/2024/06/24/boogie-bunnies-xbox-360/)

### Modes and presentation

- The original offered Classic, Arcade, and Endless modes.
- The original campaign moved through themed locations and costume sets.
- The game supported cooperative play, although its shared-rail movement had control limitations.
- The original did not reveal the next bunny color.

## 2. Prototype 0.1 interpretations

These choices make the first build deterministic and testable. They are **not** claims that the original used the same hidden rules.

### Coordinate system

- The prototype board is 12 columns × 8 rows.
- Columns 1–10 are marching lanes; columns 0 and 11 are outside lanes.
- Row 0 is the hazard/front edge. Row 7 is the back/arrival edge.
- Advancement moves every occupied cell one row toward row 0, ejecting occupants that move past it.

The 12-column structure is reconstructed; the eight-row depth is a provisional tuning value.

### Placement

- Bottom shots enter a selected column from the hazard/front edge and stop immediately before the first occupied cell. If the column is empty, the bunny travels to the back row.
- Left and right shots enter a selected row and stop immediately before the first occupied cell.
- A side shot through an entirely empty row passes through and is discarded.
- A shot is blocked if the entry cell is already occupied.
- Blocked, placed, and passed-through launches all consume a Classic turn for now.

### Collapse

- After a clear, each column compacts toward row 7, the back/arrival edge, while preserving bunny order. A successful match therefore creates breathing room near the hazard.
- The initial clear must contain the newly placed bunny.
- After the first clear, every new 3+ group caused by compaction may resolve as the next chain stage.
- Advancement itself never starts match resolution.

Prototype 0.4 initially packed cleared columns toward row 0. Physical-device playtesting immediately exposed that as backwards: a successful match made the entire formation rush toward danger. From the September 25 playtest onward, successful clears compact away from the hazard; scheduled Classic advancement remains the only whole-formation movement toward it. This behavior is isolated in `Board.compactAwayFromHazard()` so later historical verification can still refine it without rewriting matching or presentation.

### Prototype scoring

- 100 points per removed bunny, multiplied by the one-based chain stage.
- Progress, dance, danger, win/loss, bombs, and line clears are active in Prototype 0.4. Their exact values are provisional BunBun tuning rather than reconstructed historical constants.

## 3. Proposed BunBun changes

These are intentional modernizations rather than reconstructions.

- Touch-first aiming with a clearly highlighted lane.
- Two control experiments: direct lane tapping and drag/flick from a launcher rail.
- Optional next-bunny preview if hidden colors feel unfair on a phone.
- Precise visual targeting; do not reproduce the original controller's aiming ambiguity.
- Single-player first. A later “Eddie + Beth” cooperative mode should be designed for shared iPad play or nearby devices rather than copying the old shared-rail restriction.
- Original characters, environments, music, title, and effects.
- Accessibility options for color identification, motion, haptics, and sound.

## 4. Birthday-specific ideas

These belong to the polished Beth Edition, not the mechanics prototype.

- On first launch, begin on black. Introduce one bunny, then another, and reveal the familiar three-sided board before showing the title.
- Keep the nostalgic recognition as the surprise rather than explaining the premise up front.
- Hide personal Easter eggs and memory-based achievements in later levels.
- End the final level with a large dance celebration in which the bunnies arrange themselves into:

  **HAPPY BIRTHDAY**  
  **BETH**

- Have one final bunny hop forward carrying an object meaningful to Eddie and Beth.

## 5. Prototype 0.1 acceptance criteria

- A native iPhone app launches into a SpriteKit scene.
- The scene visibly distinguishes 10 marching columns, two outside columns, and all three launcher sides.
- Artwork consists only of simple colored circles and geometric placeholders.
- `Board`, `Bunny`, `MatchEngine`, `ChainResolver`, and `GameState` are pure Swift and import neither SpriteKit nor SwiftUI.
- The rules recognize horizontal, vertical, and L-shaped connected groups of 3+.
- Diagonal-only groups do not match.
- A player placement can start a clear.
- Column compaction can create and resolve a multi-stage chain.
- Passive marching advancement does not resolve matches.
- Every third Classic launch advances the formation.
- Automated tests cover matching, non-matching, chain reactions, outside-lane spawning, side-row pass-through, and Classic advancement.

## 6. Architecture boundary

```text
Pure Swift rules
  Bunny / Board / MatchEngine / ChainResolver / GameState
                    |
                    | TurnOutcome + board snapshots
                    v
Presentation
  SpriteKit scene / placeholder nodes / touch mapping
```

The rules layer owns coordinates, placement, matching, clearing, chains, advancement, score, and turn cadence. SpriteKit owns drawing, animation, sound, and input translation. This permits a later SpriteKit, SceneKit, RealityKit, or hybrid presentation without changing the puzzle engine.

## 7. Deferred questions for play testing

1. What is the exact historical board depth and visible perspective?
2. How exactly do front-row edge shots wrap or bend?
3. Does a clear collapse only vertically, or do bunnies shift according to shot direction or another rule?
4. Are disconnected same-color groups created in the same movement resolved together or sequentially?
5. Do blocked shots consume a turn?
6. What are the precise progress, pit-damage, decay, dance-meter, and special-bunny values?
7. Which control scheme feels most immediately recognizable to Eddie and Beth?

Answers should be recorded here before changing the rules, preserving the line between reconstruction and BunBun design.

## 8. Prototype 0.1 playtest findings

Tested by Eddie on a physical iPhone on September 25, 2026.

- The reconstructed **10 ordinary + 2 outside column** geometry resembles the remembered board.
- The eight-row depth also appears correct.
- Shot placement, wrapping behavior, movement toward the pit, and advancement timing all felt plausibly faithful, subject to later comparison with gameplay recordings.
- The largest visual mismatch is aspect ratio. The remembered game filled a 4:3 television, while a modern iPhone leaves substantially more vertical space around a width-constrained board.
- Original bunnies were taller than they were wide. Prototype 0.2 should use taller cells and bunny silhouettes so the board occupies more vertical space without changing row or column counts.
- The old game communicated its rules through constant character motion, celebration, and spectacle. Static placeholders make mechanically correct behavior feel less recognizable.
- The current prototype is intentionally forgiving near the hazard. A historically accurate loss threshold can wait until movement and feedback make board pressure legible.

### Prototype 0.2 action pass

- Preserve the validated row and column counts.
- Increase cell height independently of cell width.
- Replace circles with simple tall bunny-shaped placeholders; this is still temporary art.
- Animate launched bunnies along their shot paths.
- Animate match pops, chain labels, column collapse, and Classic advancement.
- Highlight the selected launcher and the lane being aimed through.
- Add restart and debug-display controls for rapid play testing.
- Keep loss disabled while movement and board-pressure behavior are evaluated.

## 9. Prototype 0.3 provisional tuning

Prototype 0.3 activated the first complete play loop. Its initial values were BunBun tuning choices for play testing, not reconstructed historical constants. Prototype 0.4 supersedes several of these values after adding specials and testing the guided opening.

- Each cleared bunny adds 4 progress points.
- Each fallen bunny removes 5 progress points.
- Each fallen bunny adds 12 danger points, so a single fall is survivable.
- Each cleared bunny relieves 3 danger points.
- Reaching 100 progress completes the level.
- Reaching 100 danger ends the attempt with a gentle “Bunnies need a break” screen.
- Each cleared bunny charges 14 dance points.
- At 100 dance points, a four-launch dance party begins and the dance meter rolls over.
- Clears made while the dance party is active score 2× points.
- The opening board contains no passive matches and intentionally offers an introductory blue match from the left followed by a green match from the right.
- Arriving rows contain occasional gaps and continue to spawn only in the 10 ordinary lanes.

Presentation during a dance party uses placeholder dancing, colored lights, confetti, haptics, and a 2× indicator. Final music, choreography, and character animation remain deferred.

## 10. Prototype 0.4 special-bunny interpretations and tuning

Prototype 0.4 adds strategic special bunnies while keeping their uncertain historical details explicit.

### Special rules

- A red bomb bunny participates in red matches like an ordinary red bunny.
- When a matched red bomb activates, it removes occupied cells in a 3×3 area centered on itself.
- A purple line bunny participates in purple matches like an ordinary purple bunny.
- When a matched purple line bunny activates, it removes occupied cells across both its full row and full column.
- If one special removes another special, the caught special activates during the same chain stage.
- Overlapping effects remove and score each bunny only once.
- After the expanded removal finishes, normal column compaction occurs and any new matches continue as the next chain stage.

The 3×3 bomb, row-and-column cross, and cascading-special behavior are **BunBun prototype interpretations**. They are designed to be readable and satisfying while the original game's exact hidden rules remain uncertain.

### First-level tuning

- A bunny removed as part of an actual color match adds 3 progress points.
- A bunny removed only by a special effect adds 1 progress point. This keeps a large line clear exciting without ending the level immediately.
- Every Classic advancement removes 2 progress points, introducing the reconstructed progress-decay pressure in a turn-based form.
- A fallen bunny removes 2 progress points and adds 6 danger points.
- Every cleared bunny still relieves 3 danger points.
- A matched bunny adds 14 dance points; a bunny removed only by a special adds 4 dance points.
- Dance parties still last four launches and award 2× score.
- Score remains 100 points per removed bunny multiplied by chain depth and the active dance multiplier.

### Guided opening

The first four supplied bunnies form a deterministic mechanics tour:

1. Blue normal bunny: clear the prepared pair from the left.
2. Green normal bunny: clear the prepared pair from the right.
3. Red bomb bunny: match the prepared red pair from the left, demonstrate the blast, and survive the first Classic advancement.
4. Purple line bunny: match the prepared purple pair from the right and demonstrate the row/column clear.

After the introduction, normal colors resume and both special types recur in the deterministic prototype sequence. Arriving rows still use only ordinary colors and the 10 marching columns.

### Prototype 0.4 acceptance criteria

- Both special types are represented in the pure Swift model and require no SpriteKit dependency.
- Special effects can remove differently colored bunnies.
- A special caught by another special activates exactly once.
- Special removals can compact the board and create later chain stages.
- Match clears and effect-only clears can be tuned independently for progress and dance charge.
- The first four guided shots demonstrate both specials without causing an immediate loss.
- Placeholder presentation clearly distinguishes bomb and line bunnies and animates their effects.
- Automated tests cover bomb radius, line clearing, cascading specials, special scoring, progress decay, and the guided opening.

### Prototype animation pass

The blue bunny concept is now used as real prototype presentation art while remaining isolated from the rules layer.

- Four generated 4×2 sprite sheets provide eight-frame idle, match-celebration, board-advance reaction, and dance-party motions.
- The original generated sheets are retained in `Mockup Images`; runtime copies live in `BunBun/Resources`.
- The blue master artwork is hue-shifted at runtime and cached for all six gameplay colors. Neutral black eyes and white highlights remain intact.
- Idle loops receive a small deterministic phase offset so the formation does not move in mechanical lockstep.
- Matched bunnies celebrate before leaving the board, survivors react before Classic advancement, and active dance parties replace idle motion with the dance loop.
- Special-bunny badges and effects remain presentation overlays, keeping the same character animation reusable for normal, bomb, and line bunnies.

These sprite sheets are prototype assets, not a commitment to the final 2D/3D rendering approach described in the art and animation research.
