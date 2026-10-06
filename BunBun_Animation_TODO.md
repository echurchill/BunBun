# BunBun Animation Pipeline and To-Do

This document records the inexpensive animation pipeline currently used by BunBun and the remaining work needed before final art production.

## Current approach

BunBun uses one blue bunny as the master character design. Image generation produces small 4×2 sprite sheets containing eight sequential frames for one named motion. Before an accepted sheet enters the app bundle, its alpha is cleaned to remove disconnected paint and thin strands left by AI background removal. SpriteKit slices those clean sheets once per motion, shares the resulting textures among every bunny, and applies the six gameplay colors with a lightweight GPU hue shader that preserves the neutral black eyes and bright highlights.

This gives us one consistent animation source per motion rather than six separately generated color variants.

### Implemented motions

| Motion | Runtime asset | Gameplay use |
| --- | --- | --- |
| Idle bounce | `BunnyIdleSheet.png` | Staggered ambient motion |
| Aim reaction | `BunnyAimSheet.png` | Bunnies react when their row or column is highlighted |
| Match celebration | `BunnyCelebrateSheet.png` | Successful clears; faster and larger on deeper chains |
| Board-advance reaction | `BunnyAdvanceSheet.png` | Nervous brace before Classic advancement |
| Bomb anticipation | `BunnyBombSheet.png` | Red bomb wind-up plus a pulsing bomb badge |
| Line anticipation | `BunnyLineSheet.png` | Purple line-clear wind-up plus rotating cross badge |
| Rescue tumble | `BunnyRescueSheet.png` | Safe comic exit for bunnies reaching the hazard |
| Dance boogie | `BunnyDanceSheet.png` | Dance-party variant one |
| Dance two-step | `BunnyDanceTwoStepSheet.png` | Dance-party variant two |
| Dance happy-hop | `BunnyDanceHopSheet.png` | Dance-party variant three |

Each bunny derives a stable personality number from its identifier. That number currently chooses a small size difference, idle tempo, calm-crowd cohort, and dance loop. It creates personality without changing the game model.

### Calm-crowd timing

The original game footage shows that most bunnies hold a readable neutral pose during ordinary play. Large movement is reserved for the launched bunny, a successful match, board advancement, and group celebrations. BunBun therefore divides ordinary board bunnies into seven deterministic cohorts. Each cohort performs one short idle gesture in its own time slot and then holds the neutral frame. Aiming animates only the first three bunnies along the selected launch path, board-advance reactions ripple in small waves, and dance-party loops start with staggered phases.

This timing belongs entirely to the presentation layer. Matching, chains, scoring, and board advancement do not depend on it.

## Repeatable creation pipeline

1. **Lock the master design.** Use the approved blue idle or turnaround sheet as the strict visual reference. Do not regenerate a character from text alone.
2. **Generate one motion at a time.** Ask for exactly eight sequential frames in a 4×2, row-major layout. A sheet should describe one loop or one non-looping action, never a collection of unrelated poses.
3. **Constrain the camera and character.** Require a fixed front-facing orthographic camera, identical scale, consistent foot baseline, consistent lighting, and approximately 12 percent padding.
4. **Request true transparency.** Require genuine alpha and prohibit floors, shadows, scenery, labels, grid lines, borders, effects, and extra characters. SpriteKit supplies gameplay particles and markers separately.
5. **Inspect before integration.** Confirm design consistency, readable motion, clean alpha, exactly eight cells, no clipped ears or feet, and a sensible frame-one/frame-eight transition for loops.
6. **Archive the untouched generation.** Store the descriptive original filename in `Mockup Images`. Never overwrite an accepted source sheet; make a versioned sibling if it needs revision.
7. **Create and clean the runtime copy.** Preserve the untouched generation in `Mockup Images`, then remove disconnected alpha debris and thin background-removal strands from the copy. Store the cleaned sheet in `BunBun/Resources` using a stable code-facing name such as `BunnyRescueSheet.png`. Cleanup must happen before shipping, never on the gameplay thread.
8. **Register the resource.** Add the runtime PNG to the Xcode Resources build phase without replacing the project file or disturbing signing settings.
9. **Wire the event.** Add the asset name to `BunnyMotion`, trigger it from `BunnyNode`, and keep event timing in `GameScene`. Game rules must never import SpriteKit or depend on animation duration.
10. **Verify on a physical iPhone.** Check readability at actual board scale, animation timing, memory, color shifts, and whether simultaneous motion becomes distracting.

The current generated sheets are 1774×887 pixels. `BunnyAnimationLibrary` deliberately slices them using proportional rounded boundaries rather than assuming evenly divisible pixel dimensions.

## Reusable generation prompt template

```text
Use the attached blue bunny sprite sheet as a strict character and rendering reference. Create a production-ready 2D game sprite sheet featuring exactly the same original blue bunny. Do not redesign the character.

Animation: [describe one eight-frame action, including its start, middle, end, and whether frame eight must return to frame one].

Layout: exactly four columns by two rows. Frame order runs left to right across the first row, then left to right across the second row. Every cell contains exactly one complete bunny.

Preserve the exact body proportions, facial design, eye size, ear length, blue color, glossy clay/plastic material, and lighting. Use a fixed front-facing orthographic camera, identical character scale, horizontal centering, and one consistent invisible ground baseline.

Use a genuinely transparent alpha background. No floor, shadows, scenery, text, numbers, grid lines, borders, accessories, motion trails, particles, or additional characters. Nothing may cross a frame boundary. Leave approximately 12 percent empty padding around the maximum motion.
```

## Art rules learned so far

- Give ears explicit secondary-motion instructions; otherwise they change shape randomly rather than following the body.
- Specify sequential animation rather than “eight poses.”
- Generate loops and one-shot reactions separately.
- Keep bombs, line symbols, particles, confetti, beams, and warning cues out of the generated art. Code-driven overlays are sharper, cheaper, and easier to tune.
- Generate only the blue master. The shared GPU hue shader produces more consistent color families than six independent generations without retaining six full texture copies or running Core Image during a combo.
- Treat alpha cleanup as an asset-preparation step. Runtime morphology and per-color image rendering caused multi-second stalls when cascades flowed into dance parties on iPhone and iPad.
- Never use SpriteKit's convenience texture-animation action for the generated sheets. On SpriteKit 27 it can resize a sprite to the source frame's native pixel dimensions while advancing frames. BunBun swaps each texture explicitly and reapplies the board-relative display size on every frame.
- Stagger loops and use multiple dance cycles. Perfect synchronization makes a lively crowd look mechanical.
- Treat generated artwork as prototype production material until its commercial-use terms and final provenance are archived.

## Remaining animation to-do

- Add a gentle blink or glance variation that can be layered without restarting idle animation.
- Add two aim reactions for personality variety: shy duck and eager lean.
- Add a larger level-complete group routine distinct from the ordinary dance party.
- Create birthday-finale poses and letter-holding poses for `HAPPY BIRTHDAY BETH`.
- Add launcher-specific entrance motion: bottom hop, left cartwheel, and right cartwheel.
- Add a blocked-shot “bonk and recover” that remains harmless and funny.
- Test Reduced Motion behavior: static idle frame, shorter clears, no screen shake, and reduced confetti.
- Decide whether final production remains generated 2D, moves to a rigged 2D puppet, or uses a 3D model rendered into sheets. The rules and presentation boundary supports all three.

## Acceptance checklist for every new sheet

- Same recognizable bunny design in all eight cells.
- Eight frames in correct row-major order.
- Clean alpha and no baked background effects.
- No clipped extremities or cell-boundary overlap.
- Motion reads when rendered approximately 25×35 points on an iPhone.
- Loop has no obvious last-to-first jump, or one-shot ends on the intended pose.
- All six runtime colors remain readable after GPU hue shifting.
- Original generation, final prompt, runtime copy, and licensing/provenance note are retained.
