import SpriteKit
import XCTest
@testable import BunBun

final class EndPanelTests: XCTestCase {
    private func context(
        status: PlayStatus = .won,
        score: Int = 1200,
        hasNextLevel: Bool = true,
        size: CGSize = CGSize(width: 390, height: 844),
        isTablet: Bool = false,
        panelScale: CGFloat = 1
    ) -> EndPanel.Context {
        EndPanel.Context(
            status: status,
            score: score,
            stats: EndPanel.RunStats(
                launches: 14,
                falls: 1,
                specialActivations: 2,
                danceParties: 1,
                elapsedSeconds: 96
            ),
            hasNextLevel: hasNextLevel,
            size: size,
            boardCenter: CGPoint(x: size.width / 2, y: size.height / 2),
            isTablet: isTablet,
            panelScale: panelScale
        )
    }

    private func panelShape(_ node: SKNode) throws -> SKShapeNode {
        try XCTUnwrap(node as? SKShapeNode)
    }

    @MainActor
    func testPhoneWinPanelKeepsLegacyGeometry() throws {
        let node = EndPanel.makeNode(context: context())
        let panel = try panelShape(node)

        XCTAssertEqual(panel.path?.boundingBox.size ?? .zero, CGSize(width: 330, height: 250))
        XCTAssertEqual(node.position, CGPoint(x: 195, y: 422))

        let labels = node.children.compactMap { $0 as? SKLabelNode }
        let title = try XCTUnwrap(labels.first { $0.text == "LEVEL COMPLETE!" })
        XCTAssertEqual(title.fontSize, 23)
        XCTAssertTrue(labels.contains { $0.text == "Score 1200" })

        let next = try XCTUnwrap(node.childNode(withName: "control:next") as? SKShapeNode)
        XCTAssertEqual(next.path?.boundingBox.size ?? .zero, CGSize(width: 174, height: 31))
        XCTAssertEqual(next.position.y, -24)
    }

    @MainActor
    func testTelevisionPanelScalesGeometryAndFonts() throws {
        let node = EndPanel.makeNode(context: context(
            size: CGSize(width: 1920, height: 1080),
            panelScale: 1.75
        ))
        let panel = try panelShape(node)

        XCTAssertEqual(panel.path?.boundingBox.width ?? 0, 330 * 1.75, accuracy: 0.001)
        XCTAssertEqual(panel.path?.boundingBox.height ?? 0, 250 * 1.75, accuracy: 0.001)

        let labels = node.children.compactMap { $0 as? SKLabelNode }
        let title = try XCTUnwrap(labels.first { $0.text == "LEVEL COMPLETE!" })
        XCTAssertEqual(title.fontSize, 23 * 1.75, accuracy: 0.001)

        let next = try XCTUnwrap(node.childNode(withName: "control:next") as? SKShapeNode)
        XCTAssertEqual(next.path?.boundingBox.width ?? 0, 174 * 1.75, accuracy: 0.001)
        XCTAssertEqual(next.path?.boundingBox.height ?? 0, 31 * 1.75, accuracy: 0.001)
        XCTAssertEqual(next.position.y, -24 * 1.75, accuracy: 0.001)
    }

    @MainActor
    func testLossPanelOffersRetryWithoutNext() throws {
        let node = EndPanel.makeNode(context: context(status: .lost))

        XCTAssertNil(node.childNode(withName: "control:next"))
        let retry = try XCTUnwrap(node.childNode(withName: "control:replay"))
        let retryLabel = try XCTUnwrap(retry.children.compactMap { $0 as? SKLabelNode }.first)
        XCTAssertEqual(retryLabel.text, "RETRY")
        XCTAssertNotNil(node.childNode(withName: "control:levels"))
    }

    @MainActor
    func testFinalLevelOmitsNextButton() throws {
        let node = EndPanel.makeNode(context: context(hasNextLevel: false))

        XCTAssertNil(node.childNode(withName: "control:next"))
        let replay = try XCTUnwrap(node.childNode(withName: "control:replay"))
        XCTAssertEqual(replay.position.y, -38)
    }
}
