import Foundation

struct SpecialActivation: Equatable, Sendable {
    let cell: Cell
    let kind: BunnyKind
    let affectedCells: Set<Cell>
}

struct ChainStage: Equatable, Sendable {
    let depth: Int
    let matchedCells: Set<Cell>
    let removedCells: Set<Cell>
    let specialActivations: [SpecialActivation]
    let boardBefore: Board
    let boardAfter: Board

    var specialEffectRemovedCount: Int {
        removedCells.subtracting(matchedCells).count
    }
}

struct ChainResolution: Equatable, Sendable {
    let board: Board
    let stages: [ChainStage]

    var removedCount: Int {
        stages.reduce(0) { $0 + $1.removedCells.count }
    }

    var matchedCount: Int {
        stages.reduce(0) { $0 + $1.matchedCells.count }
    }

    var specialEffectRemovedCount: Int {
        stages.reduce(0) { $0 + $1.specialEffectRemovedCount }
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
            let expansion = expandedRemoval(startingWith: pending, on: board)
            board.remove(at: expansion.cells)
            board.compactAwayFromHazard()
            stages.append(ChainStage(
                depth: depth,
                matchedCells: pending,
                removedCells: expansion.cells,
                specialActivations: expansion.activations,
                boardBefore: boardBefore,
                boardAfter: board
            ))
            pending = matchEngine.allMatches(on: board).reduce(into: Set<Cell>()) {
                $0.formUnion($1)
            }
        }

        return ChainResolution(board: board, stages: stages)
    }

    /// Prototype 0.4 interpretation: a matched bomb removes its occupied 3×3
    /// neighborhood, while a matched line bunny removes its occupied row and
    /// column. A special caught by another special activates in the same stage.
    private func expandedRemoval(
        startingWith matchedCells: Set<Cell>,
        on board: Board
    ) -> (cells: Set<Cell>, activations: [SpecialActivation]) {
        var removedCells = matchedCells
        var activations: [SpecialActivation] = []
        var activatedCells: Set<Cell> = []
        var pendingSpecials = matchedCells.sorted(by: cellSort)

        while !pendingSpecials.isEmpty {
            let cell = pendingSpecials.removeFirst()
            guard !activatedCells.contains(cell),
                  let bunny = board[cell],
                  bunny.kind != .normal else { continue }

            activatedCells.insert(cell)
            let affectedCells = effectCells(for: bunny.kind, at: cell, on: board)
            activations.append(SpecialActivation(
                cell: cell,
                kind: bunny.kind,
                affectedCells: affectedCells
            ))

            let newlyAffected = affectedCells.subtracting(removedCells)
            removedCells.formUnion(affectedCells)
            pendingSpecials.append(contentsOf: newlyAffected.sorted(by: cellSort))
        }

        return (removedCells, activations)
    }

    private func effectCells(for kind: BunnyKind, at origin: Cell, on board: Board) -> Set<Cell> {
        let candidates: [Cell]

        switch kind {
        case .normal:
            candidates = []
        case .redBomb:
            candidates = (-1...1).flatMap { rowDelta in
                (-1...1).map { columnDelta in
                    origin.neighbor(columnDelta: columnDelta, rowDelta: rowDelta)
                }
            }
        case .lineClear:
            let row = (0..<board.columnCount).map { Cell(column: $0, row: origin.row) }
            let column = (0..<board.rowCount).map { Cell(column: origin.column, row: $0) }
            candidates = row + column
        }

        return Set(candidates.filter { board.contains($0) && board[$0] != nil })
    }

    private func cellSort(_ lhs: Cell, _ rhs: Cell) -> Bool {
        lhs.row == rhs.row ? lhs.column < rhs.column : lhs.row < rhs.row
    }
}
