import XCTest
@testable import BunBun

final class GamePressureTests: XCTestCase {
    func testOpeningBoardHasNoPassiveMatchAndFirstShotClearsBlueSetup() {
        let board = PrototypeLevel.startingBoard()
        XCTAssertTrue(MatchEngine().allMatches(on: board).isEmpty)

        var state = GameState(board: board)
        let outcome = state.launch(Bunny(color: .blue), from: .left, lane: 5)

        XCTAssertEqual(outcome.chain?.removedCount, 3)
        XCTAssertEqual(state.progress, 12)
        XCTAssertEqual(state.danceMeter, 42)
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

        let danceMatch = state.launch(Bunny(color: .green), from: .left, lane: 0)
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
        XCTAssertEqual(state.progress, 15)
        XCTAssertEqual(state.danger, 12)
        XCTAssertEqual(state.status, .playing)
    }

    func testRepeatedPitPressureEventuallyLoses() {
        var board = Board()
        XCTAssertTrue(board.place(Bunny(color: .purple), at: Cell(column: 4, row: 0)))
        var state = GameState(board: board, launchesSinceAdvance: 2, danger: 92)

        _ = state.launch(Bunny(color: .orange), from: .right, lane: 7)

        XCTAssertEqual(state.danger, 100)
        XCTAssertEqual(state.status, .lost)
    }

    func testFillingProgressWinsLevel() {
        var board = Board()
        XCTAssertTrue(board.place(Bunny(color: .pink), at: Cell(column: 2, row: 2)))
        XCTAssertTrue(board.place(Bunny(color: .pink), at: Cell(column: 3, row: 2)))
        var state = GameState(board: board, progress: 90)

        _ = state.launch(Bunny(color: .pink), from: .left, lane: 2)

        XCTAssertEqual(state.progress, 100)
        XCTAssertEqual(state.status, .won)
    }
}
