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
    static let launchesPerClassicAdvance = 3
    static let maximumMeterValue = 100
    static let progressPerMatchedBunny = 3
    static let progressPerSpecialEffectBunny = 1
    static let progressDecayPerAdvance = 2
    static let progressLostPerFallenBunny = 2
    static let dangerPerFallenBunny = 6
    static let dangerReliefPerClearedBunny = 3
    static let danceChargePerMatchedBunny = 14
    static let danceChargePerSpecialEffectBunny = 4
    static let dancePartyLength = 4

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
        launchesSinceAdvance: Int = 0,
        score: Int = 0,
        progress: Int = 0,
        danceMeter: Int = 0,
        danger: Int = 0,
        dancePartyTurnsRemaining: Int = 0,
        status: PlayStatus = .playing
    ) {
        self.board = board
        self.launchesSinceAdvance = launchesSinceAdvance
        self.score = score
        self.progress = min(max(progress, 0), Self.maximumMeterValue)
        self.danceMeter = min(max(danceMeter, 0), Self.maximumMeterValue - 1)
        self.danger = min(max(danger, 0), Self.maximumMeterValue)
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
                partial + stage.removedCells.count * 100 * stage.depth
            } * multiplier
            score += points
        }

        if removedCount > 0 {
            progress = min(
                Self.maximumMeterValue,
                progress
                    + matchedCount * Self.progressPerMatchedBunny
                    + specialEffectRemovedCount * Self.progressPerSpecialEffectBunny
            )
            danger = max(0, danger - removedCount * Self.dangerReliefPerClearedBunny)

            let danceCharge = matchedCount * Self.danceChargePerMatchedBunny
                + specialEffectRemovedCount * Self.danceChargePerSpecialEffectBunny

            if danceWasActive {
                // Charge the next party more slowly while the current one is active.
                danceMeter = min(
                    Self.maximumMeterValue - 1,
                    danceMeter + danceCharge / 2
                )
            } else {
                danceMeter += danceCharge
                if danceMeter >= Self.maximumMeterValue {
                    danceMeter -= Self.maximumMeterValue
                    dancePartyTurnsRemaining = Self.dancePartyLength
                    dancePartyStarted = true
                }
            }
        }

        let boardAfterResolution = board

        launchesSinceAdvance += 1
        var didAdvance = false
        var fallen: [Bunny] = []
        if launchesSinceAdvance == Self.launchesPerClassicAdvance {
            // Advancement intentionally does not invoke the resolver. A passive
            // 3+ group waits for the next player-caused placement or active chain.
            fallen = board.advance(newBackRow: newBackRow)
            launchesSinceAdvance = 0
            didAdvance = true
            progress = max(0, progress - Self.progressDecayPerAdvance)
        }

        if !fallen.isEmpty {
            progress = max(0, progress - fallen.count * Self.progressLostPerFallenBunny)
            danger = min(
                Self.maximumMeterValue,
                danger + fallen.count * Self.dangerPerFallenBunny
            )
        }

        var dancePartyEnded = false
        if danceWasActive {
            dancePartyTurnsRemaining = max(0, dancePartyTurnsRemaining - 1)
            dancePartyEnded = dancePartyTurnsRemaining == 0
        }

        if progress >= Self.maximumMeterValue {
            status = .won
        } else if danger >= Self.maximumMeterValue {
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
