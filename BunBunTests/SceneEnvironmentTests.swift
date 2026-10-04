import SpriteKit
import XCTest
@testable import BunBun

final class SceneEnvironmentTests: XCTestCase {
    private func context(environment: LevelEnvironment, danceMode: Bool) -> SceneEnvironment.Context {
        SceneEnvironment.Context(
            size: CGSize(width: 390, height: 844),
            environment: environment,
            backgroundFrame: CGRect(x: 0, y: 0, width: 390, height: 844),
            isTablet: false,
            danceMode: danceMode
        )
    }

    @MainActor
    func testEveryEnvironmentBuildsEffects() {
        for environment in LevelEnvironment.allCases {
            let layer = SKNode()
            SceneEnvironment.configure(layer, context: context(environment: environment, danceMode: false))
            XCTAssertFalse(layer.children.isEmpty, "\(environment) should build ambient effects")
        }
    }

    @MainActor
    func testDanceModeBuildsAtLeastAsManyEffects() {
        for environment in LevelEnvironment.allCases {
            let calm = SKNode()
            let party = SKNode()
            SceneEnvironment.configure(calm, context: context(environment: environment, danceMode: false))
            SceneEnvironment.configure(party, context: context(environment: environment, danceMode: true))
            XCTAssertGreaterThanOrEqual(
                party.children.count,
                calm.children.count,
                "\(environment) dance mode should not remove effects"
            )
        }
    }

    @MainActor
    func testReconfigureReplacesPreviousEffects() {
        let layer = SKNode()
        let desert = context(environment: .desertCamp, danceMode: false)
        SceneEnvironment.configure(layer, context: desert)
        let desertCount = layer.children.count
        XCTAssertGreaterThan(desertCount, 0)
        SceneEnvironment.configure(layer, context: desert)
        XCTAssertEqual(layer.children.count, desertCount, "reconfiguring must not stack effects")

        let snow = context(environment: .snowyWoodland, danceMode: true)
        let fresh = SKNode()
        SceneEnvironment.configure(fresh, context: snow)
        SceneEnvironment.configure(layer, context: snow)
        XCTAssertEqual(layer.children.count, fresh.children.count)
    }

    func testShadeAlphaStaysWithinVisibleRange() {
        for environment in LevelEnvironment.allCases {
            for isTablet in [false, true] {
                let alpha = SceneEnvironment.shadeAlpha(for: environment, isTablet: isTablet)
                XCTAssertGreaterThan(alpha, 0, "\(environment) tablet=\(isTablet)")
                XCTAssertLessThan(alpha, 1, "\(environment) tablet=\(isTablet)")
            }
        }
    }
}
