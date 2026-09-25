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
        XCTAssertEqual(result.stages[0].boardBefore.occupiedCells.count, 6)
        XCTAssertEqual(result.stages[0].boardAfter.occupiedCells.count, 3)
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

    func testMatchedRedBombRemovesOccupiedThreeByThreeNeighborhood() {
        var board = Board()
        let match = [
            Cell(column: 2, row: 2),
            Cell(column: 3, row: 2),
            Cell(column: 4, row: 2)
        ]
        XCTAssertTrue(board.place(Bunny(color: .red), at: match[0]))
        XCTAssertTrue(board.place(Bunny(color: .red, kind: .redBomb), at: match[1]))
        XCTAssertTrue(board.place(Bunny(color: .red), at: match[2]))

        let nearby = Cell(column: 3, row: 3)
        let farAway = Cell(column: 8, row: 6)
        XCTAssertTrue(board.place(Bunny(color: .blue), at: nearby))
        XCTAssertTrue(board.place(Bunny(color: .green), at: farAway))

        let result = ChainResolver().resolve(board: board, triggeredBy: match[1])

        XCTAssertEqual(result.stages.count, 1)
        XCTAssertEqual(result.stages[0].matchedCells, Set(match))
        XCTAssertTrue(result.stages[0].removedCells.contains(nearby))
        XCTAssertEqual(result.stages[0].specialActivations.map(\.kind), [.redBomb])
        XCTAssertEqual(result.specialEffectRemovedCount, 1)
        XCTAssertNotNil(result.board[Cell(column: farAway.column, row: 0)])
    }

    func testMatchedLineBunnyClearsItsRowAndColumn() {
        var board = Board()
        let origin = Cell(column: 3, row: 2)
        let matched = [Cell(column: 2, row: 2), origin, Cell(column: 4, row: 2)]
        XCTAssertTrue(board.place(Bunny(color: .purple), at: matched[0]))
        XCTAssertTrue(board.place(Bunny(color: .purple, kind: .lineClear), at: origin))
        XCTAssertTrue(board.place(Bunny(color: .purple), at: matched[2]))

        let sameRow = Cell(column: 8, row: 2)
        let sameColumn = Cell(column: 3, row: 6)
        let untouched = Cell(column: 9, row: 6)
        XCTAssertTrue(board.place(Bunny(color: .blue), at: sameRow))
        XCTAssertTrue(board.place(Bunny(color: .green), at: sameColumn))
        XCTAssertTrue(board.place(Bunny(color: .orange), at: untouched))

        let result = ChainResolver().resolve(board: board, triggeredBy: origin)

        XCTAssertEqual(result.stages.count, 1)
        XCTAssertTrue(result.stages[0].removedCells.isSuperset(of: Set([sameRow, sameColumn])))
        XCTAssertEqual(result.stages[0].specialActivations.map(\.kind), [.lineClear])
        XCTAssertEqual(result.specialEffectRemovedCount, 2)
        XCTAssertNotNil(result.board[Cell(column: untouched.column, row: 0)])
    }

    func testSpecialCaughtByBombActivatesInSameStage() {
        var board = Board()
        let bomb = Cell(column: 2, row: 2)
        XCTAssertTrue(board.place(Bunny(color: .red), at: Cell(column: 0, row: 2)))
        XCTAssertTrue(board.place(Bunny(color: .red), at: Cell(column: 1, row: 2)))
        XCTAssertTrue(board.place(Bunny(color: .red, kind: .redBomb), at: bomb))

        let caughtLineBunny = Cell(column: 3, row: 2)
        let lineTarget = Cell(column: 3, row: 6)
        XCTAssertTrue(board.place(Bunny(color: .purple, kind: .lineClear), at: caughtLineBunny))
        XCTAssertTrue(board.place(Bunny(color: .blue), at: lineTarget))

        let result = ChainResolver().resolve(board: board, triggeredBy: bomb)

        XCTAssertEqual(result.stages.count, 1)
        XCTAssertEqual(result.stages[0].specialActivations.map(\.kind), [.redBomb, .lineClear])
        XCTAssertTrue(result.stages[0].removedCells.contains(lineTarget))
    }
}
