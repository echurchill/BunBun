import SpriteKit

final class GameScene: SKScene {
    private var state = GameState(board: GameScene.demoBoard())
    private var currentColorIndex = 0
    private var selectedSide: LaunchSide = .bottom

    private let boardLayer = SKNode()
    private let hudLayer = SKNode()

    private var boardOrigin = CGPoint.zero
    private var cellSize: CGFloat = 24

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1)
        addChild(boardLayer)
        addChild(hudLayer)
        render()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard oldSize != .zero else { return }
        render()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }

        if let side = launcherSide(at: point) {
            selectedSide = side
            render()
            return
        }

        guard let cell = boardCell(at: point) else { return }
        let lane = selectedSide == .bottom ? cell.column : cell.row
        let color = BunnyColor.allCases[currentColorIndex % BunnyColor.allCases.count]
        let newRow = Dictionary(uniqueKeysWithValues: Board.marchingColumns.map { column in
            let index = (column + currentColorIndex + 2) % BunnyColor.allCases.count
            return (column, Bunny(color: BunnyColor.allCases[index]))
        })

        _ = state.launch(
            Bunny(color: color),
            from: selectedSide,
            lane: lane,
            newBackRow: newRow
        )
        currentColorIndex += 1
        render()
    }

    private func render() {
        guard size.width > 0, size.height > 0 else { return }
        boardLayer.removeAllChildren()
        hudLayer.removeAllChildren()

        let horizontalPadding: CGFloat = 42
        cellSize = min(
            (size.width - horizontalPadding * 2) / CGFloat(state.board.columnCount),
            (size.height * 0.58) / CGFloat(state.board.rowCount)
        )
        let boardWidth = CGFloat(state.board.columnCount) * cellSize
        let boardHeight = CGFloat(state.board.rowCount) * cellSize
        boardOrigin = CGPoint(
            x: (size.width - boardWidth) / 2,
            y: (size.height - boardHeight) / 2 - 12
        )

        drawTitle()
        drawBoard()
        drawLaunchers()
        drawHUD()
    }

    private func drawTitle() {
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "BUNBUN  •  BUNNY LAB 0.1"
        title.fontSize = 19
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height - 82)
        hudLayer.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitle.text = "Tap a rail, then tap a lane"
        subtitle.fontSize = 13
        subtitle.fontColor = SKColor(white: 0.72, alpha: 1)
        subtitle.position = CGPoint(x: size.width / 2, y: title.position.y - 25)
        hudLayer.addChild(subtitle)
    }

    private func drawBoard() {
        for row in 0..<state.board.rowCount {
            for column in 0..<state.board.columnCount {
                let cell = Cell(column: column, row: row)
                let center = point(for: cell)
                let isOutside = Board.outsideColumns.contains(column)

                let slot = SKShapeNode(rectOf: CGSize(width: cellSize - 2, height: cellSize - 2), cornerRadius: 4)
                slot.position = center
                slot.fillColor = isOutside
                    ? SKColor(red: 0.16, green: 0.13, blue: 0.24, alpha: 1)
                    : SKColor(red: 0.12, green: 0.16, blue: 0.23, alpha: 1)
                slot.strokeColor = isOutside
                    ? SKColor(red: 0.55, green: 0.35, blue: 0.72, alpha: 0.7)
                    : SKColor(white: 0.28, alpha: 0.7)
                slot.lineWidth = 1
                boardLayer.addChild(slot)

                if let bunny = state.board[cell] {
                    let circle = SKShapeNode(circleOfRadius: cellSize * 0.36)
                    circle.position = center
                    circle.fillColor = spriteColor(for: bunny.color)
                    circle.strokeColor = .white.withAlphaComponent(0.7)
                    circle.lineWidth = 1.5
                    circle.zPosition = 2
                    boardLayer.addChild(circle)
                }
            }
        }

        let hazard = SKShapeNode(rectOf: CGSize(width: CGFloat(state.board.columnCount) * cellSize, height: 4))
        hazard.position = CGPoint(
            x: boardOrigin.x + CGFloat(state.board.columnCount) * cellSize / 2,
            y: boardOrigin.y - 7
        )
        hazard.fillColor = .systemRed
        hazard.strokeColor = .clear
        boardLayer.addChild(hazard)
    }

    private func drawLaunchers() {
        addLauncher(.left, at: CGPoint(
            x: boardOrigin.x - 25,
            y: boardOrigin.y + CGFloat(state.board.rowCount) * cellSize / 2
        ))
        addLauncher(.right, at: CGPoint(
            x: boardOrigin.x + CGFloat(state.board.columnCount) * cellSize + 25,
            y: boardOrigin.y + CGFloat(state.board.rowCount) * cellSize / 2
        ))
        addLauncher(.bottom, at: CGPoint(
            x: boardOrigin.x + CGFloat(state.board.columnCount) * cellSize / 2,
            y: boardOrigin.y - 40
        ))
    }

    private func addLauncher(_ side: LaunchSide, at position: CGPoint) {
        let isSelected = selectedSide == side
        let node = SKShapeNode(circleOfRadius: 17)
        node.name = "launcher:\(side.rawValue)"
        node.position = position
        node.fillColor = isSelected ? .systemYellow : SKColor(white: 0.25, alpha: 1)
        node.strokeColor = isSelected ? .white : SKColor(white: 0.5, alpha: 1)
        node.lineWidth = isSelected ? 3 : 1
        node.zPosition = 4
        hudLayer.addChild(node)

        let glyph = SKLabelNode(fontNamed: "AvenirNext-Bold")
        glyph.name = node.name
        glyph.text = side == .left ? "→" : side == .right ? "←" : "↑"
        glyph.fontSize = 20
        glyph.fontColor = .black
        glyph.verticalAlignmentMode = .center
        glyph.position = position
        glyph.zPosition = 5
        hudLayer.addChild(glyph)
    }

    private func drawHUD() {
        let color = BunnyColor.allCases[currentColorIndex % BunnyColor.allCases.count]
        let next = SKShapeNode(circleOfRadius: 11)
        next.fillColor = spriteColor(for: color)
        next.strokeColor = .white
        next.position = CGPoint(x: size.width / 2 - 67, y: 70)
        hudLayer.addChild(next)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = "Next shot   •   Score \(state.score)   •   Advance in \(3 - state.launchesSinceAdvance)"
        label.fontSize = 12
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: next.position.x + 19, y: next.position.y)
        hudLayer.addChild(label)
    }

    private func point(for cell: Cell) -> CGPoint {
        CGPoint(
            x: boardOrigin.x + (CGFloat(cell.column) + 0.5) * cellSize,
            y: boardOrigin.y + (CGFloat(cell.row) + 0.5) * cellSize
        )
    }

    private func boardCell(at point: CGPoint) -> Cell? {
        let column = Int((point.x - boardOrigin.x) / cellSize)
        let row = Int((point.y - boardOrigin.y) / cellSize)
        let cell = Cell(column: column, row: row)
        return state.board.contains(cell) ? cell : nil
    }

    private func launcherSide(at point: CGPoint) -> LaunchSide? {
        for side in LaunchSide.allCases {
            let nodes = hudLayer.children.filter { $0.name == "launcher:\(side.rawValue)" }
            if nodes.contains(where: { $0.frame.insetBy(dx: -8, dy: -8).contains(point) }) {
                return side
            }
        }
        return nil
    }

    private func spriteColor(for color: BunnyColor) -> SKColor {
        switch color {
        case .blue: .systemBlue
        case .green: .systemGreen
        case .orange: .systemOrange
        case .pink: .systemPink
        case .purple: .systemPurple
        }
    }

    private static func demoBoard() -> Board {
        var board = Board()
        let colors = BunnyColor.allCases
        for row in 3..<Board.prototypeRows {
            for column in Board.marchingColumns where (row + column) % 4 != 0 {
                let color = colors[(row * 2 + column) % colors.count]
                _ = board.place(Bunny(color: color), at: Cell(column: column, row: row))
            }
        }
        return board
    }
}
