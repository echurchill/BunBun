import Foundation

enum BunnyColor: String, CaseIterable, Codable, Sendable {
    case blue
    case green
    case orange
    case pink
    case purple
}

enum BunnyKind: String, Codable, Sendable {
    case normal
    case redBomb
    case lineClear
}

struct Bunny: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let color: BunnyColor
    let kind: BunnyKind

    init(id: UUID = UUID(), color: BunnyColor, kind: BunnyKind = .normal) {
        self.id = id
        self.color = color
        self.kind = kind
    }
}

struct Cell: Hashable, Codable, Sendable {
    let column: Int
    let row: Int

    func neighbor(columnDelta: Int, rowDelta: Int) -> Cell {
        Cell(column: column + columnDelta, row: row + rowDelta)
    }
}

enum LaunchSide: String, CaseIterable, Codable, Sendable {
    case left
    case right
    case bottom
}

enum LaunchResult: Equatable, Sendable {
    case placed(Cell)
    case passedThrough
    case blocked
}
