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

/// Deterministic generator used by the gameplay queue. A run can feel
/// unpredictable to the player while tests, replays, and bug reports remain
/// reproducible from the same seed.
struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

/// A board-aware shuffle bag for launch bunnies.
///
/// Every palette color is represented before the bag refills. Colors already
/// visible on the board receive a modest weight boost, and adjacent pairs get
/// one additional ticket. This recreates the original game's steady supply of
/// tempting near-matches without guaranteeing the player a useful shot. The
/// anti-streak rule prevents three identical normal colors in succession.
struct BunnyQueue: Sendable {
    private let palette: [BunnyColor]
    private var random: SeededRandomNumberGenerator
    private var bag: [BunnyColor] = []
    private var recentColors: [BunnyColor] = []

    init(seed: UInt64, palette: [BunnyColor]) {
        precondition(!palette.isEmpty)
        self.palette = Array(Set(palette)).sorted { $0.rawValue < $1.rawValue }
        random = SeededRandomNumberGenerator(seed: seed)
    }

    mutating func next(on board: Board, kind: BunnyKind = .normal) -> PrototypeShot {
        if bag.isEmpty {
            refill(using: board)
        }

        if recentColors.count >= 2,
           recentColors.suffix(2).allSatisfy({ $0 == recentColors.last }),
           bag.last == recentColors.last {
            if bag.lastIndex(where: { $0 != recentColors.last }) == nil {
                let deferred = bag
                refill(using: board)
                bag.insert(contentsOf: deferred, at: 0)
            }
            if let alternative = bag.lastIndex(where: { $0 != recentColors.last }) {
                bag.swapAt(alternative, bag.index(before: bag.endIndex))
            }
        }

        let color = bag.removeLast()
        recentColors.append(color)
        recentColors = Array(recentColors.suffix(2))
        return PrototypeShot(color: color, kind: kind)
    }

    private mutating func refill(using board: Board) {
        let counts = board.occupants.values.reduce(into: [BunnyColor: Int]()) {
            $0[$1.color, default: 0] += 1
        }
        let pairedColors = Set(board.occupants.compactMap { cell, bunny -> BunnyColor? in
            let right = cell.neighbor(columnDelta: 1, rowDelta: 0)
            let above = cell.neighbor(columnDelta: 0, rowDelta: 1)
            return board[right]?.color == bunny.color || board[above]?.color == bunny.color
                ? bunny.color
                : nil
        })

        bag = palette.flatMap { color in
            let boardTickets = min(3, counts[color, default: 0] / 3)
            let pairTicket = pairedColors.contains(color) ? 1 : 0
            return Array(repeating: color, count: 2 + boardTickets + pairTicket)
        }
        bag.shuffle(using: &random)
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
