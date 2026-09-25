import Foundation

enum PlayStatus: Equatable, Sendable {
    case playing
    case won
    case lost
}

struct TurnOutcome: Equatable, Sendable {
    let launchResult: LaunchResult
    let chain: ChainResolution?
    let boardAfterResolution: Board
    let boardAfterTurn: Board
    let didAdvance: Bool
    let fallenBunnies: [Bunny]
    let pointsAwarded: Int
    let scoreMultiplier: Int
    let progressDelta: Int
    let dangerDelta: Int
    let dancePartyStarted: Bool
    let dancePartyEnded: Bool
}

struct GameState: Equatable, Sendable {
    // Prototype 0.4 compatibility constants. New gameplay uses `rules` so
    // each data-driven level can tune these values independently.
    static let launchesPerClassicAdvance = GameRules.bunnyLab.launchesPerAdvance
    static let maximumMeterValue = GameRules.bunnyLab.progressTarget
    static let progressPerMatchedBunny = GameRules.bunnyLab.progressPerMatchedBunny
    static let progressPerSpecialEffectBunny = GameRules.bunnyLab.progressPerSpecialEffectBunny
    static let progressDecayPerAdvance = GameRules.bunnyLab.progressDecayPerAdvance
    static let progressLostPerFallenBunny = GameRules.bunnyLab.progressLostPerFallenBunny
    static let dangerPerFallenBunny = GameRules.bunnyLab.dangerPerFallenBunny
    static let dangerReliefPerClearedBunny = GameRules.bunnyLab.dangerReliefPerClearedBunny
    static let danceChargePerMatchedBunny = GameRules.bunnyLab.danceChargePerMatchedBunny
    static let danceChargePerSpecialEffectBunny = GameRules.bunnyLab.danceChargePerSpecialEffectBunny
    static let dancePartyLength = GameRules.bunnyLab.dancePartyLength

    let rules: GameRules
    private(set) var board: Board
    private(set) var launchesSinceAdvance: Int
    private(set) var score: Int
    private(set) var progress: Int
    private(set) var danceMeter: Int
    private(set) var danger: Int
    private(set) var dancePartyTurnsRemaining: Int
    private(set) var status: PlayStatus

    var isDancePartyActive: Bool {
        dancePartyTurnsRemaining > 0
    }

    init(
        board: Board = Board(),
        rules: GameRules = .bunnyLab,
        launchesSinceAdvance: Int = 0,
        score: Int = 0,
        progress: Int = 0,
        danceMeter: Int = 0,
        danger: Int = 0,
        dancePartyTurnsRemaining: Int = 0,
        status: PlayStatus = .playing
    ) {
        self.rules = rules
        self.board = board
        self.launchesSinceAdvance = launchesSinceAdvance
        self.score = score
        self.progress = min(max(progress, 0), rules.progressTarget)
        self.danceMeter = min(max(danceMeter, 0), rules.danceTarget - 1)
        self.danger = min(max(danger, 0), rules.dangerLimit)
        self.dancePartyTurnsRemaining = max(dancePartyTurnsRemaining, 0)
        self.status = status
    }

    mutating func launch(
        _ bunny: Bunny,
        from side: LaunchSide,
        lane: Int,
        newBackRow: [Int: Bunny] = [:],
        resolver: ChainResolver = ChainResolver()
    ) -> TurnOutcome {
        guard status == .playing else {
            return TurnOutcome(
                launchResult: .blocked,
                chain: nil,
                boardAfterResolution: board,
                boardAfterTurn: board,
                didAdvance: false,
                fallenBunnies: [],
                pointsAwarded: 0,
                scoreMultiplier: isDancePartyActive ? 2 : 1,
                progressDelta: 0,
                dangerDelta: 0,
                dancePartyStarted: false,
                dancePartyEnded: false
            )
        }

        let startingProgress = progress
        let startingDanger = danger
        let danceWasActive = isDancePartyActive
        let multiplier = danceWasActive ? 2 : 1
        let launchResult = board.launch(bunny, from: side, lane: lane)
        var chain: ChainResolution?
        var points = 0
        var removedCount = 0
        var matchedCount = 0
        var specialEffectRemovedCount = 0
        var dancePartyStarted = false

        if case let .placed(cell) = launchResult {
            let resolution = resolver.resolve(board: board, triggeredBy: cell)
            board = resolution.board
            chain = resolution.stages.isEmpty ? nil : resolution
            removedCount = resolution.removedCount
            matchedCount = resolution.matchedCount
            specialEffectRemovedCount = resolution.specialEffectRemovedCount
            points = resolution.stages.reduce(0) { partial, stage in
                partial + stage.removedCells.count * rules.pointsPerRemovedBunny * stage.depth
            } * multiplier
            score += points
        }

        if removedCount > 0 {
            progress = min(
                rules.progressTarget,
                progress
                    + matchedCount * rules.progressPerMatchedBunny
                    + specialEffectRemovedCount * rules.progressPerSpecialEffectBunny
            )
            danger = max(0, danger - removedCount * rules.dangerReliefPerClearedBunny)

            let danceCharge = matchedCount * rules.danceChargePerMatchedBunny
                + specialEffectRemovedCount * rules.danceChargePerSpecialEffectBunny

            if danceWasActive {
                // Charge the next party more slowly while the current one is active.
                danceMeter = min(
                    rules.danceTarget - 1,
                    danceMeter + danceCharge / 2
                )
            } else {
                danceMeter += danceCharge
                if danceMeter >= rules.danceTarget {
                    danceMeter -= rules.danceTarget
                    dancePartyTurnsRemaining = rules.dancePartyLength
                    dancePartyStarted = true
                }
            }
        }

        let boardAfterResolution = board

        launchesSinceAdvance += 1
        var didAdvance = false
        var fallen: [Bunny] = []
        if launchesSinceAdvance >= rules.launchesPerAdvance {
            // Advancement intentionally does not invoke the resolver. A passive
            // 3+ group waits for the next player-caused placement or active chain.
            fallen = board.advance(newBackRow: newBackRow)
            launchesSinceAdvance = 0
            didAdvance = true
            progress = max(0, progress - rules.progressDecayPerAdvance)
        }

        if !fallen.isEmpty {
            progress = max(0, progress - fallen.count * rules.progressLostPerFallenBunny)
            danger = min(
                rules.dangerLimit,
                danger + fallen.count * rules.dangerPerFallenBunny
            )
        }

        var dancePartyEnded = false
        if danceWasActive {
            dancePartyTurnsRemaining = max(0, dancePartyTurnsRemaining - 1)
            dancePartyEnded = dancePartyTurnsRemaining == 0
        }

        if progress >= rules.progressTarget {
            status = .won
        } else if danger >= rules.dangerLimit {
            status = .lost
        }

        return TurnOutcome(
            launchResult: launchResult,
            chain: chain,
            boardAfterResolution: boardAfterResolution,
            boardAfterTurn: board,
            didAdvance: didAdvance,
            fallenBunnies: fallen,
            pointsAwarded: points,
            scoreMultiplier: multiplier,
            progressDelta: progress - startingProgress,
            dangerDelta: danger - startingDanger,
            dancePartyStarted: dancePartyStarted,
            dancePartyEnded: dancePartyEnded
        )
    }
}
