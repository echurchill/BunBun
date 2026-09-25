import Foundation

enum PlayStatus: Equatable, Sendable {
    case playing
    case won
    case lost
}

struct TurnOutcome: Equatable, Sendable {
    let launchResult: LaunchResult
    let chain: ChainResolution?
    let didAdvance: Bool
    let fallenBunnies: [Bunny]
    let pointsAwarded: Int
}

struct GameState: Equatable, Sendable {
    static let launchesPerClassicAdvance = 3

    private(set) var board: Board
    private(set) var launchesSinceAdvance: Int
    private(set) var score: Int
    private(set) var progress: Int
    private(set) var danceMeter: Int
    private(set) var status: PlayStatus

    init(
        board: Board = Board(),
        launchesSinceAdvance: Int = 0,
        score: Int = 0,
        progress: Int = 0,
        danceMeter: Int = 0,
        status: PlayStatus = .playing
    ) {
        self.board = board
        self.launchesSinceAdvance = launchesSinceAdvance
        self.score = score
        self.progress = progress
        self.danceMeter = danceMeter
        self.status = status
    }

    mutating func launch(
        _ bunny: Bunny,
        from side: LaunchSide,
        lane: Int,
        newBackRow: [Int: Bunny] = [:],
        resolver: ChainResolver = ChainResolver()
    ) -> TurnOutcome {
        let launchResult = board.launch(bunny, from: side, lane: lane)
        var chain: ChainResolution?
        var points = 0

        if case let .placed(cell) = launchResult {
            let resolution = resolver.resolve(board: board, triggeredBy: cell)
            board = resolution.board
            chain = resolution.stages.isEmpty ? nil : resolution
            points = resolution.stages.reduce(0) { partial, stage in
                partial + stage.removedCells.count * 100 * stage.depth
            }
            score += points
        }

        launchesSinceAdvance += 1
        var didAdvance = false
        var fallen: [Bunny] = []
        if launchesSinceAdvance == Self.launchesPerClassicAdvance {
            // Advancement intentionally does not invoke the resolver. A passive
            // 3+ group waits for the next player-caused placement or active chain.
            fallen = board.advance(newBackRow: newBackRow)
            launchesSinceAdvance = 0
            didAdvance = true
        }

        return TurnOutcome(
            launchResult: launchResult,
            chain: chain,
            didAdvance: didAdvance,
            fallenBunnies: fallen,
            pointsAwarded: points
        )
    }
}
