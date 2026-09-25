import Foundation

enum PrototypeLevel {
    static let shotSequence: [BunnyColor] = [.blue, .green, .orange, .pink, .purple]

    static func shotColor(at index: Int) -> BunnyColor {
        shotSequence[index % shotSequence.count]
    }

    /// A match-free opening with two obvious setups: the first blue bunny can
    /// complete a pair from the left, and the second green bunny can complete a
    /// pair from the right. This makes the action pass easy to exercise.
    static func startingBoard() -> Board {
        var board = Board()
        let rows: [Int: [Int: BunnyColor]] = [
            7: [1: .orange, 2: .pink, 3: .green, 4: .purple, 5: .blue,
                6: .pink, 7: .green, 8: .orange, 9: .purple, 10: .blue],
            6: [1: .purple, 2: .orange, 3: .pink, 4: .blue, 5: .purple,
                6: .orange, 7: .pink, 8: .green, 9: .green],
            5: [2: .blue, 3: .blue, 4: .orange, 5: .pink, 6: .purple,
                7: .green, 8: .orange, 9: .pink, 10: .purple],
            4: [1: .pink, 2: .green, 3: .orange, 4: .purple, 5: .green,
                6: .orange, 7: .blue, 8: .purple, 9: .blue, 10: .orange]
        ]

        for (row, columns) in rows {
            for (column, color) in columns {
                _ = board.place(Bunny(color: color), at: Cell(column: column, row: row))
            }
        }
        return board
    }

    static func advanceRow(forTurn turn: Int) -> [Int: Bunny] {
        Dictionary(uniqueKeysWithValues: Board.marchingColumns.compactMap { column in
            guard (column + turn) % 5 != 0 else { return nil }
            let color = shotSequence[(column * 2 + turn) % shotSequence.count]
            return (column, Bunny(color: color))
        })
    }
}
