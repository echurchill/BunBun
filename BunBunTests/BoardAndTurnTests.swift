import XCTest
import SpriteKit
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

    @MainActor
    func testBunnyNodeKeepsGeneratedTextureInsideItsBoardCell() async throws {
        let cellWidth: CGFloat = 31
        let cellHeight: CGFloat = 45.5
        let immediateIdleID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000004")
        )
        let node = BunnyNode(
            bunny: Bunny(id: immediateIdleID, color: .blue),
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            color: .systemBlue
        )
        let scene = SKScene(size: CGSize(width: 390, height: 844))
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scene.addChild(node)
        view.presentScene(scene)

        // This ID belongs to idle cohort zero, so its generated texture action
        // starts immediately. Waiting catches a resize that initial-state tests
        // cannot see.
        try await Task.sleep(for: .milliseconds(1_400))

        let renderedBounds = node.calculateAccumulatedFrame()

        XCTAssertLessThanOrEqual(renderedBounds.width, cellWidth * 1.2)
        XCTAssertLessThanOrEqual(renderedBounds.height, cellHeight * 1.2)
    }

    @MainActor
    func testBunnyNodeKeepsItsSizeWhenIdleIsInterruptedByCelebration() async throws {
        let cellWidth: CGFloat = 31
        let cellHeight: CGFloat = 45.5
        let immediateIdleID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000004")
        )
        let node = BunnyNode(
            bunny: Bunny(id: immediateIdleID, color: .orange),
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            color: .systemYellow
        )
        let scene = SKScene(size: CGSize(width: 390, height: 844))
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scene.addChild(node)
        view.presentScene(scene)

        // Reproduce the reported path: the yellow/orange cohort begins its
        // idle gesture and is immediately switched to the match celebration.
        try await Task.sleep(for: .milliseconds(80))
        node.playCelebration(chainDepth: 1)

        // Also prove that the final render-pass guard repairs any native-size
        // frame left behind by an interrupted SpriteKit texture action.
        let sprite = try XCTUnwrap(node.children.compactMap { $0 as? SKSpriteNode }.first)
        sprite.size = CGSize(width: 2_048, height: 2_048)
        node.enforceDisplaySize()

        for _ in 0..<8 {
            try await Task.sleep(for: .milliseconds(75))
            let renderedBounds = node.calculateAccumulatedFrame()
            XCTAssertLessThanOrEqual(renderedBounds.width, cellWidth * 1.2)
            XCTAssertLessThanOrEqual(renderedBounds.height, cellHeight * 1.2)
        }
    }
}
