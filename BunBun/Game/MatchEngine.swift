import Foundation

struct MatchEngine: Sendable {
    private let neighborOffsets = [
        (column: -1, row: 0),
        (column: 1, row: 0),
        (column: 0, row: -1),
        (column: 0, row: 1)
    ]

    func match(containing origin: Cell, on board: Board) -> Set<Cell> {
        guard let originBunny = board[origin] else { return [] }

        var visited: Set<Cell> = []
        var pending = [origin]

        while let cell = pending.popLast() {
            guard !visited.contains(cell), board[cell]?.color == originBunny.color else { continue }
            visited.insert(cell)

            for offset in neighborOffsets {
                let neighbor = cell.neighbor(
                    columnDelta: offset.column,
                    rowDelta: offset.row
                )
                if board.contains(neighbor), !visited.contains(neighbor) {
                    pending.append(neighbor)
                }
            }
        }

        return visited.count >= 3 ? visited : []
    }

    func allMatches(on board: Board) -> [Set<Cell>] {
        var examined: Set<Cell> = []
        var matches: [Set<Cell>] = []

        for cell in board.occupiedCells.sorted(by: cellSort) where !examined.contains(cell) {
            let connected = connectedComponent(containing: cell, on: board)
            examined.formUnion(connected)
            if connected.count >= 3 {
                matches.append(connected)
            }
        }

        return matches
    }

    private func connectedComponent(containing origin: Cell, on board: Board) -> Set<Cell> {
        guard let originBunny = board[origin] else { return [] }
        var visited: Set<Cell> = []
        var pending = [origin]

        while let cell = pending.popLast() {
            guard !visited.contains(cell), board[cell]?.color == originBunny.color else { continue }
            visited.insert(cell)
            for offset in neighborOffsets {
                let neighbor = cell.neighbor(columnDelta: offset.column, rowDelta: offset.row)
                if board.contains(neighbor), !visited.contains(neighbor) {
                    pending.append(neighbor)
                }
            }
        }
        return visited
    }

    private func cellSort(_ lhs: Cell, _ rhs: Cell) -> Bool {
        lhs.row == rhs.row ? lhs.column < rhs.column : lhs.row < rhs.row
    }
}
