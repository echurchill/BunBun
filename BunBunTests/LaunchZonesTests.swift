import CoreGraphics
import XCTest
@testable import BunBun

final class LaunchZonesTests: XCTestCase {
    /// Wide-phone geometry (Pro Max class): capped 31pt cells center a
    /// 372pt board in 440pt, which left 22pt dead strips outside each side
    /// zone under the old fixed slop.
    private let wideLayout = LaunchZones.Layout(
        size: CGSize(width: 440, height: 956),
        boardOrigin: CGPoint(x: 34, y: 290),
        cellWidth: 31,
        cellHeight: 45.5,
        boardWidth: 372,
        rowCount: 8,
        columnCount: 12
    )

    private func midY(row: Int) -> CGFloat {
        wideLayout.boardOrigin.y + (CGFloat(row) + 0.5) * wideLayout.cellHeight
    }

    private func mirrored(_ target: LaunchZones.Target?) -> LaunchZones.Target? {
        guard let target else { return nil }
        switch target.side {
        case .left: return LaunchZones.Target(side: .right, lane: target.lane)
        case .right: return LaunchZones.Target(side: .left, lane: target.lane)
        case .bottom: return LaunchZones.Target(side: .bottom, lane: 11 - target.lane)
        }
    }

    func testSideZonesReachBothScreenEdges() {
        for row in 0..<8 {
            XCTAssertEqual(
                LaunchZones.target(at: CGPoint(x: 0, y: midY(row: row)), layout: wideLayout),
                LaunchZones.Target(side: .left, lane: row),
                "row \(row)"
            )
            XCTAssertEqual(
                LaunchZones.target(at: CGPoint(x: 439.9, y: midY(row: row)), layout: wideLayout),
                LaunchZones.Target(side: .right, lane: row),
                "row \(row)"
            )
        }
    }

    func testFormerlyDeadOuterStripsNowRegister() {
        // Both points sat inside the old 22pt dead strips on a Pro Max.
        XCTAssertEqual(
            LaunchZones.target(at: CGPoint(x: 21.9, y: midY(row: 2)), layout: wideLayout)?.side,
            .left
        )
        XCTAssertEqual(
            LaunchZones.target(at: CGPoint(x: 418.1, y: midY(row: 2)), layout: wideLayout)?.side,
            .right
        )
    }

    func testZonesAreMirrorSymmetric() {
        // Non-integral stride avoids exact zone boundaries, which the
        // dedicated boundary test covers.
        var x: CGFloat = 0.5
        while x < wideLayout.size.width {
            let point = CGPoint(x: x, y: midY(row: 3))
            let mirror = CGPoint(x: wideLayout.size.width - x, y: midY(row: 3))
            XCTAssertEqual(
                mirrored(LaunchZones.target(at: point, layout: wideLayout)),
                LaunchZones.target(at: mirror, layout: wideLayout),
                "x=\(x)"
            )
            x += 3.7
        }
    }

    func testInnerZoneBoundaries() {
        // Left zone ends where the second column begins; right zone begins
        // where the last column begins.
        XCTAssertNil(LaunchZones.target(at: CGPoint(x: 65, y: midY(row: 3)), layout: wideLayout))
        XCTAssertEqual(
            LaunchZones.target(at: CGPoint(x: 375, y: midY(row: 3)), layout: wideLayout),
            LaunchZones.Target(side: .right, lane: 3)
        )
    }

    func testTapsOutsideBoardHeightSelectNothing() {
        XCTAssertNil(LaunchZones.target(at: CGPoint(x: 200, y: 660), layout: wideLayout))
        XCTAssertNil(LaunchZones.target(at: CGPoint(x: 200, y: 37), layout: wideLayout))
        XCTAssertNil(LaunchZones.target(at: CGPoint(x: 200, y: 237.6), layout: wideLayout))
    }

    func testBottomZoneUnchanged() {
        XCTAssertEqual(
            LaunchZones.target(at: CGPoint(x: 204.5, y: 289.9), layout: wideLayout),
            LaunchZones.Target(side: .bottom, lane: 5)
        )
        XCTAssertNil(LaunchZones.target(at: CGPoint(x: 10, y: 280), layout: wideLayout))
        XCTAssertNil(LaunchZones.target(at: CGPoint(x: 430, y: 280), layout: wideLayout))
    }

    func testInnerBoardTapsSelectNothing() {
        XCTAssertNil(LaunchZones.target(at: CGPoint(x: 204.5, y: midY(row: 3)), layout: wideLayout))
    }

    func testStandardPhoneKeepsEdgeToEdgeZones() {
        let layout = LaunchZones.Layout(
            size: CGSize(width: 390, height: 844),
            boardOrigin: CGPoint(x: 10, y: 240),
            cellWidth: 30,
            cellHeight: 45,
            boardWidth: 360,
            rowCount: 8,
            columnCount: 12
        )
        let y = layout.boardOrigin.y + 3.5 * layout.cellHeight
        XCTAssertEqual(
            LaunchZones.target(at: CGPoint(x: 0, y: y), layout: layout)?.side,
            .left
        )
        XCTAssertEqual(
            LaunchZones.target(at: CGPoint(x: 389.9, y: y), layout: layout)?.side,
            .right
        )
    }

    func testPerspectiveProjectionCreatesDenserForegroundCrowd() {
        let projection = BoardProjection(
            boardOrigin: wideLayout.boardOrigin,
            cellWidth: wideLayout.cellWidth,
            cellHeight: wideLayout.cellHeight,
            rowCount: wideLayout.rowCount,
            columnCount: wideLayout.columnCount,
            profile: .phone
        )

        XCTAssertGreaterThan(projection.bunnyScale(for: 0), projection.bunnyScale(for: 7))
        XCTAssertGreaterThan(projection.rowWidthScale(for: 0), projection.rowWidthScale(for: 7))

        let frontSpacing = projection.point(for: Cell(column: 5, row: 1)).y
            - projection.point(for: Cell(column: 5, row: 0)).y
        let backSpacing = projection.point(for: Cell(column: 5, row: 7)).y
            - projection.point(for: Cell(column: 5, row: 6)).y
        XCTAssertGreaterThan(frontSpacing, backSpacing)
        XCTAssertGreaterThan(
            projection.depthPosition(for: 0),
            projection.depthPosition(for: 7)
        )
    }

    func testPerspectiveSideZonesFollowProjectedRowCentersAndWidths() {
        let projection = BoardProjection(
            boardOrigin: wideLayout.boardOrigin,
            cellWidth: wideLayout.cellWidth,
            cellHeight: wideLayout.cellHeight,
            rowCount: wideLayout.rowCount,
            columnCount: wideLayout.columnCount,
            profile: .phone
        )
        let layout = LaunchZones.Layout(
            size: wideLayout.size,
            boardOrigin: wideLayout.boardOrigin,
            cellWidth: wideLayout.cellWidth,
            cellHeight: wideLayout.cellHeight,
            boardWidth: wideLayout.boardWidth,
            rowCount: wideLayout.rowCount,
            columnCount: wideLayout.columnCount,
            rowCenters: projection.rowCenters,
            rowWidthScales: projection.rowWidthScales
        )

        for row in 0..<wideLayout.rowCount {
            let leftOutline = projection.point(for: Cell(column: 0, row: row))
            let rightOutline = projection.point(for: Cell(column: 11, row: row))
            XCTAssertEqual(
                LaunchZones.target(at: leftOutline, layout: layout),
                LaunchZones.Target(side: .left, lane: row)
            )
            XCTAssertEqual(
                LaunchZones.target(at: rightOutline, layout: layout),
                LaunchZones.Target(side: .right, lane: row)
            )
        }
    }
}
