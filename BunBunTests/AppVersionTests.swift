import XCTest
@testable import BunBun

final class AppVersionTests: XCTestCase {
    func testMarketingVersionIsNeverEmpty() {
        XCTAssertFalse(AppVersion.marketingVersion.isEmpty)
    }

    func testPrototypeTagContainsMarketingVersion() {
        XCTAssertTrue(AppVersion.prototypeTag.hasPrefix("PROTOTYPE "))
        XCTAssertTrue(AppVersion.prototypeTag.contains(AppVersion.marketingVersion))
    }
}
