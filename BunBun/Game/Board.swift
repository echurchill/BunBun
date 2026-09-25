import Foundation

struct Board: Equatable, Sendable {
    static let prototypeColumns = 12
    static let prototypeRows = 8
    static let marchingColumns = 1...10
    static let outsideColumns: Set<Int> = [0, 11]

    let columnCount: Int
    let rowCount: Int
    private(set) var occupants: [Cell: Bunny]

    init(
        columnCount: Int = Board.prototypeColumns,
        rowCount: Int = Board.prototypeRows,
        occupants: [Cell: Bunny] = [:]
    ) {
        precondition(columnCount > 0 && rowCount > 0)
        self.columnCount = columnCount
        self.rowCount = rowCount
        self.occupants = occupants.filter { cell, _ in
            (0..<columnCount).contains(cell.column) && (0..<rowCount).contains(cell.row)
        }
    }

    subscript(cell: Cell) -> Bunny? {
        get { occupants[cell] }
        set {
            precondition(contains(cell), "Cell is outside the board")
            occupants[cell] = newValue
        }
    }

    func contains(_ cell: Cell) -> Bool {
        (0..<columnCount).contains(cell.column) && (0..<rowCount).contains(cell.row)
    }

    var occupiedCells: Set<Cell> {
        Set(occupants.keys)
    }

    mutating func place(_ bunny: Bunny, at cell: Cell) -> Bool {
        guard contains(cell), occupants[cell] == nil else { return false }
        occupants[cell] = bunny
        return true
    }

    mutating func remove(at cells: Set<Cell>) {
        for cell in cells {
            occupants.removeValue(forKey: cell)
        }
    }

    @discardableResult
    mutating func launch(_ bunny: Bunny, from side: LaunchSide, lane: Int) -> LaunchResult {
        let target: Cell?

        switch side {
        case .bottom:
            guard (0..<columnCount).contains(lane) else { return .blocked }
            let occupiedRows = occupants.keys
                .filter { $0.column == lane }
                .map(\.row)
                .sorted()
            if let first = occupiedRows.first {
                target = first > 0 ? Cell(column: lane, row: first - 1) : nil
            } else {
                target = Cell(column: lane, row: rowCount - 1)
            }

        case .left:
            guard (0..<rowCount).contains(lane) else { return .blocked }
            let occupiedColumns = occupants.keys
                .filter { $0.row == lane }
                .map(\.column)
                .sorted()
            guard let first = occupiedColumns.first else { return .passedThrough }
            target = first > 0 ? Cell(column: first - 1, row: lane) : nil

        case .right:
            guard (0..<rowCount).contains(lane) else { return .blocked }
            let occupiedColumns = occupants.keys
                .filter { $0.row == lane }
                .map(\.column)
                .sorted(by: >)
            guard let first = occupiedColumns.first else { return .passedThrough }
            target = first < columnCount - 1 ? Cell(column: first + 1, row: lane) : nil
        }

        guard let target, place(bunny, at: target) else { return .blocked }
        return .placed(target)
    }

    /// Closes holes after a successful clear by packing each column against
    /// the back/arrival edge. Clearing bunnies therefore creates space near
    /// the hazard; only Classic advancement moves the formation toward danger.
    mutating func compactAwayFromHazard() {
        for column in 0..<columnCount {
            let bunnies = occupants
                .filter { $0.key.column == column }
                .sorted { $0.key.row < $1.key.row }
                .map(\.value)

            occupants = occupants.filter { $0.key.column != column }
            let firstRow = rowCount - bunnies.count
            for (offset, bunny) in bunnies.enumerated() {
                let row = firstRow + offset
                occupants[Cell(column: column, row: row)] = bunny
            }
        }
    }

    /// Moves the formation one step toward row zero. New marching bunnies may
    /// only enter ordinary columns; outside lanes never spawn them.
    @discardableResult
    mutating func advance(newBackRow: [Int: Bunny] = [:]) -> [Bunny] {
        var moved: [Cell: Bunny] = [:]
        var fallen: [Bunny] = []

        for (cell, bunny) in occupants {
            let next = cell.neighbor(columnDelta: 0, rowDelta: -1)
            if next.row < 0 {
                fallen.append(bunny)
            } else {
                moved[next] = bunny
            }
        }

        for (column, bunny) in newBackRow where Board.marchingColumns.contains(column) {
            let cell = Cell(column: column, row: rowCount - 1)
            if moved[cell] == nil {
                moved[cell] = bunny
            }
        }

        occupants = moved
        return fallen
    }
}
