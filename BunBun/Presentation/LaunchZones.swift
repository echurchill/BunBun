import CoreGraphics

/// Pure launch-zone geometry: maps a touch point to a launcher side and lane.
/// The side zones span from the screen edges to the inner edge of the
/// outside-lane columns, so taps anywhere between a launcher outline and its
/// border register; the bottom zone is unchanged. Pure so the mapping —
/// including left/right symmetry — is unit-testable without a scene.
enum LaunchZones {
    struct Layout {
        let size: CGSize
        let boardOrigin: CGPoint
        let cellWidth: CGFloat
        let cellHeight: CGFloat
        let boardWidth: CGFloat
        let rowCount: Int
        let columnCount: Int
    }

    struct Target: Equatable {
        let side: LaunchSide
        let lane: Int
    }

    static func target(at point: CGPoint, layout: Layout) -> Target? {
        let row = Int(((point.y - layout.boardOrigin.y) / layout.cellHeight).rounded(.down))
        let isWithinBoardHeight = row >= 0 && row < layout.rowCount

        if isWithinBoardHeight,
           point.x >= 0,
           point.x < layout.boardOrigin.x + layout.cellWidth {
            return Target(side: .left, lane: row)
        }

        if isWithinBoardHeight,
           point.x >= layout.boardOrigin.x + layout.boardWidth - layout.cellWidth,
           point.x < layout.size.width {
            return Target(side: .right, lane: row)
        }

        let bottomZoneHeight = max(52, layout.cellHeight * 1.15)
        let isWithinBottomZone = point.y >= layout.boardOrigin.y - bottomZoneHeight
            && point.y < layout.boardOrigin.y
        guard isWithinBottomZone,
              point.x >= layout.boardOrigin.x,
              point.x < layout.boardOrigin.x + layout.boardWidth else { return nil }

        let column = Int((point.x - layout.boardOrigin.x) / layout.cellWidth)
        guard column >= 0, column < layout.columnCount else { return nil }
        return Target(side: .bottom, lane: column)
    }
}
