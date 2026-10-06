import XCTest
@testable import BunBun

final class ChainResolverTests: XCTestCase {
    func testOpeningMatchMovesOnlyBunniesBelowTheClearedRowBackward() throws {
        var board = LevelCatalog.bunnyLab.startingBoard()
        let launch = board.launch(Bunny(color: .blue), from: .left, lane: 5)
        guard case let .placed(origin) = launch else {
            return XCTFail("Opening tutorial shot should be placed")
        }

        let result = ChainResolver().resolve(board: board, triggeredBy: origin)
        let stage = try XCTUnwrap(result.stages.first)
        let oldCells = Dictionary(uniqueKeysWithValues: stage.boardBefore.occupants.map { ($0.value.id, $0.key) })
        let newCells = Dictionary(uniqueKeysWithValues: stage.boardAfter.occupants.map { ($0.value.id, $0.key) })
        let movements = oldCells.compactMap { id, oldCell -> (Cell, Cell)? in
            guard let newCell = newCells[id], newCell != oldCell else { return nil }
            return (oldCell, newCell)
        }

        XCTAssertEqual(movements.count, 3)
        XCTAssertTrue(movements.allSatisfy { oldCell, newCell in
            (1...3).contains(oldCell.column)
                && oldCell.row == 4
                && newCell == Cell(column: oldCell.column, row: 5)
        })
    }

    func testMatchDoesNotPullAnUntouchedGappedColumnBackward() throws {
        var board = Board()
        for column in 2...4 {
            XCTAssertTrue(board.place(Bunny(color: .pink), at: Cell(column: column, row: 4)))
        }

        let untouchedBunnies = [
            Bunny(color: .blue),
            Bunny(color: .green),
            Bunny(color: .orange)
        ]
        for (row, bunny) in zip(3...5, untouchedBunnies) {
            XCTAssertTrue(board.place(bunny, at: Cell(column: 8, row: row)))
        }

        let result = ChainResolver().resolve(
            board: board,
            triggeredBy: Cell(column: 3, row: 4)
        )

        let stage = try XCTUnwrap(result.stages.first)
        for (row, bunny) in zip(3...5, untouchedBunnies) {
            XCTAssertEqual(stage.boardAfter[Cell(column: 8, row: row)], bunny)
        }
        XCTAssertNil(stage.boardAfter[Cell(column: 8, row: 7)])
    }

    func testCompactionCreatesSecondChainStage() {
        var board = Board()

        for (column, blueRow) in zip(2...4, [1, 3, 5]) {
            XCTAssertTrue(board.place(Bunny(color: .pink), at: Cell(column: column, row: 6)))
            XCTAssertTrue(board.place(Bunny(color: .blue), at: Cell(column: column, row: blueRow)))
        }

        let result = ChainResolver().resolve(
            board: board,
            triggeredBy: Cell(column: 3, row: 6)
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

    func testSuccessfulClearCompactsSurvivorsAwayFromHazard() {
        var board = Board()
        for column in 2...4 {
            XCTAssertTrue(board.place(Bunny(color: .pink), at: Cell(column: column, row: 4)))
        }
        let survivor = Bunny(color: .blue)
        XCTAssertTrue(board.place(survivor, at: Cell(column: 2, row: 2)))

        let result = ChainResolver().resolve(
            board: board,
            triggeredBy: Cell(column: 3, row: 4)
        )

        XCTAssertEqual(result.board[Cell(column: 2, row: 7)], survivor)
        XCTAssertNil(result.board[Cell(column: 2, row: 0)])
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
        XCTAssertEqual(result.board[farAway], board[farAway])
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
        XCTAssertEqual(result.board[untouched], board[untouched])
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
