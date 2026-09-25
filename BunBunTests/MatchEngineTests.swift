import XCTest
@testable import BunBun

final class MatchEngineTests: XCTestCase {
    private let engine = MatchEngine()

    func testHorizontalGroupOfThreeMatches() {
        let cells = [Cell(column: 2, row: 2), Cell(column: 3, row: 2), Cell(column: 4, row: 2)]
        let board = board(with: cells, color: .blue)

        XCTAssertEqual(engine.match(containing: cells[1], on: board), Set(cells))
    }

    func testVerticalGroupOfThreeMatches() {
        let cells = [Cell(column: 5, row: 1), Cell(column: 5, row: 2), Cell(column: 5, row: 3)]
        let board = board(with: cells, color: .green)

        XCTAssertEqual(engine.match(containing: cells[0], on: board), Set(cells))
    }

    func testLShapeIsOneConnectedMatch() {
        let cells = [
            Cell(column: 3, row: 2),
            Cell(column: 3, row: 3),
            Cell(column: 4, row: 2)
        ]
        let board = board(with: cells, color: .orange)

        XCTAssertEqual(engine.match(containing: cells[0], on: board), Set(cells))
    }

    func testDiagonalOnlyGroupDoesNotMatch() {
        let cells = [Cell(column: 2, row: 2), Cell(column: 3, row: 3), Cell(column: 4, row: 4)]
        let board = board(with: cells, color: .purple)

        XCTAssertTrue(engine.match(containing: cells[1], on: board).isEmpty)
    }

    func testTwoBunniesDoNotMatch() {
        let cells = [Cell(column: 6, row: 2), Cell(column: 6, row: 3)]
        let board = board(with: cells, color: .pink)

        XCTAssertTrue(engine.match(containing: cells[0], on: board).isEmpty)
    }

    private func board(with cells: [Cell], color: BunnyColor) -> Board {
        var board = Board()
        for cell in cells {
            XCTAssertTrue(board.place(Bunny(color: color), at: cell))
        }
        return board
    }
}
