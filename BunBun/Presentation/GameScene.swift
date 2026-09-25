import SpriteKit
import UIKit

final class GameScene: SKScene {
    private var state = GameState(board: PrototypeLevel.startingBoard())
    private var currentColorIndex = 0
    private var selectedSide: LaunchSide = .bottom
    private var highlightedLane: Int?
    private var isAnimating = false
    private var showsDebug = false
    private var showsDanceParty = false

    private let partyLayer = SKNode()
    private let gridLayer = SKNode()
    private let bunnyLayer = SKNode()
    private let effectLayer = SKNode()
    private let hudLayer = SKNode()

    private var boardOrigin = CGPoint.zero
    private var cellWidth: CGFloat = 24
    private var cellHeight: CGFloat = 34

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1)
        addChild(partyLayer)
        addChild(gridLayer)
        addChild(bunnyLayer)
        addChild(effectLayer)
        addChild(hudLayer)
        renderAll()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard oldSize != .zero else { return }
        renderAll()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isAnimating, let point = touches.first?.location(in: self) else { return }
        updateHighlight(at: point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isAnimating, let point = touches.first?.location(in: self) else { return }
        updateHighlight(at: point)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        highlightedLane = nil
        drawGrid()
        updateAimReactions()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isAnimating, let point = touches.first?.location(in: self) else { return }

        if let control = controlName(at: point) {
            highlightedLane = nil
            switch control {
            case "restart": resetGame()
            case "debug":
                showsDebug.toggle()
                renderAll()
            default: break
            }
            return
        }

        if let side = launcherSide(at: point) {
            selectedSide = side
            highlightedLane = nil
            renderAll()
            return
        }

        guard let cell = boardCell(at: point) else {
            highlightedLane = nil
            drawGrid()
            return
        }

        guard state.status == .playing else {
            flashMessage("TAP RESTART", color: .white)
            return
        }

        let lane = selectedSide == .bottom ? cell.column : cell.row
        performLaunch(lane: lane)
    }

    private func performLaunch(lane: Int) {
        let shot = PrototypeLevel.shot(at: currentColorIndex)
        let bunny = shot.makeBunny()
        let newRow = PrototypeLevel.advanceRow(forTurn: currentColorIndex)

        let outcome = state.launch(
            bunny,
            from: selectedSide,
            lane: lane,
            newBackRow: newRow
        )
        currentColorIndex += 1
        highlightedLane = nil
        isAnimating = true
        drawGrid()
        updateAimReactions()

        animateShot(
            bunny: bunny,
            side: selectedSide,
            lane: lane,
            result: outcome.launchResult
        ) { [weak self] in
            self?.animateResolution(outcome)
        }
    }

    private func animateShot(
        bunny: Bunny,
        side: LaunchSide,
        lane: Int,
        result: LaunchResult,
        completion: @escaping () -> Void
    ) {
        let start = launcherPosition(for: side)
        let end: CGPoint

        switch result {
        case let .placed(cell):
            end = point(for: cell)
        case .passedThrough:
            let rowY = point(for: Cell(column: 0, row: lane)).y
            end = CGPoint(
                x: side == .left ? boardOrigin.x + boardWidth + cellWidth : boardOrigin.x - cellWidth,
                y: rowY
            )
        case .blocked:
            flashMessage("BLOCKED", color: .systemOrange)
            shakeLauncher(side)
            run(.sequence([.wait(forDuration: 0.22), .run(completion)]))
            return
        }

        let projectile = BunnyNode(
            bunny: bunny,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            color: spriteColor(for: bunny.color)
        )
        projectile.position = start
        projectile.setScale(0.78)
        projectile.zPosition = 20
        effectLayer.addChild(projectile)

        let distance = hypot(end.x - start.x, end.y - start.y)
        let duration = max(0.16, min(0.38, TimeInterval(distance / 850)))
        let move = SKAction.move(to: end, duration: duration)
        move.timingMode = .easeInEaseOut
        projectile.run(.sequence([
            .group([move, .scale(to: 1, duration: duration)]),
            .run {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            },
            .removeFromParent(),
            .run(completion)
        ]))
    }

    private func animateResolution(_ outcome: TurnOutcome) {
        if let stages = outcome.chain?.stages, !stages.isEmpty {
            animateChain(stages, index: 0) { [weak self] in
                self?.animateAdvanceIfNeeded(outcome)
            }
        } else {
            updateBunnies(outcome.boardAfterResolution)
            animateAdvanceIfNeeded(outcome)
        }
    }

    private func animateChain(
        _ stages: [ChainStage],
        index: Int,
        completion: @escaping () -> Void
    ) {
        guard stages.indices.contains(index) else {
            completion()
            return
        }

        let stage = stages[index]
        updateBunnies(stage.boardBefore)
        let specialKinds = Set(stage.specialActivations.map(\.kind))
        let message: String
        if specialKinds.count > 1 {
            message = "SPECIAL CHAIN!"
        } else if specialKinds.contains(.redBomb) {
            message = "BUNNY BOOM!"
        } else if specialKinds.contains(.lineClear) {
            message = "LINE CLEAR!"
        } else {
            message = stage.depth == 1 ? "MATCH!" : "CHAIN ×\(stage.depth)"
        }
        flashMessage(message, color: .systemYellow)
        UINotificationFeedbackGenerator().notificationOccurred(stage.depth == 1 ? .success : .warning)
        addConfetti(for: stage.depth)

        for activation in stage.specialActivations {
            run(.sequence([
                .wait(forDuration: 0.34),
                .run { [weak self] in self?.addSpecialEffect(activation) }
            ]))
        }

        let specialCells = Set(stage.specialActivations.map(\.cell))
        for cell in stage.removedCells {
            guard let node = bunnyNode(at: cell, on: stage.boardBefore) else { continue }
            let delay = Double((cell.column + cell.row) % 3) * 0.035
            node.run(.sequence([
                .wait(forDuration: delay),
                .run {
                    if specialCells.contains(cell) {
                        node.playSpecialAnticipation()
                    } else {
                        node.playCelebration(chainDepth: stage.depth)
                    }
                },
                .wait(forDuration: 0.52),
                .group([
                    .scale(to: 0.05, duration: 0.14),
                    .fadeOut(withDuration: 0.14)
                ])
            ]))
            addPop(
                at: point(for: cell),
                color: nodeColor(at: cell, on: stage.boardBefore),
                delay: delay + 0.43
            )
        }

        run(.sequence([
            .wait(forDuration: 0.74),
            .run { [weak self] in
                var survivors = stage.boardBefore
                survivors.remove(at: stage.removedCells)
                self?.animateBoardTransition(from: survivors, to: stage.boardAfter, duration: 0.20)
            },
            .wait(forDuration: 0.25),
            .run { [weak self] in
                self?.animateChain(stages, index: index + 1, completion: completion)
            }
        ]))
    }

    private func animateAdvanceIfNeeded(_ outcome: TurnOutcome) {
        applyDancePartyTransition(outcome)

        guard outcome.didAdvance else {
            finishAnimation()
            return
        }

        flashMessage("HOP!", color: .systemPink)
        updateBunnies(outcome.boardAfterResolution)
        for case let bunny as BunnyNode in bunnyLayer.children {
            bunny.playAdvanceReaction()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let postTransitionWait = outcome.fallenBunnies.isEmpty ? 0.40 : 0.74
        run(.sequence([
            .wait(forDuration: 0.56),
            .run { [weak self] in
                self?.animateBoardTransition(
                    from: outcome.boardAfterResolution,
                    to: outcome.boardAfterTurn,
                    duration: 0.34,
                    rescuesMissingBunnies: !outcome.fallenBunnies.isEmpty
                )
            },
            .wait(forDuration: postTransitionWait),
            .run { [weak self] in
                if !outcome.fallenBunnies.isEmpty {
                    self?.flashMessage(
                        outcome.fallenBunnies.count == 1 ? "ONE BUNNY FELL" : "\(outcome.fallenBunnies.count) BUNNIES FELL",
                        color: .systemRed
                    )
                }
                self?.finishAnimation()
            }
        ]))
    }

    private func finishAnimation() {
        updateBunnies(state.board)
        drawHUD()
        isAnimating = false
        showEndStateIfNeeded()
    }

    private func animateBoardTransition(
        from oldBoard: Board,
        to newBoard: Board,
        duration: TimeInterval,
        rescuesMissingBunnies: Bool = false
    ) {
        updateBunnies(oldBoard)
        let newLocations = Dictionary(uniqueKeysWithValues: newBoard.occupants.map { ($0.value.id, $0.key) })

        for (_, bunny) in oldBoard.occupants {
            guard let node = bunnyLayer.childNode(withName: "bunny:\(bunny.id.uuidString)") else { continue }
            if let newCell = newLocations[bunny.id] {
                let action = SKAction.move(to: point(for: newCell), duration: duration)
                action.timingMode = .easeInEaseOut
                node.run(action)
            } else if rescuesMissingBunnies, let bunnyNode = node as? BunnyNode {
                bunnyNode.playRescue()
                bunnyNode.run(.sequence([
                    .wait(forDuration: 0.48),
                    .group([
                        .moveBy(x: 0, y: cellHeight * 0.72, duration: 0.18),
                        .fadeOut(withDuration: 0.18)
                    ])
                ]))
            } else {
                node.run(.group([
                    .moveBy(x: 0, y: -cellHeight * 1.2, duration: duration),
                    .fadeOut(withDuration: duration)
                ]))
            }
        }

        let refreshDelay = rescuesMissingBunnies ? max(duration, 0.70) : duration
        run(.sequence([
            .wait(forDuration: refreshDelay),
            .run { [weak self] in self?.updateBunnies(newBoard, animateEntrants: true) }
        ]))
    }

    private func renderAll() {
        guard size.width > 0, size.height > 0 else { return }
        layoutBoard()
        drawGrid()
        updateBunnies(state.board)
        updateAimReactions()
        drawHUD()
        if showsDanceParty {
            configureDancePartyBackdrop()
        }
    }

    private func layoutBoard() {
        let horizontalPadding: CGFloat = 42
        cellWidth = min(30, (size.width - horizontalPadding * 2) / CGFloat(state.board.columnCount))
        cellHeight = min(cellWidth * 1.43, (size.height * 0.50) / CGFloat(state.board.rowCount))
        boardOrigin = CGPoint(
            x: (size.width - boardWidth) / 2,
            y: (size.height - boardHeight) / 2 - 6
        )
    }

    private var boardWidth: CGFloat {
        CGFloat(state.board.columnCount) * cellWidth
    }

    private var boardHeight: CGFloat {
        CGFloat(state.board.rowCount) * cellHeight
    }

    private func drawGrid() {
        gridLayer.removeAllChildren()

        for row in 0..<state.board.rowCount {
            for column in 0..<state.board.columnCount {
                let cell = Cell(column: column, row: row)
                let isOutside = Board.outsideColumns.contains(column)
                let isHighlighted = highlightedLane.map { lane in
                    selectedSide == .bottom ? lane == column : lane == row
                } ?? false

                let slot = SKShapeNode(
                    rectOf: CGSize(width: cellWidth - 2, height: cellHeight - 2),
                    cornerRadius: 5
                )
                slot.position = point(for: cell)
                slot.fillColor = isHighlighted
                    ? SKColor(red: 0.26, green: 0.30, blue: 0.39, alpha: 1)
                    : isOutside
                        ? SKColor(red: 0.16, green: 0.13, blue: 0.24, alpha: 1)
                        : SKColor(red: 0.12, green: 0.16, blue: 0.23, alpha: 1)
                slot.strokeColor = isHighlighted
                    ? .systemYellow.withAlphaComponent(0.85)
                    : isOutside
                        ? SKColor(red: 0.55, green: 0.35, blue: 0.72, alpha: 0.7)
                        : SKColor(white: 0.28, alpha: 0.7)
                slot.lineWidth = isHighlighted ? 2 : 1
                gridLayer.addChild(slot)
            }
        }

        let hazard = SKShapeNode(rectOf: CGSize(width: boardWidth, height: 5), cornerRadius: 2)
        hazard.position = CGPoint(x: boardOrigin.x + boardWidth / 2, y: boardOrigin.y - 8)
        hazard.fillColor = .systemRed
        hazard.strokeColor = .clear
        gridLayer.addChild(hazard)
    }

    private func updateBunnies(_ board: Board, animateEntrants: Bool = false) {
        bunnyLayer.removeAllChildren()
        for (cell, bunny) in board.occupants {
            let node = BunnyNode(
                bunny: bunny,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                color: spriteColor(for: bunny.color)
            )
            node.position = point(for: cell)
            node.zPosition = 2
            node.setDancing(showsDanceParty)
            if animateEntrants && cell.row == board.rowCount - 1 {
                node.alpha = 0
                node.setScale(0.45)
                node.run(.group([
                    .fadeIn(withDuration: 0.18),
                    .scale(to: 1, duration: 0.22)
                ]))
            }
            bunnyLayer.addChild(node)
        }
    }

    private func drawHUD() {
        hudLayer.removeAllChildren()

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "BUNBUN  •  BUNNY LAB 0.4"
        title.fontSize = 19
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height - 82)
        hudLayer.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        switch currentColorIndex {
        case 0:
            subtitle.text = "Try LEFT on the row with the blue pair"
        case 1:
            subtitle.text = "Now try RIGHT on the row with the green pair"
        case 2:
            subtitle.text = "BOMB: try LEFT on the red pair"
        case 3:
            subtitle.text = "LINE: try RIGHT on the purple pair"
        default:
            subtitle.text = "Tap a rail, then tap or drag to a lane"
        }
        subtitle.fontSize = 12
        subtitle.fontColor = SKColor(white: 0.72, alpha: 1)
        subtitle.position = CGPoint(x: size.width / 2, y: title.position.y - 24)
        hudLayer.addChild(subtitle)

        addControl(name: "debug", text: showsDebug ? "DEBUG ON" : "DEBUG", x: 58)
        addControl(name: "restart", text: "RESTART", x: size.width - 58)

        let meterWidth = min(92, (size.width - 48) / 3)
        let meterY = size.height - 166
        addMeter(title: "PROGRESS", value: state.progress, color: .systemGreen, x: size.width * 0.22, y: meterY, width: meterWidth)
        addMeter(
            title: state.isDancePartyActive ? "DANCE ×2 (\(state.dancePartyTurnsRemaining))" : "DANCE",
            value: state.danceMeter,
            color: state.isDancePartyActive ? .systemYellow : .systemPurple,
            x: size.width * 0.50,
            y: meterY,
            width: meterWidth
        )
        addMeter(title: "DANGER", value: state.danger, color: .systemRed, x: size.width * 0.78, y: meterY, width: meterWidth)

        for side in LaunchSide.allCases {
            addLauncher(side, at: launcherPosition(for: side))
        }

        let shot = PrototypeLevel.shot(at: currentColorIndex)
        let previewBunny = shot.makeBunny()
        let preview = BunnyNode(
            bunny: previewBunny,
            cellWidth: 22,
            cellHeight: 31,
            color: spriteColor(for: shot.color)
        )
        preview.position = CGPoint(x: size.width / 2 - 75, y: 69)
        preview.setScale(0.82)
        hudLayer.addChild(preview)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        let multiplier = state.isDancePartyActive ? "   •   2×" : ""
        let nextName = switch shot.kind {
        case .normal: "Next"
        case .redBomb: "Next BOMB"
        case .lineClear: "Next LINE"
        }
        label.text = "\(nextName)   •   Score \(state.score)   •   Hop in \(3 - state.launchesSinceAdvance)\(multiplier)"
        label.fontSize = 12
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: preview.position.x + 20, y: preview.position.y)
        hudLayer.addChild(label)

        if showsDebug {
            let debug = SKLabelNode(fontNamed: "Menlo")
            debug.text = "side=\(selectedSide.rawValue)  occupied=\(state.board.occupants.count)  state=\(state.status)"
            debug.fontSize = 9
            debug.fontColor = .systemGreen
            debug.position = CGPoint(x: size.width / 2, y: 38)
            hudLayer.addChild(debug)
        }
    }

    private func addControl(name: String, text: String, x: CGFloat) {
        let node = SKLabelNode(fontNamed: "AvenirNext-Bold")
        node.name = "control:\(name)"
        node.text = text
        node.fontSize = 10
        node.fontColor = SKColor(white: 0.70, alpha: 1)
        node.position = CGPoint(x: x, y: size.height - 132)
        hudLayer.addChild(node)
    }

    private func addMeter(title: String, value: Int, color: SKColor, x: CGFloat, y: CGFloat, width: CGFloat) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = 8
        label.fontColor = SKColor(white: 0.72, alpha: 1)
        label.position = CGPoint(x: x, y: y + 9)
        hudLayer.addChild(label)

        let track = SKShapeNode(rectOf: CGSize(width: width, height: 7), cornerRadius: 3.5)
        track.position = CGPoint(x: x, y: y - 2)
        track.fillColor = SKColor(white: 0.17, alpha: 1)
        track.strokeColor = SKColor(white: 0.35, alpha: 1)
        track.lineWidth = 1
        hudLayer.addChild(track)

        let fillWidth = max(0, width * CGFloat(value) / CGFloat(GameState.maximumMeterValue))
        guard fillWidth > 0 else { return }
        let fill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: 5), cornerRadius: 2.5)
        fill.position = CGPoint(x: x - width / 2 + fillWidth / 2, y: y - 2)
        fill.fillColor = color
        fill.strokeColor = .clear
        fill.zPosition = 1
        hudLayer.addChild(fill)
    }

    private func addLauncher(_ side: LaunchSide, at position: CGPoint) {
        let isSelected = selectedSide == side
        let node = SKShapeNode(circleOfRadius: 18)
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

    private func launcherPosition(for side: LaunchSide) -> CGPoint {
        switch side {
        case .left:
            CGPoint(x: boardOrigin.x - 25, y: boardOrigin.y + boardHeight / 2)
        case .right:
            CGPoint(x: boardOrigin.x + boardWidth + 25, y: boardOrigin.y + boardHeight / 2)
        case .bottom:
            CGPoint(x: boardOrigin.x + boardWidth / 2, y: boardOrigin.y - 45)
        }
    }

    private func updateHighlight(at point: CGPoint) {
        guard let cell = boardCell(at: point) else { return }
        highlightedLane = selectedSide == .bottom ? cell.column : cell.row
        drawGrid()
        updateAimReactions()
    }

    private func updateAimReactions() {
        for (cell, bunny) in state.board.occupants {
            guard let node = bunnyLayer.childNode(
                withName: "bunny:\(bunny.id.uuidString)"
            ) as? BunnyNode else { continue }

            let isInHighlightedLane = highlightedLane.map { lane in
                selectedSide == .bottom ? cell.column == lane : cell.row == lane
            } ?? false
            node.setAiming(isInHighlightedLane)
        }
    }

    private func point(for cell: Cell) -> CGPoint {
        CGPoint(
            x: boardOrigin.x + (CGFloat(cell.column) + 0.5) * cellWidth,
            y: boardOrigin.y + (CGFloat(cell.row) + 0.5) * cellHeight
        )
    }

    private func boardCell(at point: CGPoint) -> Cell? {
        guard point.x >= boardOrigin.x, point.x < boardOrigin.x + boardWidth,
              point.y >= boardOrigin.y, point.y < boardOrigin.y + boardHeight else { return nil }
        let cell = Cell(
            column: Int((point.x - boardOrigin.x) / cellWidth),
            row: Int((point.y - boardOrigin.y) / cellHeight)
        )
        return state.board.contains(cell) ? cell : nil
    }

    private func launcherSide(at point: CGPoint) -> LaunchSide? {
        LaunchSide.allCases.first { side in
            hudLayer.children
                .filter { $0.name == "launcher:\(side.rawValue)" }
                .contains { $0.frame.insetBy(dx: -8, dy: -8).contains(point) }
        }
    }

    private func controlName(at point: CGPoint) -> String? {
        for node in hudLayer.children where node.name?.hasPrefix("control:") == true {
            if node.frame.insetBy(dx: -14, dy: -12).contains(point) {
                return node.name?.replacingOccurrences(of: "control:", with: "")
            }
        }
        return nil
    }

    private func bunnyNode(at cell: Cell, on board: Board) -> BunnyNode? {
        guard let bunny = board[cell] else { return nil }
        return bunnyLayer.childNode(withName: "bunny:\(bunny.id.uuidString)") as? BunnyNode
    }

    private func nodeColor(at cell: Cell, on board: Board) -> SKColor {
        board[cell].map { spriteColor(for: $0.color) } ?? .white
    }

    private func addPop(at position: CGPoint, color: SKColor, delay: TimeInterval = 0) {
        let ring = SKShapeNode(circleOfRadius: cellWidth * 0.24)
        ring.position = position
        ring.strokeColor = color
        ring.lineWidth = 4
        ring.fillColor = .clear
        ring.zPosition = 30
        effectLayer.addChild(ring)
        ring.run(.sequence([
            .wait(forDuration: delay),
            .group([
                .scale(to: 2.2, duration: 0.28),
                .fadeOut(withDuration: 0.28)
            ]),
            .removeFromParent()
        ]))
    }

    private func addSpecialEffect(_ activation: SpecialActivation) {
        switch activation.kind {
        case .normal:
            break
        case .redBomb:
            let center = point(for: activation.cell)
            let blast = SKShapeNode(circleOfRadius: max(cellWidth, cellHeight) * 0.44)
            blast.position = center
            blast.fillColor = .systemRed.withAlphaComponent(0.42)
            blast.strokeColor = .systemYellow
            blast.lineWidth = 5
            blast.zPosition = 29
            effectLayer.addChild(blast)
            blast.run(.sequence([
                .group([
                    .scale(to: 3.0, duration: 0.30),
                    .fadeOut(withDuration: 0.30)
                ]),
                .removeFromParent()
            ]))

        case .lineClear:
            let center = point(for: activation.cell)
            let horizontal = SKShapeNode(
                rectOf: CGSize(width: boardWidth + cellWidth, height: max(7, cellHeight * 0.22)),
                cornerRadius: 4
            )
            horizontal.position = CGPoint(x: boardOrigin.x + boardWidth / 2, y: center.y)

            let vertical = SKShapeNode(
                rectOf: CGSize(width: max(7, cellWidth * 0.22), height: boardHeight + cellHeight),
                cornerRadius: 4
            )
            vertical.position = CGPoint(x: center.x, y: boardOrigin.y + boardHeight / 2)

            for beam in [horizontal, vertical] {
                beam.fillColor = .systemPurple.withAlphaComponent(0.64)
                beam.strokeColor = .white
                beam.lineWidth = 2
                beam.zPosition = 29
                beam.setScale(0.08)
                effectLayer.addChild(beam)
                beam.run(.sequence([
                    .group([
                        .scale(to: 1, duration: 0.12),
                        .fadeAlpha(to: 0.82, duration: 0.12)
                    ]),
                    .wait(forDuration: 0.10),
                    .fadeOut(withDuration: 0.15),
                    .removeFromParent()
                ]))
            }
        }
    }

    private func addConfetti(for chainDepth: Int) {
        let colors: [SKColor] = [.systemPink, .systemYellow, .systemBlue, .systemGreen, .systemPurple]
        let count = min(10 + chainDepth * 6, 34)
        let origin = CGPoint(x: size.width / 2, y: boardOrigin.y + boardHeight * 0.62)

        for index in 0..<count {
            let piece = SKShapeNode(rectOf: CGSize(width: 5, height: 9), cornerRadius: 1)
            piece.fillColor = colors[index % colors.count]
            piece.strokeColor = .clear
            piece.position = origin
            piece.zPosition = 32
            effectLayer.addChild(piece)

            let angle = CGFloat.pi * (0.12 + 0.76 * CGFloat(index) / CGFloat(max(count - 1, 1)))
            let distance = CGFloat(55 + (index * 17) % 85)
            let destination = CGPoint(
                x: origin.x + cos(angle) * distance,
                y: origin.y + sin(angle) * distance - CGFloat((index * 9) % 45)
            )
            piece.run(.sequence([
                .group([
                    .move(to: destination, duration: 0.48),
                    .rotate(byAngle: CGFloat.pi * 2, duration: 0.48),
                    .sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.23)])
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func applyDancePartyTransition(_ outcome: TurnOutcome) {
        if outcome.dancePartyStarted {
            showsDanceParty = true
            configureDancePartyBackdrop()
            updateBunnies(outcome.boardAfterResolution)
            flashMessage("DANCE PARTY!  2×", color: .systemYellow)
            addConfetti(for: 3)
        } else if outcome.dancePartyEnded {
            showsDanceParty = false
            partyLayer.removeAllChildren()
            backgroundColor = SKColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1)
        }
    }

    private func configureDancePartyBackdrop() {
        partyLayer.removeAllChildren()
        backgroundColor = SKColor(red: 0.10, green: 0.04, blue: 0.18, alpha: 1)
        let colors: [SKColor] = [.systemPink, .systemBlue, .systemPurple, .systemYellow]

        for index in 0..<8 {
            let light = SKShapeNode(circleOfRadius: CGFloat(45 + (index % 3) * 18))
            light.fillColor = colors[index % colors.count].withAlphaComponent(0.10)
            light.strokeColor = .clear
            light.position = CGPoint(
                x: CGFloat((index * 71 + 24) % max(Int(size.width), 1)),
                y: CGFloat((index * 113 + 90) % max(Int(size.height), 1))
            )
            light.zPosition = -10
            partyLayer.addChild(light)
            light.run(.repeatForever(.sequence([
                .group([.scale(to: 1.35, duration: 0.42), .fadeAlpha(to: 0.35, duration: 0.42)]),
                .group([.scale(to: 0.75, duration: 0.42), .fadeAlpha(to: 0.08, duration: 0.42)])
            ])))
        }
    }

    private func showEndStateIfNeeded() {
        guard state.status != .playing else { return }
        let panel = SKShapeNode(rectOf: CGSize(width: min(310, size.width - 50), height: 112), cornerRadius: 18)
        panel.fillColor = SKColor(white: 0.05, alpha: 0.92)
        panel.strokeColor = state.status == .won ? .systemGreen : .systemPink
        panel.lineWidth = 3
        panel.position = CGPoint(x: size.width / 2, y: boardOrigin.y + boardHeight / 2)
        panel.zPosition = 60
        effectLayer.addChild(panel)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = state.status == .won ? "LEVEL COMPLETE!" : "BUNNIES NEED A BREAK"
        title.fontSize = state.status == .won ? 23 : 18
        title.fontColor = .white
        title.verticalAlignmentMode = .center
        title.position.y = 15
        panel.addChild(title)

        let prompt = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        prompt.text = "Tap RESTART to play again"
        prompt.fontSize = 12
        prompt.fontColor = SKColor(white: 0.75, alpha: 1)
        prompt.verticalAlignmentMode = .center
        prompt.position.y = -22
        panel.addChild(prompt)

        if state.status == .won {
            addConfetti(for: 5)
        }
    }

    private func flashMessage(_ text: String, color: SKColor) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 25
        label.fontColor = color
        label.position = CGPoint(x: size.width / 2, y: boardOrigin.y + boardHeight + 23)
        label.zPosition = 40
        label.setScale(0.5)
        effectLayer.addChild(label)
        label.run(.sequence([
            .group([.scale(to: 1.12, duration: 0.13), .fadeIn(withDuration: 0.08)]),
            .scale(to: 1, duration: 0.08),
            .wait(forDuration: 0.24),
            .group([.moveBy(x: 0, y: 12, duration: 0.18), .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
    }

    private func shakeLauncher(_ side: LaunchSide) {
        let nodes = hudLayer.children.filter { $0.name == "launcher:\(side.rawValue)" }
        for node in nodes {
            node.run(.sequence([
                .moveBy(x: -5, y: 0, duration: 0.04),
                .moveBy(x: 10, y: 0, duration: 0.08),
                .moveBy(x: -5, y: 0, duration: 0.04)
            ]))
        }
    }

    private func resetGame() {
        removeAllActions()
        effectLayer.removeAllChildren()
        state = GameState(board: PrototypeLevel.startingBoard())
        currentColorIndex = 0
        selectedSide = .bottom
        highlightedLane = nil
        isAnimating = false
        showsDanceParty = false
        partyLayer.removeAllChildren()
        backgroundColor = SKColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1)
        renderAll()
        flashMessage("READY!", color: .systemGreen)
    }

    private func spriteColor(for color: BunnyColor) -> SKColor {
        switch color {
        case .blue: .systemBlue
        case .green: .systemGreen
        case .orange: .systemOrange
        case .pink: .systemPink
        case .purple: .systemPurple
        case .red: .systemRed
        }
    }

}
