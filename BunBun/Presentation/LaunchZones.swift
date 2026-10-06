import Foundation

/// Presentation-only mapping from the rectangular rules board to a shallow
/// perspective stage. Row zero is closest to the stream/viewer; the final row
/// is the back/arrival edge. Game rules continue to use ordinary `Cell`s.
struct BoardProjection {
    struct Profile: Equatable {
        let farWidthScale: CGFloat
        let farBunnyScale: CGFloat
        let nearBunnyScale: CGFloat
        let verticalCurve: CGFloat

        /// A little stronger on phones, where the old uniform grid left the
        /// characters looking especially small and isolated.
        static let phone = Profile(
            farWidthScale: 0.90,
            farBunnyScale: 1.04,
            nearBunnyScale: 1.28,
            verticalCurve: 1.22
        )

        /// The larger canvas can carry the densest crowd without obscuring
        /// color reads or the side launch outlines.
        static let tablet = Profile(
            farWidthScale: 0.89,
            farBunnyScale: 1.06,
            nearBunnyScale: 1.31,
            verticalCurve: 1.23
        )

        /// Compensate for living-room viewing distance with a larger footprint
        /// while keeping the stage itself clear of the television HUD.
        static let television = Profile(
            farWidthScale: 0.92,
            farBunnyScale: 1.14,
            nearBunnyScale: 1.38,
            verticalCurve: 1.18
        )
    }

    let boardOrigin: CGPoint
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let rowCount: Int
    let columnCount: Int
    let profile: Profile

    var boardWidth: CGFloat { CGFloat(columnCount) * cellWidth }
    var boardHeight: CGFloat { CGFloat(rowCount) * cellHeight }

    func point(for cell: Cell) -> CGPoint {
        let widthScale = rowWidthScale(for: cell.row)
        let boardCenterX = boardOrigin.x + boardWidth / 2
        let centeredColumn = CGFloat(cell.column) + 0.5 - CGFloat(columnCount) / 2

        return CGPoint(
            x: boardCenterX + centeredColumn * cellWidth * widthScale,
            y: projectedY(for: cell.row)
        )
    }

    func bunnyScale(for row: Int) -> CGFloat {
        interpolate(
            from: profile.farBunnyScale,
            to: profile.nearBunnyScale,
            progress: foregroundDepth(for: row)
        )
    }

    func rowWidthScale(for row: Int) -> CGFloat {
        interpolate(
            from: profile.farWidthScale,
            to: 1,
            progress: foregroundDepth(for: row)
        )
    }

    func rowBounds(for row: Int) -> ClosedRange<CGFloat> {
        let width = boardWidth * rowWidthScale(for: row)
        let center = boardOrigin.x + boardWidth / 2
        return (center - width / 2)...(center + width / 2)
    }

    /// Larger values draw closer rows over rows farther from the viewer.
    func depthPosition(for row: Int) -> CGFloat {
        2 + CGFloat(max(0, rowCount - row)) * 0.1
    }

    var rowCenters: [CGFloat] {
        (0..<rowCount).map(projectedY(for:))
    }

    var rowWidthScales: [CGFloat] {
        (0..<rowCount).map(rowWidthScale(for:))
    }

    private func foregroundDepth(for row: Int) -> CGFloat {
        guard rowCount > 1 else { return 1 }
        let clampedRow = min(max(row, 0), rowCount - 1)
        return 1 - CGFloat(clampedRow) / CGFloat(rowCount - 1)
    }

    private func projectedY(for row: Int) -> CGFloat {
        guard rowCount > 1 else { return boardOrigin.y + cellHeight / 2 }
        let clampedRow = min(max(row, 0), rowCount - 1)
        let progress = CGFloat(clampedRow) / CGFloat(rowCount - 1)
        let curvedProgress = 1 - pow(1 - progress, profile.verticalCurve)
        let usableHeight = CGFloat(rowCount - 1) * cellHeight
        return boardOrigin.y + cellHeight / 2 + curvedProgress * usableHeight
    }

    private func interpolate(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }
}

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
        let rowCenters: [CGFloat]?
        let rowWidthScales: [CGFloat]?

        init(
            size: CGSize,
            boardOrigin: CGPoint,
            cellWidth: CGFloat,
            cellHeight: CGFloat,
            boardWidth: CGFloat,
            rowCount: Int,
            columnCount: Int,
            rowCenters: [CGFloat]? = nil,
            rowWidthScales: [CGFloat]? = nil
        ) {
            self.size = size
            self.boardOrigin = boardOrigin
            self.cellWidth = cellWidth
            self.cellHeight = cellHeight
            self.boardWidth = boardWidth
            self.rowCount = rowCount
            self.columnCount = columnCount
            self.rowCenters = rowCenters
            self.rowWidthScales = rowWidthScales
        }
    }

    struct Target: Equatable {
        let side: LaunchSide
        let lane: Int
    }

    static func target(at point: CGPoint, layout: Layout) -> Target? {
        let row = row(at: point.y, layout: layout)
        let isWithinBoardHeight = row >= 0 && row < layout.rowCount
        let rowWidthScale = layout.rowWidthScales?[safe: row] ?? 1
        let boardCenterX = layout.boardOrigin.x + layout.boardWidth / 2
        let innerColumnOffset = (CGFloat(layout.columnCount) / 2 - 1) * layout.cellWidth * rowWidthScale
        let leftInnerEdge = boardCenterX - innerColumnOffset
        let rightInnerEdge = boardCenterX + innerColumnOffset

        if isWithinBoardHeight,
           point.x >= 0,
           point.x < leftInnerEdge {
            return Target(side: .left, lane: row)
        }

        if isWithinBoardHeight,
           point.x >= rightInnerEdge,
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

    private static func row(at y: CGFloat, layout: Layout) -> Int {
        guard let centers = layout.rowCenters,
              centers.count == layout.rowCount,
              !centers.isEmpty else {
            return Int(((y - layout.boardOrigin.y) / layout.cellHeight).rounded(.down))
        }

        let minimumY = layout.boardOrigin.y
        let maximumY = layout.boardOrigin.y + CGFloat(layout.rowCount) * layout.cellHeight
        guard y >= minimumY, y < maximumY else { return -1 }

        for row in centers.indices {
            let upperBoundary = row == centers.index(before: centers.endIndex)
                ? maximumY
                : (centers[row] + centers[row + 1]) / 2
            if y < upperBoundary { return row }
        }
        return -1
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
