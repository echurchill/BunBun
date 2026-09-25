import XCTest
@testable import BunBun

final class ChainResolverTests: XCTestCase {
    func testCompactionCreatesSecondChainStage() {
        var board = Board()

        for column in 2...4 {
            XCTAssertTrue(board.place(Bunny(color: .pink), at: Cell(column: column, row: 0)))
            XCTAssertTrue(board.place(Bunny(color: .blue), at: Cell(column: column, row: 1)))
        }

        let result = ChainResolver().resolve(
            board: board,
            triggeredBy: Cell(column: 3, row: 0)
        )

        XCTAssertEqual(result.stages.count, 2)
        XCTAssertEqual(result.stages[0].depth, 1)
        XCTAssertEqual(result.stages[0].removedCells.count, 3)
        XCTAssertEqual(result.stages[1].depth, 2)
        XCTAssertEqual(result.stages[1].removedCells.count, 3)
        XCTAssertEqual(result.removedCount, 6)
        XCTAssertTrue(result.board.occupiedCells.isEmpty)
    }

    func testUnrelatedExistingMatchDoesNotStartWithoutTriggeredMatch() {
        var board = Board()
        for column in 2...4 {
            XCTAssertTrue(board.place(Bunny(color: .green), at: Cell(column: column, row: 0)))
        }
        let trigger = Cell(column: 8, row: 4)
        XCTAssertTrue(board.place(Bunny(color: .orange), at: trigger))

        let result = ChainResolver().resolve(board: board, triggeredBy: trigger)

        XCTAssertTrue(result.stages.isEmpty)
        XCTAssertEqual(result.board, board)
    }
}
