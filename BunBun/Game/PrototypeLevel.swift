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
    /// Compatibility facade for Prototype 0.4 tests and notes. Runtime play
    /// now consumes the data-driven Bunny Lab definition directly.
    static var shotSequence: [PrototypeShot] { LevelCatalog.bunnyLab.shotSequence }

    static func shot(at index: Int) -> PrototypeShot {
        LevelCatalog.bunnyLab.shot(at: index)
    }

    static func shotColor(at index: Int) -> BunnyColor {
        shot(at: index).color
    }

    /// A match-free opening with two obvious setups: the first blue bunny can
    /// complete a pair from the left, and the second green bunny can complete a
    /// pair from the right. This makes the action pass easy to exercise.
    static func startingBoard() -> Board {
        LevelCatalog.bunnyLab.startingBoard()
    }

    static func advanceRow(forTurn turn: Int) -> [Int: Bunny] {
        LevelCatalog.bunnyLab.advanceRow(forTurn: turn)
    }
}
