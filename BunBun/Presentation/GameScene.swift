import SpriteKit
import UIKit

final class GameScene: SKScene {
    private struct PlaytestRunStats {
        private let startedAt = Date()
        private var endedAt: Date?
        private(set) var launches = 0
        private(set) var falls = 0
        private(set) var specialActivations = 0
        private(set) var danceParties = 0

        mutating func record(_ outcome: TurnOutcome) {
            launches += 1
            falls += outcome.fallenBunnies.count
            specialActivations += outcome.chain?.stages.reduce(0) {
                $0 + $1.specialActivations.count
            } ?? 0
            if outcome.dancePartyStarted {
                danceParties += 1
            }
        }

        mutating func finish() {
            if endedAt == nil {
                endedAt = Date()
            }
        }

        var elapsedSeconds: Int {
            max(0, Int((endedAt ?? Date()).timeIntervalSince(startedAt).rounded()))
        }
    }

    private struct LaunchTarget {
        let side: LaunchSide
        let lane: Int
    }

    private let level: LevelDefinition
    private let hasNextLevel: Bool
    private let onLevelCompleted: (LevelID, Int) -> Void
    private let onRequestLevels: () -> Void
    private let onRequestNextLevel: () -> Void

    private var state: GameState
    private var currentShotIndex = 0
    private var selectedSide: LaunchSide = .bottom
    private var highlightedLane: Int?
    private var isAnimating = false
    private var showsDebug = false
    private var showsDanceParty = false
    private var didReportCompletion = false
    private var playtestStats = PlaytestRunStats()

    private let partyLayer = SKNode()
    private let gridLayer = SKNode()
    private let bunnyLayer = SKNode()
    private let effectLayer = SKNode()
    private let hudLayer = SKNode()

    private var boardOrigin = CGPoint.zero
    private var cellWidth: CGFloat = 24
    private var cellHeight: CGFloat = 34

    private var isTabletLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var hudScale: CGFloat {
        isTabletLayout ? 1.22 : 1
    }

    init(
        size: CGSize,
        level: LevelDefinition = LevelCatalog.bunnyLab,
        hasNextLevel: Bool = false,
        onLevelCompleted: @escaping (LevelID, Int) -> Void = { _, _ in },
        onRequestLevels: @escaping () -> Void = {},
        onRequestNextLevel: @escaping () -> Void = {}
    ) {
        self.level = level
        self.hasNextLevel = hasNextLevel
        self.onLevelCompleted = onLevelCompleted
        self.onRequestLevels = onRequestLevels
        self.onRequestNextLevel = onRequestNextLevel
        state = GameState(board: level.startingBoard(), rules: level.rules)
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = themeBackgroundColor
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
            case "replay": resetGame()
            case "levels": onRequestLevels()
            case "next": onRequestNextLevel()
            case "debug":
                showsDebug.toggle()
                renderAll()
            default: break
            }
            return
        }

        guard let target = launchTarget(at: point) else {
            highlightedLane = nil
            drawGrid()
            updateAimReactions()
            return
        }

        guard state.status == .playing else {
            flashMessage("TAP RESTART", color: .white)
            return
        }

        selectedSide = target.side
        performLaunch(lane: target.lane)
    }

    private func performLaunch(lane: Int) {
        let shot = level.shot(at: currentShotIndex)
        let bunny = shot.makeBunny()
        let newRow = level.advanceRow(forTurn: currentShotIndex)

        let outcome = state.launch(
            bunny,
            from: selectedSide,
            lane: lane,
            newBackRow: newRow
        )
        playtestStats.record(outcome)
        currentShotIndex += 1
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
        let start = projectileStartPosition(for: side, lane: lane)
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
            pulseLaunchTarget(side: side, lane: lane)
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
        for (cell, model) in outcome.boardAfterResolution.occupants {
            guard let bunny = bunnyLayer.childNode(
                withName: "bunny:\(model.id.uuidString)"
            ) as? BunnyNode else { continue }
            let delay = Double((cell.column + cell.row * 2) % 5) * 0.055
            bunny.run(.sequence([
                .wait(forDuration: delay),
                .run { [weak bunny] in bunny?.playAdvanceReaction() }
            ]))
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
        let horizontalPadding: CGFloat = isTabletLayout ? max(54, size.width * 0.08) : 10
        let maximumCellWidth: CGFloat = isTabletLayout ? 64 : 31
        let boardHeightFraction: CGFloat = isTabletLayout ? 0.60 : 0.52
        cellWidth = min(
            maximumCellWidth,
            (size.width - horizontalPadding * 2) / CGFloat(state.board.columnCount)
        )
        cellHeight = min(
            cellWidth * 1.47,
            (size.height * boardHeightFraction) / CGFloat(state.board.rowCount)
        )
        boardOrigin = CGPoint(
            x: (size.width - boardWidth) / 2,
            y: (size.height - boardHeight) / 2 - (isTabletLayout ? 10 : 6)
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
        title.text = "BUNBUN  •  \(level.displayName.uppercased()) 0.5"
        title.fontSize = (level.displayName.count > 14 ? 16 : 19) * hudScale
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height - 82)
        hudLayer.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitle.text = level.prompt(at: currentShotIndex)
        subtitle.fontSize = 12 * hudScale
        subtitle.fontColor = SKColor(white: 0.72, alpha: 1)
        subtitle.position = CGPoint(x: size.width / 2, y: title.position.y - 24)
        hudLayer.addChild(subtitle)

        let controlInset: CGFloat = isTabletLayout ? 90 : 58
        addControl(name: "debug", text: showsDebug ? "DEBUG ON" : "DEBUG", x: controlInset)
        addControl(name: "restart", text: "RESTART", x: size.width - controlInset)

        let meterWidth = min(isTabletLayout ? 150 : 92, (size.width - 48) / 3)
        let meterY = size.height - 166
        addMeter(
            title: "PROGRESS",
            value: state.progress,
            maximumValue: state.rules.progressTarget,
            color: .systemGreen,
            x: size.width * 0.22,
            y: meterY,
            width: meterWidth
        )
        addMeter(
            title: state.isDancePartyActive ? "DANCE ×2 (\(state.dancePartyTurnsRemaining))" : "DANCE",
            value: state.danceMeter,
            maximumValue: state.rules.danceTarget,
            color: state.isDancePartyActive ? .systemYellow : .systemPurple,
            x: size.width * 0.50,
            y: meterY,
            width: meterWidth
        )
        addMeter(
            title: "DANGER",
            value: state.danger,
            maximumValue: state.rules.dangerLimit,
            color: .systemRed,
            x: size.width * 0.78,
            y: meterY,
            width: meterWidth
        )

        let shot = level.shot(at: currentShotIndex)
        let previewBunny = shot.makeBunny()
        let preview = BunnyNode(
            bunny: previewBunny,
            cellWidth: 22,
            cellHeight: 31,
            color: spriteColor(for: shot.color)
        )
        let previewY = isTabletLayout ? max(72, boardOrigin.y - cellHeight * 1.6) : 69
        preview.position = CGPoint(x: size.width / 2 - (isTabletLayout ? 95 : 75), y: previewY)
        preview.setScale(isTabletLayout ? 1.05 : 0.82)
        hudLayer.addChild(preview)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        let multiplier = state.isDancePartyActive ? "   •   2×" : ""
        let nextName = switch shot.kind {
        case .normal: "Next"
        case .redBomb: "Next BOMB"
        case .lineClear: "Next LINE"
        }
        label.text = "\(nextName)   •   Score \(state.score)   •   Hop in \(state.rules.launchesPerAdvance - state.launchesSinceAdvance)\(multiplier)"
        label.fontSize = 12 * hudScale
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: preview.position.x + 20, y: preview.position.y)
        hudLayer.addChild(label)

        if showsDebug {
            let debug = SKLabelNode(fontNamed: "Menlo")
            debug.text = "side=\(selectedSide.rawValue)  occupied=\(state.board.occupants.count)  state=\(state.status)"
            debug.fontSize = 9 * hudScale
            debug.fontColor = .systemGreen
            debug.position = CGPoint(x: size.width / 2, y: 38)
            hudLayer.addChild(debug)
        }
    }

    private func addControl(name: String, text: String, x: CGFloat) {
        let node = SKLabelNode(fontNamed: "AvenirNext-Bold")
        node.name = "control:\(name)"
        node.text = text
        node.fontSize = 10 * hudScale
        node.fontColor = SKColor(white: 0.70, alpha: 1)
        node.position = CGPoint(x: x, y: size.height - 132)
        hudLayer.addChild(node)
    }

    private func addMeter(
        title: String,
        value: Int,
        maximumValue: Int,
        color: SKColor,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat
    ) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = 8 * hudScale
        label.fontColor = SKColor(white: 0.72, alpha: 1)
        label.position = CGPoint(x: x, y: y + 9)
        hudLayer.addChild(label)

        let track = SKShapeNode(rectOf: CGSize(width: width, height: 7), cornerRadius: 3.5)
        track.position = CGPoint(x: x, y: y - 2)
        track.fillColor = SKColor(white: 0.17, alpha: 1)
        track.strokeColor = SKColor(white: 0.35, alpha: 1)
        track.lineWidth = 1
        hudLayer.addChild(track)

        let fillWidth = max(0, width * CGFloat(value) / CGFloat(max(maximumValue, 1)))
        guard fillWidth > 0 else { return }
        let fill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: 5), cornerRadius: 2.5)
        fill.position = CGPoint(x: x - width / 2 + fillWidth / 2, y: y - 2)
        fill.fillColor = color
        fill.strokeColor = .clear
        fill.zPosition = 1
        hudLayer.addChild(fill)
    }

    private func projectileStartPosition(for side: LaunchSide, lane: Int) -> CGPoint {
        switch side {
        case .left:
            CGPoint(
                x: boardOrigin.x - cellWidth * 0.72,
                y: point(for: Cell(column: 0, row: lane)).y
            )
        case .right:
            CGPoint(
                x: boardOrigin.x + boardWidth + cellWidth * 0.72,
                y: point(for: Cell(column: state.board.columnCount - 1, row: lane)).y
            )
        case .bottom:
            CGPoint(
                x: point(for: Cell(column: lane, row: 0)).x,
                y: boardOrigin.y - cellHeight * 0.72
            )
        }
    }

    private func updateHighlight(at point: CGPoint) {
        if let target = launchTarget(at: point) {
            selectedSide = target.side
            highlightedLane = target.lane
        } else {
            highlightedLane = nil
        }
        drawGrid()
        updateAimReactions()
    }

    private func launchTarget(at point: CGPoint) -> LaunchTarget? {
        let row = Int(((point.y - boardOrigin.y) / cellHeight).rounded(.down))
        let isWithinBoardHeight = row >= 0 && row < state.board.rowCount
        let sideHitSlop = max(12, cellWidth * 0.25)

        if isWithinBoardHeight,
           point.x >= boardOrigin.x - sideHitSlop,
           point.x < boardOrigin.x + cellWidth {
            return LaunchTarget(side: .left, lane: row)
        }

        if isWithinBoardHeight,
           point.x >= boardOrigin.x + boardWidth - cellWidth,
           point.x < boardOrigin.x + boardWidth + sideHitSlop {
            return LaunchTarget(side: .right, lane: row)
        }

        let bottomZoneHeight = max(52, cellHeight * 1.15)
        let isWithinBottomZone = point.y >= boardOrigin.y - bottomZoneHeight
            && point.y < boardOrigin.y
        guard isWithinBottomZone,
              point.x >= boardOrigin.x,
              point.x < boardOrigin.x + boardWidth else { return nil }

        let column = Int((point.x - boardOrigin.x) / cellWidth)
        guard column >= 0, column < state.board.columnCount else { return nil }
        return LaunchTarget(side: .bottom, lane: column)
    }

    private func updateAimReactions() {
        let reactingCells: Set<Cell>
        if let highlightedLane {
            let candidates = state.board.occupants.keys.filter { cell in
                selectedSide == .bottom
                    ? cell.column == highlightedLane
                    : cell.row == highlightedLane
            }
            let ordered = candidates.sorted { lhs, rhs in
                switch selectedSide {
                case .bottom:
                    lhs.row < rhs.row
                case .left:
                    lhs.column < rhs.column
                case .right:
                    lhs.column > rhs.column
                }
            }
            reactingCells = Set(ordered.prefix(3))
        } else {
            reactingCells = []
        }

        for (cell, bunny) in state.board.occupants {
            guard let node = bunnyLayer.childNode(
                withName: "bunny:\(bunny.id.uuidString)"
            ) as? BunnyNode else { continue }

            node.setAiming(reactingCells.contains(cell))
        }
    }

    private func point(for cell: Cell) -> CGPoint {
        CGPoint(
            x: boardOrigin.x + (CGFloat(cell.column) + 0.5) * cellWidth,
            y: boardOrigin.y + (CGFloat(cell.row) + 0.5) * cellHeight
        )
    }

    private func controlName(at point: CGPoint) -> String? {
        for node in hudLayer.children where node.name?.hasPrefix("control:") == true {
            if node.frame.insetBy(dx: -14, dy: -12).contains(point) {
                return node.name?.replacingOccurrences(of: "control:", with: "")
            }
        }

        for hitNode in nodes(at: point) {
            var node: SKNode? = hitNode
            while let candidate = node, candidate !== self {
                if let name = candidate.name, name.hasPrefix("control:") {
                    return name.replacingOccurrences(of: "control:", with: "")
                }
                node = candidate.parent
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
            backgroundColor = themeBackgroundColor
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
        playtestStats.finish()
        let panelHeight: CGFloat = state.status == .won ? 250 : 222
        let panel = SKShapeNode(
            rectOf: CGSize(width: min(isTabletLayout ? 420 : 330, size.width - 38), height: panelHeight),
            cornerRadius: 18
        )
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
        title.position.y = panelHeight / 2 - 35
        panel.addChild(title)

        let prompt = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        prompt.text = state.status == .won
            ? "Score \(state.score)"
            : "Score \(state.score)  •  Ready to try again"
        prompt.fontSize = 12
        prompt.fontColor = SKColor(white: 0.75, alpha: 1)
        prompt.verticalAlignmentMode = .center
        prompt.position.y = panelHeight / 2 - 64
        panel.addChild(prompt)

        let activity = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        activity.text = "Launches \(playtestStats.launches)  •  Falls \(playtestStats.falls)"
        activity.fontSize = 11
        activity.fontColor = SKColor(white: 0.82, alpha: 1)
        activity.verticalAlignmentMode = .center
        activity.position.y = panelHeight / 2 - 90
        panel.addChild(activity)

        let events = SKLabelNode(fontNamed: "AvenirNext-Medium")
        events.text = "Specials \(playtestStats.specialActivations)  •  Parties \(playtestStats.danceParties)  •  \(playtestStats.elapsedSeconds)s"
        events.fontSize = 10
        events.fontColor = SKColor(white: 0.68, alpha: 1)
        events.verticalAlignmentMode = .center
        events.position.y = panelHeight / 2 - 111
        panel.addChild(events)

        if state.status == .won {
            if hasNextLevel {
                addEndButton(to: panel, name: "next", text: "NEXT LEVEL", y: -24)
            }
            addEndButton(to: panel, name: "replay", text: "REPLAY", y: hasNextLevel ? -62 : -38)
            addEndButton(to: panel, name: "levels", text: "LEVELS", y: hasNextLevel ? -100 : -80)
            addConfetti(for: 5)
            if !didReportCompletion {
                didReportCompletion = true
                onLevelCompleted(level.id, state.score)
            }
        } else {
            addEndButton(to: panel, name: "replay", text: "RETRY", y: -43)
            addEndButton(to: panel, name: "levels", text: "LEVELS", y: -83)
        }
    }

    private func addEndButton(to panel: SKNode, name: String, text: String, y: CGFloat) {
        let button = SKShapeNode(rectOf: CGSize(width: 174, height: 31), cornerRadius: 10)
        button.name = "control:\(name)"
        button.position.y = y
        button.fillColor = name == "next" ? .systemGreen : SKColor(white: 0.18, alpha: 1)
        button.strokeColor = name == "next" ? .white : SKColor(white: 0.46, alpha: 1)
        button.lineWidth = name == "next" ? 2 : 1
        panel.addChild(button)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.name = button.name
        label.text = text
        label.fontSize = 12
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        button.addChild(label)
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

    private func pulseLaunchTarget(side: LaunchSide, lane: Int) {
        let position: CGPoint
        switch side {
        case .left:
            position = point(for: Cell(column: 0, row: lane))
        case .right:
            position = point(for: Cell(column: state.board.columnCount - 1, row: lane))
        case .bottom:
            position = CGPoint(
                x: point(for: Cell(column: lane, row: 0)).x,
                y: boardOrigin.y - cellHeight * 0.48
            )
        }

        let pulse = SKShapeNode(
            rectOf: CGSize(width: cellWidth - 2, height: cellHeight - 2),
            cornerRadius: 5
        )
        pulse.position = position
        pulse.fillColor = .clear
        pulse.strokeColor = .systemOrange
        pulse.lineWidth = 4
        pulse.zPosition = 35
        effectLayer.addChild(pulse)
        pulse.run(.sequence([
            .group([
                .scale(to: 1.18, duration: 0.16),
                .fadeOut(withDuration: 0.22)
            ]),
            .removeFromParent()
        ]))
    }

    private func resetGame() {
        removeAllActions()
        effectLayer.removeAllChildren()
        state = GameState(board: level.startingBoard(), rules: level.rules)
        currentShotIndex = 0
        selectedSide = .bottom
        highlightedLane = nil
        isAnimating = false
        showsDanceParty = false
        didReportCompletion = false
        playtestStats = PlaytestRunStats()
        partyLayer.removeAllChildren()
        backgroundColor = themeBackgroundColor
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

    private var themeBackgroundColor: SKColor {
        switch level.theme {
        case .lab:
            SKColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1)
        case .meadow:
            SKColor(red: 0.025, green: 0.105, blue: 0.105, alpha: 1)
        case .rehearsal:
            SKColor(red: 0.105, green: 0.035, blue: 0.14, alpha: 1)
        }
    }
}
