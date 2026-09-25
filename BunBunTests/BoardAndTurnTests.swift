import XCTest
@testable import BunBun

final class BoardAndTurnTests: XCTestCase {
    func testSideLaunchPassesThroughEmptyRow() {
        var board = Board()
        let result = board.launch(Bunny(color: .blue), from: .left, lane: 4)

        XCTAssertEqual(result, .passedThrough)
        XCTAssertTrue(board.occupiedCells.isEmpty)
    }

    func testAdvanceSpawnsOnlyInMarchingColumns() {
        var board = Board()
        let entrants = [
            0: Bunny(color: .pink),
            1: Bunny(color: .green),
            10: Bunny(color: .orange),
            11: Bunny(color: .purple)
        ]

        board.advance(newBackRow: entrants)

        XCTAssertNil(board[Cell(column: 0, row: 7)])
        XCTAssertNotNil(board[Cell(column: 1, row: 7)])
        XCTAssertNotNil(board[Cell(column: 10, row: 7)])
        XCTAssertNil(board[Cell(column: 11, row: 7)])
    }

    func testEveryThirdLaunchAdvancesWithoutPassivelyResolvingMatch() {
        var board = Board()
        for column in 2...4 {
            XCTAssertTrue(board.place(Bunny(color: .green), at: Cell(column: column, row: 2)))
        }
        var state = GameState(board: board)

        let first = state.launch(Bunny(color: .blue), from: .left, lane: 7)
        let second = state.launch(Bunny(color: .orange), from: .right, lane: 7)
        let third = state.launch(Bunny(color: .purple), from: .left, lane: 7)

        XCTAssertFalse(first.didAdvance)
        XCTAssertFalse(second.didAdvance)
        XCTAssertTrue(third.didAdvance)
        XCTAssertEqual(state.launchesSinceAdvance, 0)

        let passiveMatch = MatchEngine().allMatches(on: state.board)
        XCTAssertEqual(passiveMatch.count, 1)
        XCTAssertEqual(passiveMatch[0].count, 3)
    }
}
