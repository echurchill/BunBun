import Foundation

struct ChainStage: Equatable, Sendable {
    let depth: Int
    let removedCells: Set<Cell>
    let boardBefore: Board
    let boardAfter: Board
}

struct ChainResolution: Equatable, Sendable {
    let board: Board
    let stages: [ChainStage]

    var removedCount: Int {
        stages.reduce(0) { $0 + $1.removedCells.count }
    }
}

struct ChainResolver: Sendable {
    let matchEngine: MatchEngine

    init(matchEngine: MatchEngine = MatchEngine()) {
        self.matchEngine = matchEngine
    }

    /// The first stage must touch the player-placed bunny. Later stages may be
    /// any matches produced by compaction during the active chain.
    func resolve(board: Board, triggeredBy origin: Cell) -> ChainResolution {
        var board = board
        var stages: [ChainStage] = []
        var pending = matchEngine.match(containing: origin, on: board)

        while !pending.isEmpty {
            let depth = stages.count + 1
            let boardBefore = board
            board.remove(at: pending)
            board.compactTowardHazard()
            stages.append(ChainStage(
                depth: depth,
                removedCells: pending,
                boardBefore: boardBefore,
                boardAfter: board
            ))
            pending = matchEngine.allMatches(on: board).reduce(into: Set<Cell>()) {
                $0.formUnion($1)
            }
        }

        return ChainResolution(board: board, stages: stages)
    }
}
