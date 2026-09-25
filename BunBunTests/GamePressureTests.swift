import XCTest
@testable import BunBun

final class GamePressureTests: XCTestCase {
    func testOpeningBoardHasNoPassiveMatchAndFirstShotClearsBlueSetup() {
        let board = PrototypeLevel.startingBoard()
        XCTAssertTrue(MatchEngine().allMatches(on: board).isEmpty)

        var state = GameState(board: board)
        let outcome = state.launch(Bunny(color: .blue), from: .left, lane: 5)

        XCTAssertEqual(outcome.chain?.removedCount, 3)
        XCTAssertEqual(state.progress, 9)
        XCTAssertEqual(state.danceMeter, 42)
        XCTAssertTrue(
            outcome.boardAfterResolution.occupiedCells.allSatisfy { $0.row >= 4 },
            "A successful opening match must not pull the formation toward the hazard"
        )
    }

    func testOpeningSequenceIntroducesBothSpecialBunnies() {
        var state = GameState(board: PrototypeLevel.startingBoard())

        let blue = state.launch(PrototypeLevel.shot(at: 0).makeBunny(), from: .left, lane: 5)
        let green = state.launch(PrototypeLevel.shot(at: 1).makeBunny(), from: .right, lane: 6)
        let bomb = state.launch(
            PrototypeLevel.shot(at: 2).makeBunny(),
            from: .left,
            lane: 5,
            newBackRow: PrototypeLevel.advanceRow(forTurn: 2)
        )
        let line = state.launch(PrototypeLevel.shot(at: 3).makeBunny(), from: .right, lane: 6)

        XCTAssertEqual(blue.chain?.matchedCount, 3)
        XCTAssertEqual(green.chain?.matchedCount, 3)
        XCTAssertTrue(bomb.didAdvance)
        XCTAssertEqual(bomb.chain?.stages.first?.specialActivations.map(\.kind), [.redBomb])
        XCTAssertEqual(line.chain?.stages.first?.specialActivations.map(\.kind), [.lineClear])
        XCTAssertGreaterThan(bomb.chain?.specialEffectRemovedCount ?? 0, 0)
        XCTAssertGreaterThan(line.chain?.specialEffectRemovedCount ?? 0, 0)
    }

    func testDancePartyStartsThenDoublesFollowingMatch() {
        var board = Board()
        for column in 2...3 {
            XCTAssertTrue(board.place(Bunny(color: .blue), at: Cell(column: column, row: 1)))
            XCTAssertTrue(board.place(Bunny(color: .green), at: Cell(column: column, row: 3)))
        }
        var state = GameState(board: board, danceMeter: 70)

        let opening = state.launch(Bunny(color: .blue), from: .left, lane: 1)
        XCTAssertTrue(opening.dancePartyStarted)
        XCTAssertTrue(state.isDancePartyActive)
        XCTAssertEqual(state.dancePartyTurnsRemaining, 4)

        let danceMatch = state.launch(Bunny(color: .green), from: .left, lane: 7)
        XCTAssertEqual(danceMatch.scoreMultiplier, 2)
        XCTAssertEqual(danceMatch.pointsAwarded, 600)
        XCTAssertEqual(state.dancePartyTurnsRemaining, 3)
    }

    func testOneFallenBunnyAddsDangerButDoesNotEndGame() {
        var board = Board()
        XCTAssertTrue(board.place(Bunny(color: .purple), at: Cell(column: 4, row: 0)))
        var state = GameState(board: board, launchesSinceAdvance: 2, progress: 20)

        let outcome = state.launch(Bunny(color: .orange), from: .left, lane: 7)

        XCTAssertTrue(outcome.didAdvance)
        XCTAssertEqual(outcome.fallenBunnies.count, 1)
        XCTAssertEqual(state.progress, 16)
        XCTAssertEqual(outcome.progressDelta, -4)
        XCTAssertEqual(state.danger, 6)
        XCTAssertEqual(state.status, .playing)
    }

    func testSpecialEffectBunniesAwardLessProgressThanMatchedBunnies() {
        var board = Board()
        XCTAssertTrue(board.place(Bunny(color: .red), at: Cell(column: 1, row: 1)))
        XCTAssertTrue(board.place(Bunny(color: .red), at: Cell(column: 2, row: 1)))
        XCTAssertTrue(board.place(Bunny(color: .blue), at: Cell(column: 1, row: 0)))
        var state = GameState(board: board)

        let outcome = state.launch(Bunny(color: .red, kind: .redBomb), from: .left, lane: 1)

        XCTAssertEqual(outcome.chain?.matchedCount, 3)
        XCTAssertEqual(outcome.chain?.specialEffectRemovedCount, 1)
        XCTAssertEqual(state.progress, 10)
        XCTAssertEqual(outcome.pointsAwarded, 400)
    }

    func testRepeatedPitPressureEventuallyLoses() {
        var board = Board()
        XCTAssertTrue(board.place(Bunny(color: .purple), at: Cell(column: 4, row: 0)))
        var state = GameState(board: board, launchesSinceAdvance: 2, danger: 95)

        _ = state.launch(Bunny(color: .orange), from: .right, lane: 7)

        XCTAssertEqual(state.danger, 100)
        XCTAssertEqual(state.status, .lost)
    }

    func testFillingProgressWinsLevel() {
        var board = Board()
        XCTAssertTrue(board.place(Bunny(color: .pink), at: Cell(column: 2, row: 2)))
        XCTAssertTrue(board.place(Bunny(color: .pink), at: Cell(column: 3, row: 2)))
        var state = GameState(board: board, progress: 91)

        _ = state.launch(Bunny(color: .pink), from: .left, lane: 2)

        XCTAssertEqual(state.progress, 100)
        XCTAssertEqual(state.status, .won)
    }
}
