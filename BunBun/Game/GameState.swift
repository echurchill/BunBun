import Foundation

enum PlayStatus: Equatable, Sendable {
    case playing
    case won
    case lost
}

enum GameMode: Equatable, Sendable {
    case classic
    case endless
}

enum ScorePraise: String, Equatable, Sendable {
    case good = "GOOD!"
    case great = "GREAT!"
    case awesome = "AWESOME!"
    case fantastic = "FANTASTIC!"
}

struct ScoreEvent: Equatable, Sendable {
    let chainDepth: Int
    let removedBunnies: Int
    let specialActivations: Int
    let multiplier: Int
    let points: Int
    let praise: ScorePraise
}

struct TurnOutcome: Equatable, Sendable {
    let launchResult: LaunchResult
    let chain: ChainResolution?
    let boardAfterResolution: Board
    let boardAfterTurn: Board
    let didAdvance: Bool
    let fallenBunnies: [Bunny]
    let pointsAwarded: Int
    let scoreEvents: [ScoreEvent]
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
    let mode: GameMode
    private(set) var board: Board
    private(set) var launchesSinceAdvance: Int
    private(set) var totalLaunches: Int
    private(set) var score: Int
    private(set) var progress: Int
    private(set) var danceMeter: Int
    private(set) var danger: Int
    private(set) var dancePartyTurnsRemaining: Int
    private(set) var status: PlayStatus

    var isDancePartyActive: Bool {
        dancePartyTurnsRemaining > 0
    }

    /// Endless begins at the familiar Classic pace, then adds pressure in
    /// readable steps instead of ending when the progress meter fills.
    var launchesPerAdvance: Int {
        guard mode == .endless else { return rules.launchesPerAdvance }
        let reduction = totalLaunches >= 60 ? 2 : (totalLaunches >= 24 ? 1 : 0)
        return max(1, rules.launchesPerAdvance - reduction)
    }

    var launchesUntilAdvance: Int {
        max(1, launchesPerAdvance - launchesSinceAdvance)
    }

    var endlessStage: Int {
        max(1, totalLaunches / 24 + 1)
    }

    init(
        board: Board = Board(),
        rules: GameRules = .bunnyLab,
        mode: GameMode = .classic,
        launchesSinceAdvance: Int = 0,
        totalLaunches: Int = 0,
        score: Int = 0,
        progress: Int = 0,
        danceMeter: Int = 0,
        danger: Int = 0,
        dancePartyTurnsRemaining: Int = 0,
        status: PlayStatus = .playing
    ) {
        self.rules = rules
        self.mode = mode
        self.board = board
        self.launchesSinceAdvance = launchesSinceAdvance
        self.totalLaunches = max(totalLaunches, 0)
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
                scoreEvents: [],
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
        var scoreEvents: [ScoreEvent] = []
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
            scoreEvents = resolution.stages.map { stage in
                let stageMultiplier = stage.depth * multiplier
                let stagePoints = stage.removedCells.count
                    * rules.pointsPerRemovedBunny
                    * stageMultiplier
                let praise: ScorePraise = switch stage.depth {
                case 1: .good
                case 2: .great
                case 3: .awesome
                default: .fantastic
                }
                return ScoreEvent(
                    chainDepth: stage.depth,
                    removedBunnies: stage.removedCells.count,
                    specialActivations: stage.specialActivations.count,
                    multiplier: stageMultiplier,
                    points: stagePoints,
                    praise: praise
                )
            }
            points = scoreEvents.reduce(0) { $0 + $1.points }
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
                    // A large chain can earn several meters of charge at once.
                    // Keep only the remainder so the next-party meter always
                    // stays inside its documented 0..<danceTarget range.
                    danceMeter %= rules.danceTarget
                    dancePartyTurnsRemaining = rules.dancePartyLength
                    dancePartyStarted = true
                }
            }
        }

        let boardAfterResolution = board

        launchesSinceAdvance += 1
        totalLaunches += 1
        var didAdvance = false
        var fallen: [Bunny] = []
        if launchesSinceAdvance >= launchesPerAdvance {
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

        if danger >= rules.dangerLimit {
            status = .lost
        } else if mode == .classic && progress >= rules.progressTarget {
            status = .won
        }

        return TurnOutcome(
            launchResult: launchResult,
            chain: chain,
            boardAfterResolution: boardAfterResolution,
            boardAfterTurn: board,
            didAdvance: didAdvance,
            fallenBunnies: fallen,
            pointsAwarded: points,
            scoreEvents: scoreEvents,
            scoreMultiplier: multiplier,
            progressDelta: progress - startingProgress,
            dangerDelta: danger - startingDanger,
            dancePartyStarted: dancePartyStarted,
            dancePartyEnded: dancePartyEnded
        )
    }
}
