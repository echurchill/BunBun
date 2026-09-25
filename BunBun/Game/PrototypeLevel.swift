import Foundation

struct PrototypeShot: Equatable, Sendable {
    let color: BunnyColor
    let kind: BunnyKind

    init(color: BunnyColor, kind: BunnyKind = .normal) {
        self.color = color
        self.kind = kind
    }

    func makeBunny() -> Bunny {
        Bunny(color: color, kind: kind)
    }
}

enum PrototypeLevel {
    /// The first four shots introduce two normal matches followed by one of
    /// each special. Later specials recur often enough for tuning playtests.
    static let shotSequence: [PrototypeShot] = [
        PrototypeShot(color: .blue),
        PrototypeShot(color: .green),
        PrototypeShot(color: .red, kind: .redBomb),
        PrototypeShot(color: .purple, kind: .lineClear),
        PrototypeShot(color: .orange),
        PrototypeShot(color: .pink),
        PrototypeShot(color: .blue),
        PrototypeShot(color: .green),
        PrototypeShot(color: .purple),
        PrototypeShot(color: .orange),
        PrototypeShot(color: .red, kind: .redBomb),
        PrototypeShot(color: .purple, kind: .lineClear),
        PrototypeShot(color: .pink)
    ]

    private static let arrivalPalette: [BunnyColor] = [
        .blue, .green, .orange, .pink, .purple
    ]

    static func shot(at index: Int) -> PrototypeShot {
        shotSequence[index % shotSequence.count]
    }

    static func shotColor(at index: Int) -> BunnyColor {
        shot(at: index).color
    }

    /// A match-free opening with two obvious setups: the first blue bunny can
    /// complete a pair from the left, and the second green bunny can complete a
    /// pair from the right. This makes the action pass easy to exercise.
    static func startingBoard() -> Board {
        var board = Board()
        let rows: [Int: [Int: BunnyColor]] = [
            7: [1: .orange, 2: .pink, 3: .green, 4: .purple, 5: .blue,
                6: .pink, 7: .green, 8: .orange, 9: .purple, 10: .purple],
            6: [1: .purple, 2: .orange, 3: .pink, 4: .blue, 5: .purple,
                6: .orange, 7: .pink, 8: .blue, 9: .green, 10: .green],
            5: [2: .blue, 3: .blue, 4: .orange, 5: .pink, 6: .purple,
                7: .green, 8: .orange, 9: .pink, 10: .blue],
            4: [1: .red, 2: .red, 3: .orange, 4: .purple, 5: .green,
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
            let color = arrivalPalette[(column * 2 + turn) % arrivalPalette.count]
            return (column, Bunny(color: color))
        })
    }
}
