# BunBun Plus Mode Possibilities

Status: design research only. None of the ideas in this document are approved for implementation.

## Purpose and Guardrails

Plus mode is a possible family of optional gameplay variants layered on top of BunBun's established rules. The existing Campaign and Endless modes should remain available unchanged. If Plus variants are developed later, Plus Campaign can introduce unfamiliar ideas gradually while Plus Endless can combine unlocked ideas into a longer-form challenge.

Potential additions should remain readable on iPhone, iPad, and Apple TV; preserve the three-sided launcher as the familiar foundation; and reward planning rather than obscure the board with uncontrolled effects.

## Earlier Research Direction

The earlier research reached one central conclusion: Plus should add **foresight and meaningful player choices**, not merely accelerate advancement or add more hazards. The original game's three-sided launcher promises strategic play, but showing only the current bunny restricts longer-term planning. Plus is an opportunity to realize more of that promise without changing the normal modes.

Relevant precedents included Tetris-style next and hold systems, Tetris Effect's player-triggered Zone meter, Puyo Puyo's guided practice problems, and Puzzle Bobble Everybubble's separation of harder challenges from its ordinary story and survival play.

Reference material from that research:

- [GameSpot's Boogie Bunnies review](https://www.gamespot.com/reviews/boogie-bunnies-review/1900-6184884/)
- [Game Hoard's Boogie Bunnies retrospective](https://thegamehoard.com/2024/06/24/boogie-bunnies-xbox-360/)
- [Tetris Effect: Connected](https://www.tetriseffect.game/connected/)
- [Puyo Puyo Tetris 2 manual](https://cdn.akamai.steamstatic.com/steam/apps/1259790/manuals/tenpex_WM_210216_Steam_en.pdf)
- [Puzzle Bobble Everybubble game modes](https://www.taito.co.jp/en/PBEverybubble/gamemodes)
- [GDC puzzle-design workshop](https://media.gdcvault.com/gdc2016/Presentations/Menzel_Jolie_Level%20Design%20Workshop.pdf)

## Previously Recommended Foundation

### Next-Bunny Queue

Show the next three bunnies. This would let players deliberately prepare chains, plan around special bunnies, and compare approaches from the left, right, and bottom.

### Hold Burrow

Let the player store one bunny and swap it with the current bunny. Only one swap would be allowed before a launch, preventing indefinite cycling while adding a useful planning decision.

### Incoming-Row Preview

Show faint silhouettes of the next marching row behind the formation. Plus could then support denser or more demanding arrivals while remaining fair and predictable.

### Player-Controlled Encore

Instead of starting a dance party immediately when its meter fills, let the player decide when to begin it. The initial research proposal was:

- Encore lasts for three launches.
- The formation does not perform its scheduled march during those launches.
- Scoring is doubled.
- Music, bunny animation, and environmental effects intensify.
- A full charge can be saved until the player needs either scoring or breathing room.

This needs careful tuning because pausing advancement and doubling score together may be too strong. The important idea is that spending the Dance meter becomes a decision rather than an automatic event.

### Teaching Challenges

Plus Campaign should introduce unfamiliar tools through short fixed-board lessons before using them in complete levels. Candidate lessons from the earlier research were:

- Make a match using a side shot.
- Pass through an empty row rather than placing an unhelpful bunny.
- Use Hold Burrow to complete a match.
- Construct a two-stage chain.
- Save and activate Encore at a useful moment.
- Combine a special bunny with a chain.

These should teach through play, keep the board state deterministic, and introduce one idea at a time before combining mechanics.

## Proposed Plus Variants

| Mode | Possible treatment |
|---|---|
| Plus Campaign | Separate progression through remixed levels. Each new mechanic receives a small teaching board before appearing in full levels. |
| Plus Endless | All unlocked Plus tools are available, with a separate high score, increasingly dense arrivals, and the existing escalating march rate. |
| Normal Campaign and Endless | Remain completely unchanged. |

Shot sequences and incoming rows should be deterministic, particularly in teaching challenges. Extra information is useful only when the game behaves consistently.

## Earlier Second-Wave Possibilities

### Spotlight Objectives

Optional goals layered over normal play, such as making a depth-two chain, clearing from all three sides, finishing with low danger, or activating two different special bunnies in one turn.

### Rainbow Bunny

Adopts the color of the first bunny it touches. The result should be previewable and deterministic rather than random.

### Lifeguard Bunny

An earned defensive bunny that saves one falling bunny by giving it an inner tube. It should be a reward for skill, not a routine cancellation of danger.

### World Challenges

Light camp lanterns by matching nearby, crack ice through adjacent clears, collect carrots embedded in the formation, or interact with similarly gentle environment-specific objectives.

### Positive Rhythm Streak

Launching near the musical beat earns additional Dance charge or presentation flourishes. Missing the beat should carry no penalty, so rhythm remains a positive optional layer rather than a requirement.

## Ideas to Defer

The earlier research recommended deferring blockers, frozen bunnies, random control changes, and constantly rotating rule modifiers. Those ideas add complication faster than strategy, make the board harder to read, and are difficult to teach cleanly.

The previously preferred first experiment was:

**Next-three queue + Hold Burrow + incoming-row preview + player-controlled Encore**, followed by four small teaching boards.

That remains a research recommendation, not an implementation decision.

## Alternate Launchers and Power-Ups

### Diagonal Bunny

A bunny enters the board at approximately 45 degrees instead of travelling horizontally or vertically. It could approach from a corner or from a diagonal launch lane and stop at the first valid open position along its path.

Questions to explore:

- Whether the trajectory is fixed to a small set of diagonals or can be aimed freely.
- Whether it stops beside the first bunny it encounters, at the board boundary, or at a previewed target.
- How to show the complete path clearly before release, especially on Apple TV.
- Whether diagonal arrival is a consumable power-up or a permanent Plus-mode launcher.

### Parachute Bunny

A bunny drops directly onto a specific legal board location, bypassing the usual three-sided travel path. This would let the player repair an awkward gap or complete a difficult match deep inside the formation.

Questions to explore:

- Whether the player may select any empty cell or only highlighted landing zones.
- Whether occupied cells, covered cells, or cells near the stream are prohibited.
- Whether the landing displaces nearby bunnies or simply fails when the target becomes invalid.
- How rarely it must appear to avoid removing too much positional challenge.

### Laser Bunny

A bunny fires a beam across a row or down a column. The beam could remove bunnies, recolor them, activate specials it touches, or temporarily open a launch corridor.

Questions to explore:

- Whether its direction is determined by the launch side or selected independently.
- Whether the laser affects every bunny in its line, stops at the first bunny, or has limited range.
- Whether affected special bunnies activate normally.
- Whether the Laser Bunny remains on the board after firing.
- How to keep its effect visually exciting without obscuring the resulting board state.

### Back Bunny

A bunny enters from the rear of the formation, providing a fourth approach direction. It would travel from the far/back edge toward the stream until reaching its legal destination.

Questions to explore:

- Whether back launches are aimed by column using a temporary rear launcher.
- How this interacts with newly arriving march rows.
- Whether a rear launch can push a bunny forward or must stop in the first empty rear-side position.
- Whether this is an earned shot, a rare power-up, or always available in a specific Plus variant.

### Twin Bunnies

Two or more bunnies launch as one move. They might share a color, have different colors, use mirrored lanes, or be aimed independently before simultaneous release.

Questions to explore:

- Whether all destinations are chosen before any bunny moves.
- Whether matching is evaluated only after every twin has landed, preventing shot-order bias.
- Whether a blocked member cancels the whole launch or only that bunny.
- Whether twins consume one turn or multiple turn units for formation advancement.
- Whether three-or-more-bunny volleys should be a rarer upgraded form.

## Mode-Scale Variant

### Infinite March

The visible board represents only the front of a much deeper formation, with bunnies extending as far into the background as the player can see. Rear ranks continually approach while play continues. This could become a signature Plus Endless presentation and pressure system rather than a single-shot power-up.

Questions to explore:

- Whether distant ranks are real game pieces, a queued arrival model, or a visual representation of upcoming rows.
- Whether the player can inspect or influence distant colors before they reach the active board.
- How perspective scaling, depth ordering, and background density remain readable on small screens.
- Whether matches can propagate into distant ranks or only occur in the active play area.
- How the march accelerates without turning the mode into an unreadable or unavoidable loss.

## Shared Design Questions

Before selecting any idea for implementation, compare it against these criteria:

- Does the player understand the effect before committing the shot?
- Does it create a new decision rather than simply erase a difficult board?
- Does it work with matches, chains, special bunnies, dance parties, and scheduled advancement?
- Can the result be resolved deterministically when several bunnies arrive simultaneously?
- Is it equally usable with touch and the Apple TV remote?
- Can the rules remain in pure Swift while SpriteKit handles only presentation?
- Can Plus Campaign teach it in isolation before Plus Endless combines it with other additions?
