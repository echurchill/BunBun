import SpriteKit
import XCTest
@testable import BunBun

final class HUDTests: XCTestCase {
    private func context(
        levelName: String = "Bunny Lab",
        subtitle: String = "Tap a side box",
        debugControlText: String? = nil,
        debugLine: String? = nil,
        meters: [HUD.Meter] = [
            HUD.Meter(title: "PROGRESS", value: 50, maximumValue: 100, color: .systemGreen),
            HUD.Meter(title: "DANCE", value: 0, maximumValue: 100, color: .systemPurple),
            HUD.Meter(title: "DANGER", value: 100, maximumValue: 100, color: .systemRed),
        ],
        shotKind: BunnyKind = .normal,
        score: Int = 1200,
        launchesUntilAdvance: Int = 2,
        danceActive: Bool = false,
        isTelevision: Bool = false,
        hudScale: CGFloat = 1,
        televisionStatus: String? = nil
    ) -> HUD.Context {
        HUD.Context(
            size: CGSize(width: 390, height: 844),
            boardOriginY: 200,
            cellHeight: 45.5,
            isTablet: false,
            isTelevision: isTelevision,
            hudScale: hudScale,
            levelName: levelName,
            campaignStatus: "LEVEL 1  •  SPRINGTIME CAMP IN 2",
            appVersion: "0.5",
            subtitle: subtitle,
            debugControlText: debugControlText,
            debugLine: debugLine,
            meters: meters,
            previewBunny: Bunny(color: .blue),
            previewTint: .systemBlue,
            shotKind: shotKind,
            score: score,
            launchesUntilAdvance: launchesUntilAdvance,
            danceActive: danceActive,
            televisionStatus: televisionStatus
        )
    }

    @MainActor
    private func labels(in layer: SKNode) -> [SKLabelNode] {
        layer.children.compactMap { $0 as? SKLabelNode }
    }

    @MainActor
    func testPhoneHUDBuildsTitleControlsMetersAndPreview() throws {
        let layer = SKNode()
        HUD.render(in: layer, context: context())

        let title = try XCTUnwrap(labels(in: layer).first { $0.text == "BUNBUN  •  BUNNY LAB 0.5" })
        XCTAssertEqual(title.fontSize, 19)
        XCTAssertTrue(labels(in: layer).contains { $0.text == "Tap a side box" })

        let restart = try XCTUnwrap(layer.childNode(withName: "control:restart"))
        XCTAssertEqual((restart as? SKLabelNode)?.text, "RESTART")
        XCTAssertNil(layer.childNode(withName: "control:debug"))

        XCTAssertEqual(layer.children.compactMap({ $0 as? BunnyNode }).count, 1)
        let caption = try XCTUnwrap(labels(in: layer).first { $0.text?.hasPrefix("Next") == true })
        XCTAssertEqual(caption.text, "Next   •   Hop in 2")
        XCTAssertTrue(labels(in: layer).contains { $0.text == "0001200" })
        XCTAssertTrue(labels(in: layer).contains { $0.text == "LEVEL 1  •  SPRINGTIME CAMP IN 2" })

        // Title, subtitle, restart, 3 meter labels, 3 tracks, 2 fills
        // (the zero dance meter draws no fill), preview, caption.
        XCTAssertEqual(layer.children.count, 15)
    }

    @MainActor
    func testLongLevelNameUsesCompactTitle() throws {
        let layer = SKNode()
        HUD.render(in: layer, context: context(levelName: "Snowflake Shuffle"))

        let title = try XCTUnwrap(labels(in: layer).first { $0.text?.hasPrefix("BUNBUN") == true })
        XCTAssertEqual(title.fontSize, 16)
    }

    @MainActor
    func testMeterFillsTrackFractionAndOmitEmptyMeters() {
        let layer = SKNode()
        HUD.render(in: layer, context: context())

        let fills = layer.children
            .compactMap { $0 as? SKShapeNode }
            .filter { $0.zPosition == 1 }
            .map { $0.path?.boundingBox.width ?? -1 }
            .sorted()
        // Progress at half of the 92pt phone meter, danger full, dance omitted.
        XCTAssertEqual(fills, [46, 92])
    }

    @MainActor
    func testMeterFillClampsOverfullValues() {
        let layer = SKNode()
        HUD.render(in: layer, context: context(meters: [
            HUD.Meter(title: "PROGRESS", value: 150, maximumValue: 100, color: .systemGreen),
        ]))

        let fills = layer.children
            .compactMap { $0 as? SKShapeNode }
            .filter { $0.zPosition == 1 }
        XCTAssertEqual(fills.count, 1)
        XCTAssertEqual(fills.first?.path?.boundingBox.width ?? -1, 92)
    }

    @MainActor
    func testBombShotAndDancePartyCaption() throws {
        let layer = SKNode()
        HUD.render(in: layer, context: context(
            shotKind: .redBomb,
            score: 0,
            launchesUntilAdvance: 3,
            danceActive: true
        ))

        let caption = try XCTUnwrap(labels(in: layer).first { $0.text?.hasPrefix("Next") == true })
        XCTAssertEqual(caption.text, "Next BOMB   •   Hop in 3   •   2×")
    }

    @MainActor
    func testTelevisionRendersRemoteHelpAndSelection() throws {
        let layer = SKNode()
        HUD.render(in: layer, context: context(
            isTelevision: true,
            hudScale: 1.75,
            televisionStatus: "LEFT  •  LANE 6"
        ))

        let help = try XCTUnwrap(labels(in: layer).first { $0.text?.contains("SELECT LAUNCH") == true })
        XCTAssertEqual(help.fontSize, 12 * 1.75, accuracy: 0.001)
        let selection = try XCTUnwrap(labels(in: layer).first { $0.text == "LEFT  •  LANE 6" })
        XCTAssertEqual(selection.fontSize, 13 * 1.75, accuracy: 0.001)
    }

    @MainActor
    func testDebugElementsAppearOnlyWhenProvided() throws {
        let plain = SKNode()
        HUD.render(in: plain, context: context())
        XCTAssertNil(plain.childNode(withName: "control:debug"))
        XCTAssertFalse(labels(in: plain).contains { $0.fontName == "Menlo" })

        let debug = SKNode()
        HUD.render(in: debug, context: context(
            debugControlText: "DEBUG ON",
            debugLine: "side=bottom  occupied=12  state=playing"
        ))
        let control = try XCTUnwrap(debug.childNode(withName: "control:debug") as? SKLabelNode)
        XCTAssertEqual(control.text, "DEBUG ON")
        XCTAssertTrue(labels(in: debug).contains { $0.fontName == "Menlo" })
    }
}
