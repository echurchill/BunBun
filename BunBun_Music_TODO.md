# BunBun Music Strategy and To-Do

Music is central to the premise: the bunnies should not merely animate while generic background music plays. The puzzle rhythm, danger, chains, and dance parties should feel synchronized to one playful musical identity.

This is a production plan, not legal advice. Service prices and terms change, so license terms must be rechecked and archived on the day any final track is generated or downloaded.

## Recommendation

Use AI generation for inexpensive exploration, then finish the selected musical idea in GarageBand.

The best low-cost workflow is:

1. Generate many short instrumental ideas with **Loudly**, **Suno**, or **Stable Audio**.
2. Choose an original four- or eight-bar hook rather than accepting the first full song.
3. Rebuild, edit, or substantially arrange the winner in GarageBand using MIDI instruments and properly licensed Apple loops.
4. Export synchronized gameplay stems and stingers rather than one fixed stereo song.
5. Preserve the GarageBand project, prompts, source generations, download receipts, and a dated copy of the applicable license terms.

GarageBand is the safest economical finishing environment for this project. Apple permits included loops to be used royalty-free in original music and distributed as part of that composition, although the individual loops may not be redistributed by themselves: [Apple GarageBand commercial-loop guidance](https://support.apple.com/en-ca/102034).

## AI generators worth testing

### Loudly — best fit for a game-production experiment

- Explicitly supports music for games and apps.
- Provides controls for genre, energy, duration, structure, instruments, key, and BPM.
- Offers WAV/MP3 downloads and stem export on applicable plans.
- Grants a non-exclusive worldwide commercial license rather than promising exclusive copyright ownership.
- Particularly useful when we need separate drums, bass, melody, and effects layers.

Official references: [Loudly AI Music Generator](https://www.loudly.com/ai-music-generator) and [Loudly licensing FAQ](https://www.loudly.com/faq).

### Suno — fastest route to memorable song ideas

- Very good for quickly exploring hooks, arrangements, and stylistic directions.
- Use instrumental generations; vocals would compete with puzzle feedback and age faster.
- Only tracks generated and properly downloaded while subscribed to an eligible paid tier should be considered for commercial use.
- Suno explicitly notes that commercial-use rights do not guarantee copyright protection.
- Free-tier output should remain private experimentation only.

Official references: [Suno paid-tier rights](https://help.suno.com/en/articles/9601665), [Suno ownership explanation](https://help.suno.com/en/articles/2416769), and [Suno terms](https://suno.com/terms).

### Stable Audio — strongest candidate for loops and sound design

- Supports requested duration, audio-to-audio variation, inpainting, and short sound effects.
- Can generate material from one second through full compositions and offers experimental stem export.
- Likely useful for seamless instrumental beds, transition risers, launcher sounds, and dance-party layers.
- Confirm the exact commercial license attached to the selected account tier before using any export in a release.

Official reference: [Stable Audio product overview](https://stableaudio.com/).

## Proposed BunBun musical identity

- **Style:** playful bubblegum electro-funk with light disco influence.
- **Tempo:** begin experiments around 112–118 BPM in 4/4.
- **Mood:** buoyant and mischievous, never frantic or infantile.
- **Core instruments:** rubbery synth bass, handclaps, compact electronic drums, marimba or toy-like pluck, bright chord stabs, and a small ear-worm lead motif.
- **Avoid:** vocals, nursery-rhyme clichés, heavy guitars, cinematic orchestration, direct references to the original Boogie Bunnies soundtrack, and prompts naming living artists.
- **Loop target:** 60–90 seconds, built from bar-aligned sections with a clean seamless ending.

### Starting generation prompt

```text
Original instrumental music for a colorful bunny match-three puzzle game. Playful bubblegum electro-funk with a light disco bounce, 116 BPM, 4/4, bright major-key harmony, rubbery synth bass, crisp handclaps, compact electronic drums, marimba-like plucks, cheerful chord stabs, and one memorable four-bar melodic hook. Energetic enough for cartoon bunnies to dance, but uncluttered enough for repeated puzzle play. No vocals, no copyrighted melody references, no imitation of any named artist or existing game soundtrack. Compose in bar-aligned sections suitable for a seamless 64-second loop with a clean loop point.
```

## Adaptive music design

Do not ship only one flattened track. Build synchronized files with the same BPM, key, duration, and bar structure:

| Layer | Purpose |
| --- | --- |
| Base groove | Always-playing drums, bass, and light harmony |
| Melody layer | Main hook; can rest periodically to prevent fatigue |
| Pressure layer | Added percussion or pulse as danger rises |
| Dance layer | Brighter lead, claps, and extra rhythm during the 2× party |
| Chain sweetener | One- or two-bar flourish triggered by deeper chains |
| Level-complete stinger | Short celebratory ending in the same key |
| Rescue sting | Gentle comic cue rather than a failure sound |
| Birthday finale | Expanded arrangement of the main motif |

SpriteKit can begin with simple crossfades. A later audio controller can keep synchronized stems running and change their volumes on bar boundaries, preventing audible restarts when danger or dance-party state changes.

## Production and licensing checklist

- Generate only original instrumental material with no artist imitation or copyrighted melody reference.
- Record the tool, plan, account, prompt, generation date, and source URL for every candidate.
- Save the untouched downloaded original before editing.
- Save a PDF or screenshot of the governing license and proof of the paid tier/download.
- Confirm that the license covers downloadable commercial video games, not merely social-video use.
- Confirm whether the license survives subscription cancellation.
- Prefer WAV or lossless stems for editing; export the game delivery files afterward.
- Rework the chosen idea in GarageBand: structure, melody, harmony, mix, transitions, and exact loop point.
- Keep the editable `.band` project and all MIDI performances.
- Test a gapless loop on an actual iPhone with headphones and the phone speaker.
- Add independent music, effects, and haptics volume controls.
- Provide a mute option and respect interruptions from other audio apps.

## Prototype music to-do

- Generate 10–20 inexpensive 30–60 second instrumental sketches across Loudly, Suno, and Stable Audio trials.
- Shortlist three based on hook, fatigue after five minutes, clean loop potential, and licensing clarity.
- Rebuild the strongest hook in GarageBand rather than shipping a minimally edited generation.
- Produce base, melody, pressure, and dance stems at one fixed tempo and length.
- Create chain, rescue, level-complete, and birthday stingers in the same key.
- Implement a presentation-only `MusicController`; keep game rules unaware of audio.
- Crossfade base/pressure/dance layers from `TurnOutcome` and meter state.
- Playtest with sound effects enabled so the arrangement leaves space for pops, launches, and bunny reactions.
- Consider paying a human musician for a final polish pass if the generated/rebuilt theme is strong but not yet unforgettable.

## Decision gate before release

Do not call a track final until we can answer all of these:

1. Can Eddie and Beth hum the hook after hearing it twice?
2. Does it remain pleasant after ten uninterrupted minutes?
3. Does dance-party mode feel musically bigger without restarting the song?
4. Is the exact license and provenance archived in the repository or private project records?
5. Can we revise the melody, stems, and loop point without returning to the generator?
6. Does the final music feel like BunBun rather than an imitation of Boogie Bunnies or a generic AI track?

## Implemented prototype audio — September 26, 2026

The first adaptive audio vertical slice is now playable on iPhone, iPad, and Apple TV. It is deliberately replaceable: game rules know nothing about sound, while `AudioDirector` translates presentation events and meter state into music and effects.

### Prototype score

- The score is an original 116-BPM, 4/4, C-major electro-funk loop lasting 16 bars (about 33.1 seconds).
- Four sample-aligned mono WAV stems start together and remain running together: base groove, melodic hook, pressure percussion, and dance sweetener.
- The base and hook play during normal puzzle play.
- The pressure stem fades in on a curved response to the danger meter rather than switching on abruptly.
- Dance parties crossfade in brighter claps and a counter-melody without restarting or losing the beat.
- A full-mix `BunBunThemePreview.wav` is retained in `Tools/AudioPreview` for quick listening outside the game. It is deliberately outside `BunBun/Resources/Audio`, whose whole-folder reference would otherwise embed it in every install.
- Stem compression was evaluated in September 2026 and deferred: the stems stay sample-aligned mono WAVs to protect gapless 33-second loops, since lossy re-encoding needs device listening tests this environment cannot run. Apple Lossless remains the preferred future format when an encoder is available.

The prototype score and effects are generated deterministically by `Tools/make_audio_assets.swift`. They contain no sampled commercial recording, no copied melody, no artist imitation, and no dependency on an AI-service license. Running this command regenerates the complete set:

```sh
swift Tools/make_audio_assets.swift
```

This procedural version is a musical sketch, not the final birthday soundtrack. Its main job is to validate tempo, layering, repetition, event timing, and the amount of sonic space needed for gameplay cues before money is spent on a final source.

### Event sound map

| Game event | Prototype cue |
| --- | --- |
| Bunny launch | Rising rubbery whoosh |
| Blocked launch | Short descending bonk |
| First match | C-major three-note sparkle |
| Deeper chain | Faster rising arpeggio, pitched slightly higher by depth |
| Bomb special | Cartoon low boom and noise burst |
| Line special | Bright upward sweep |
| Classic advancement | Compact hop cue |
| Creek rescue | Splash followed by a gentle rising whistle |
| Dance-party start | Ascending chord and claps |
| Level complete | Longer major-key flourish |
| Level lost | Gentle descending phrase with a hopeful final note |

### Runtime behavior and controls

- `AudioDirector` lives in the presentation layer; `Board`, `MatchEngine`, `ChainResolver`, and `GameState` remain pure Swift and audio-free.
- Effects are preloaded when a level starts to avoid first-use latency during a match.
- The audio session uses the ambient category, respects the hardware mute policy, and mixes with other audio instead of forcibly taking over the device.
- Apple TV Play/Pause pauses and resumes the synchronized music players with the SpriteKit scene.
- The level picker stores independent music and effects volumes plus a master mute in `UserDefaults`.
- iPhone/iPad use sliders; tvOS uses focusable minus/plus controls because SwiftUI sliders are unavailable on tvOS.

### Replacement contract for final music

Final stems can replace the four `Music*.wav` files without changing gameplay code when they share an identical sample rate, duration, tempo, downbeat, and loop boundary. Final effects can likewise replace their matching `SFX*.wav` files. Before replacement, test the candidate at least ten minutes, confirm gapless looping on physical hardware, archive its source and license, and compare the dance transition with gameplay effects active.
