import SpriteKit
import UIKit

enum TelevisionNavigation {
    case previousSide
    case nextSide
    case previousLane
    case nextLane
}

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

    private let level: LevelDefinition
    private let mode: GameMode
    private let hasNextLevel: Bool
    private let onLevelCompleted: (LevelID, Int) -> Void
    private let onRunEnded: (Int) -> Void
    private let onRequestLevels: () -> Void
    private let onRequestNextLevel: () -> Void
    private let audio = AudioDirector()

    private var state: GameState
    private var currentShotIndex = 0
    private var selectedSide: LaunchSide = .bottom
    private var highlightedLane: Int?
    private var isAnimating = false
#if DEBUG
    private var showsDebug = false
#endif
    private var showsDanceParty = false
    private var didReportCompletion = false
    private var didPlayEndCue = false
    private var playtestStats = PlaytestRunStats()

    private let backgroundLayer = SKNode()
    private let ambientLightLayer = SKNode()
    private let partyLayer = SKNode()
    private let boardStageLayer = SKNode()
    private let streamLayer = SKNode()
    private let gridLayer = SKNode()
    private let aimLayer = SKNode()
    private let bunnyLayer = SKNode()
    private let effectLayer = SKNode()
    private let hudLayer = SKNode()

    private var boardOrigin = CGPoint.zero
    private var cellWidth: CGFloat = 24
    private var cellHeight: CGFloat = 34
    private var backgroundImageFrame = CGRect.zero

    private var isTabletLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var isTelevisionLayout: Bool {
#if os(tvOS)
        true
#else
        false
#endif
    }

    private var isLargeScreenLayout: Bool {
        isTabletLayout || isTelevisionLayout
    }

    private var hudScale: CGFloat {
        if isTelevisionLayout { return 1.75 }
        return isTabletLayout ? 1.22 : 1
    }

    private var perspectiveProfile: BoardProjection.Profile {
        if isTelevisionLayout { return .television }
        return isTabletLayout ? .tablet : .phone
    }

    private var boardProjection: BoardProjection {
        BoardProjection(
            boardOrigin: boardOrigin,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            rowCount: state.board.rowCount,
            columnCount: state.board.columnCount,
            profile: perspectiveProfile
        )
    }

    init(
        size: CGSize,
        level: LevelDefinition = LevelCatalog.bunnyLab,
        mode: GameMode = .classic,
        hasNextLevel: Bool = false,
        onLevelCompleted: @escaping (LevelID, Int) -> Void = { _, _ in },
        onRunEnded: @escaping (Int) -> Void = { _ in },
        onRequestLevels: @escaping () -> Void = {},
        onRequestNextLevel: @escaping () -> Void = {}
    ) {
        self.level = level
        self.mode = mode
        self.hasNextLevel = hasNextLevel
        self.onLevelCompleted = onLevelCompleted
        self.onRunEnded = onRunEnded
        self.onRequestLevels = onRequestLevels
        self.onRequestNextLevel = onRequestNextLevel
        state = GameState(board: level.startingBoard(), rules: level.rules, mode: mode)
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = themeBackgroundColor
        backgroundLayer.zPosition = -1_000
        ambientLightLayer.zPosition = -900
        partyLayer.zPosition = -800
        boardStageLayer.zPosition = 0
        streamLayer.zPosition = -10
        gridLayer.zPosition = -5
        aimLayer.zPosition = 1
        bunnyLayer.zPosition = 5
        effectLayer.zPosition = 200
        hudLayer.zPosition = 300
        addChild(backgroundLayer)
        addChild(ambientLightLayer)
        addChild(partyLayer)
        addChild(boardStageLayer)
        boardStageLayer.addChild(streamLayer)
        boardStageLayer.addChild(gridLayer)
        boardStageLayer.addChild(aimLayer)
        boardStageLayer.addChild(bunnyLayer)
        addChild(effectLayer)
        addChild(hudLayer)
#if os(tvOS)
        selectedSide = .left
        highlightedLane = min(5, state.board.rowCount - 1)
#endif
        renderAll()
        // The cleaned sheets are inexpensive to split, and asking SpriteKit to
        // upload them now prevents the first cascade or dance party from
        // compiling/uploading several animation sets during a live transition.
        BunnyNode.preloadAnimationTextures()
        audio.startMusic()
        updateAudioMix()
    }

    override func willMove(from view: SKView) {
        audio.stop()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard oldSize != .zero else { return }
        renderAll()
    }

    override func didFinishUpdate() {
        // BunnyNodes are always direct children of these three layers
        // (board bunnies, projectiles, HUD preview), so scan them without
        // recursing into the background, grid, stream, and effects subtrees.
        for layer in [bunnyLayer, effectLayer, hudLayer] {
            for child in layer.children {
                (child as? BunnyNode)?.enforceDisplaySize()
            }
        }
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
#if DEBUG
            case "debug":
                showsDebug.toggle()
                renderAll()
#endif
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

    // MARK: - Animation

    private func animateShot(
        bunny: Bunny,
        side: LaunchSide,
        lane: Int,
        result: LaunchResult,
        completion: @escaping () -> Void
    ) {
        let start = projectileStartPosition(for: side, lane: lane)
        let end: CGPoint
        let destinationScale: CGFloat

        switch result {
        case let .placed(cell):
            audio.play(.launch)
            end = point(for: cell)
            destinationScale = boardProjection.bunnyScale(for: cell.row)
        case .passedThrough:
            audio.play(.launch)
            let rowY = point(for: Cell(column: 0, row: lane)).y
            let bounds = boardProjection.rowBounds(for: lane)
            let localCellWidth = cellWidth * boardProjection.rowWidthScale(for: lane)
            end = CGPoint(
                x: side == .left
                    ? bounds.upperBound + localCellWidth
                    : bounds.lowerBound - localCellWidth,
                y: rowY
            )
            destinationScale = boardProjection.bunnyScale(for: lane)
        case .blocked:
            audio.play(.blocked)
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
            .group([move, .scale(to: destinationScale, duration: duration)]),
            .run {
#if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
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
            reconcileBunnies(with: outcome.boardAfterResolution)
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
        reconcileBunnies(with: stage.boardBefore)
        let specialKinds = Set(stage.specialActivations.map(\.kind))
        audio.play(stage.depth == 1 ? .match : .chain, emphasis: stage.depth - 1)
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
#if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(stage.depth == 1 ? .success : .warning)
#endif
        addConfetti(for: stage.depth)

        for activation in stage.specialActivations {
            run(.sequence([
                .wait(forDuration: 0.34),
                .run { [weak self] in
                    self?.audio.play(activation.kind == .redBomb ? .bomb : .line)
                    self?.addSpecialEffect(activation)
                }
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
        audio.play(.hop)
        reconcileBunnies(with: outcome.boardAfterResolution)
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
#if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
        let postTransitionWait = outcome.fallenBunnies.isEmpty ? 0.40 : 1.85
        run(.sequence([
            .wait(forDuration: 0.56),
            .run { [weak self] in
                if !outcome.fallenBunnies.isEmpty {
                    self?.audio.play(.rescue)
                }
                self?.animateBoardTransition(
                    from: outcome.boardAfterResolution,
                    to: outcome.boardAfterTurn,
                    duration: 0.34,
                    rescuesMissingBunnies: !outcome.fallenBunnies.isEmpty,
                    animatesEntrants: true
                )
            },
            .wait(forDuration: postTransitionWait),
            .run { [weak self] in
                if !outcome.fallenBunnies.isEmpty {
                    self?.flashMessage(
                        outcome.fallenBunnies.count == 1 ? "SAFE IN A TUBE!" : "TUBE PARADE!",
                        color: .systemCyan
                    )
                }
                self?.finishAnimation()
            }
        ]))
    }

    private func finishAnimation() {
        reconcileBunnies(with: state.board)
        drawStream()
#if os(tvOS)
        highlightedLane = min(highlightedLane ?? 0, maximumTelevisionLane)
        drawGrid()
        updateAimReactions()
#endif
        drawHUD()
        updateAudioMix()
        isAnimating = false
        showEndStateIfNeeded()
    }

    private func animateBoardTransition(
        from oldBoard: Board,
        to newBoard: Board,
        duration: TimeInterval,
        rescuesMissingBunnies: Bool = false,
        animatesEntrants: Bool = false
    ) {
        let newLocations = Dictionary(uniqueKeysWithValues: newBoard.occupants.map { ($0.value.id, $0.key) })

        for (cell, bunny) in oldBoard.occupants {
            guard let node = bunnyLayer.childNode(withName: "bunny:\(bunny.id.uuidString)") as? BunnyNode else { continue }
            if let newCell = newLocations[bunny.id] {
                let move = SKAction.move(to: point(for: newCell), duration: duration)
                move.timingMode = .easeInEaseOut
                let newScale = boardProjection.bunnyScale(for: newCell.row)
                node.zPosition = boardProjection.depthPosition(for: newCell.row)
                node.run(move, withKey: "boardTransition")
                node.setPresentationScale(newScale, duration: duration)
            } else if rescuesMissingBunnies {
                animateTubeRescue(node, from: cell)
            } else {
                node.run(.group([
                    .moveBy(x: 0, y: -cellHeight * 1.2, duration: duration),
                    .fadeOut(withDuration: duration)
                ]))
            }
        }

        let refreshDelay = rescuesMissingBunnies ? max(duration, 1.75) : duration
        run(.sequence([
            .wait(forDuration: refreshDelay),
            .run { [weak self] in
                self?.reconcileBunnies(with: newBoard, animateEntrants: animatesEntrants)
            }
        ]))
    }

    private func animateTubeRescue(_ bunny: BunnyNode, from cell: Cell) {
        let start = point(for: cell)
        let splashPoint = CGPoint(x: start.x, y: streamCenterY + cellHeight * 0.03)
        let tube = makeInnerTube(seed: bunny.bunnyID.hashValue)
        tube.position = CGPoint(x: 0, y: -cellHeight * 0.22)
        tube.zPosition = -2
        bunny.addChild(tube)
        bunny.zPosition = 18
        bunny.playRescue()

        let enterWater = SKAction.move(to: splashPoint, duration: 0.28)
        enterWater.timingMode = .easeIn

        let floatPath = CGMutablePath()
        floatPath.move(to: splashPoint)
        let exitX = size.width + cellWidth * 1.8
        let travel = exitX - splashPoint.x
        floatPath.addCurve(
            to: CGPoint(x: splashPoint.x + travel * 0.36, y: splashPoint.y + cellHeight * 0.07),
            control1: CGPoint(x: splashPoint.x + travel * 0.12, y: splashPoint.y + cellHeight * 0.16),
            control2: CGPoint(x: splashPoint.x + travel * 0.24, y: splashPoint.y - cellHeight * 0.10)
        )
        floatPath.addCurve(
            to: CGPoint(x: splashPoint.x + travel * 0.70, y: splashPoint.y - cellHeight * 0.03),
            control1: CGPoint(x: splashPoint.x + travel * 0.48, y: splashPoint.y + cellHeight * 0.14),
            control2: CGPoint(x: splashPoint.x + travel * 0.58, y: splashPoint.y - cellHeight * 0.13)
        )
        floatPath.addCurve(
            to: CGPoint(x: exitX, y: splashPoint.y + cellHeight * 0.05),
            control1: CGPoint(x: splashPoint.x + travel * 0.80, y: splashPoint.y + cellHeight * 0.13),
            control2: CGPoint(x: splashPoint.x + travel * 0.92, y: splashPoint.y - cellHeight * 0.08)
        )
        let floatAway = SKAction.follow(
            floatPath,
            asOffset: false,
            orientToPath: false,
            duration: 1.10
        )
        floatAway.timingMode = .easeInEaseOut

        tube.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.07, duration: 0.24, shortestUnitArc: true),
            .rotate(toAngle: -0.07, duration: 0.30, shortestUnitArc: true)
        ])), withKey: "tubeBob")

        bunny.run(.sequence([
            .wait(forDuration: 0.22),
            .group([enterWater, .scale(to: 0.90, duration: 0.28)]),
            .run { [weak self] in self?.addWaterSplash(at: splashPoint) },
            floatAway,
            .fadeOut(withDuration: 0.10),
            .removeFromParent()
        ]))
    }

    private func makeInnerTube(seed: Int) -> SKNode {
        let container = SKNode()
        let palette: [SKColor] = [.systemOrange, .systemPink, .systemYellow, .systemTeal]
        let index = Int(UInt(bitPattern: seed) % UInt(palette.count))
        let tube = SKShapeNode(
            ellipseOf: CGSize(width: cellWidth * 0.92, height: cellHeight * 0.34)
        )
        tube.fillColor = palette[index]
        tube.strokeColor = .white.withAlphaComponent(0.86)
        tube.lineWidth = max(1.5, cellWidth * 0.08)
        tube.glowWidth = cellWidth * 0.05
        container.addChild(tube)

        let opening = SKShapeNode(
            ellipseOf: CGSize(width: cellWidth * 0.43, height: cellHeight * 0.15)
        )
        opening.fillColor = SKColor(red: 0.04, green: 0.30, blue: 0.50, alpha: 0.82)
        opening.strokeColor = SKColor(white: 1, alpha: 0.54)
        opening.lineWidth = 1
        opening.zPosition = 1
        container.addChild(opening)
        return container
    }

    private func addWaterSplash(at position: CGPoint) {
        for index in 0..<7 {
            let drop = SKShapeNode(circleOfRadius: max(1.5, cellWidth * 0.055))
            drop.position = position
            drop.fillColor = SKColor(red: 0.60, green: 0.93, blue: 1, alpha: 0.92)
            drop.strokeColor = .clear
            drop.zPosition = 31
            effectLayer.addChild(drop)
            let angle = CGFloat.pi * (0.16 + 0.68 * CGFloat(index) / 6)
            let distance = cellWidth * (0.45 + CGFloat(index % 3) * 0.16)
            drop.run(.sequence([
                .group([
                    .moveBy(
                        x: cos(angle) * distance,
                        y: sin(angle) * distance,
                        duration: 0.28
                    ),
                    .fadeOut(withDuration: 0.28)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func renderAll() {
        guard size.width > 0, size.height > 0 else { return }
        layoutBackground()
        layoutBoard()
        drawStream()
        drawGrid()
        updateBunnies(state.board)
        updateAimReactions()
        drawHUD()
        if showsDanceParty {
            configureDancePartyBackdrop()
        }
    }

    private func layoutBackground() {
        backgroundLayer.removeAllChildren()

        let texture = SKTexture(imageNamed: level.backgroundAssetName)
        texture.filteringMode = .linear
        let textureSize = texture.size()
        guard textureSize.width > 0, textureSize.height > 0 else { return }

        let fillScale = max(size.width / textureSize.width, size.height / textureSize.height)
        let image = SKSpriteNode(
            texture: texture,
            size: CGSize(
                width: textureSize.width * fillScale,
                height: textureSize.height * fillScale
            )
        )
        image.position = CGPoint(x: size.width / 2, y: size.height / 2)
        image.zPosition = -100
        backgroundLayer.addChild(image)
        backgroundImageFrame = image.frame

        let shade = SKShapeNode(rectOf: size)
        shade.position = CGPoint(x: size.width / 2, y: size.height / 2)
        shade.fillColor = SKColor(
            white: 0,
            alpha: SceneEnvironment.shadeAlpha(for: level.environment, isTablet: isTabletLayout)
        )
        shade.strokeColor = .clear
        shade.zPosition = -99
        backgroundLayer.addChild(shade)

        renderEnvironmentEffects(danceMode: showsDanceParty)
    }

    // MARK: - Environment

    private func renderEnvironmentEffects(danceMode: Bool) {
        SceneEnvironment.configure(
            ambientLightLayer,
            context: SceneEnvironment.Context(
                size: size,
                environment: level.environment,
                backgroundFrame: backgroundImageFrame,
                isTablet: isTabletLayout,
                danceMode: danceMode
            )
        )
    }

    // MARK: - Board Layout

    private func layoutBoard() {
        let horizontalPadding: CGFloat
        let maximumCellWidth: CGFloat
        let boardHeightFraction: CGFloat
        if isTelevisionLayout {
            horizontalPadding = max(180, size.width * 0.17)
            maximumCellWidth = 76
            boardHeightFraction = 0.54
        } else if isTabletLayout {
            horizontalPadding = max(42, size.width * 0.06)
            maximumCellWidth = 90
            boardHeightFraction = 0.60
        } else {
            horizontalPadding = 10
            maximumCellWidth = 31
            boardHeightFraction = 0.52
        }
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
            y: (size.height - boardHeight) / 2 - (isLargeScreenLayout ? 10 : 6)
        )

        let boardCenter = CGPoint(
            x: boardOrigin.x + boardWidth / 2,
            y: boardOrigin.y + boardHeight / 2
        )
        boardStageLayer.position = boardCenter
        let childOffset = CGPoint(x: -boardCenter.x, y: -boardCenter.y)
        for layer in [streamLayer, gridLayer, aimLayer, bunnyLayer] {
            layer.position = childOffset
        }
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
                let isSelectedSideSlot = !isOutside
                    || selectedSide == .left && column == 0
                    || selectedSide == .right && column == state.board.columnCount - 1
                let isHighlighted = isSelectedSideSlot && (highlightedLane.map { lane in
                    selectedSide == .bottom ? lane == column : lane == row
                } ?? false)

                let slotSize = isOutside
                    ? CGSize(width: cellWidth - 3, height: cellHeight - 4)
                    : CGSize(width: cellWidth * 0.62, height: max(4, cellHeight * 0.15))
                let slot = SKShapeNode(rectOf: slotSize, cornerRadius: slotSize.height / 2)
                slot.position = point(for: cell)
                slot.xScale = boardProjection.rowWidthScale(for: row)
                if !isOutside {
                    slot.position.y -= cellHeight * 0.27
                }
                slot.fillColor = isHighlighted
                    ? SKColor.systemYellow.withAlphaComponent(isOutside ? 0.09 : 0.11)
                    : isOutside
                        ? .clear
                        : SKColor(white: 0.05, alpha: 0.12)
                slot.strokeColor = isHighlighted
                    ? .systemYellow.withAlphaComponent(isOutside ? 0.92 : 0.28)
                    : isOutside
                        ? SKColor(red: 0.77, green: 0.68, blue: 0.88, alpha: 0.24)
                        : SKColor(white: 0.92, alpha: 0.09)
                slot.lineWidth = isOutside ? (isHighlighted ? 1.8 : 0.85) : 0.8
                gridLayer.addChild(slot)
            }
        }
    }

    private var streamCenterY: CGFloat {
        boardOrigin.y - max(15, cellHeight * 0.48)
    }

    private func drawStream() {
        streamLayer.removeAllChildren()

        let dangerFraction = min(
            1,
            CGFloat(state.danger) / CGFloat(max(state.rules.dangerLimit, 1))
        )
        let streamHeight = max(26, cellHeight * 0.82)
        let streamWidth = size.width + cellWidth * 1.2
        let center = CGPoint(x: boardOrigin.x + boardWidth / 2, y: streamCenterY)

        let bank = SKShapeNode(path: creekPath(
            center: center,
            width: streamWidth + 9,
            height: streamHeight + 10,
            wobble: streamHeight * 0.16,
            boardFacingWobble: streamHeight * 0.025
        ))
        bank.fillColor = streamBankColor
        bank.strokeColor = SKColor(white: 1, alpha: 0.25)
        bank.lineWidth = 1.2
        bank.zPosition = -3
        streamLayer.addChild(bank)

        let renderedWater = SKTexture(imageNamed: "CreekWaterRendered")
        renderedWater.filteringMode = .linear
        let waterBand = SKTexture(
            rect: CGRect(x: 0, y: 0.40, width: 1, height: 0.20),
            in: renderedWater
        )
        waterBand.filteringMode = .linear
        let water = SKSpriteNode(
            texture: waterBand,
            size: CGSize(width: streamWidth + cellWidth, height: streamHeight * 1.10)
        )
        water.position = center
        water.color = streamWaterTint(dangerFraction: dangerFraction)
        water.colorBlendFactor = streamWaterTintStrength(dangerFraction: dangerFraction)
        water.alpha = 0.96
        let waterCrop = SKCropNode()
        let waterMask = SKShapeNode(path: creekPath(
            center: center,
            width: streamWidth,
            height: streamHeight,
            wobble: streamHeight * 0.13,
            boardFacingWobble: streamHeight * 0.018
        ))
        waterMask.fillColor = .white
        waterMask.strokeColor = .clear
        waterCrop.maskNode = waterMask
        waterCrop.zPosition = -2
        waterCrop.addChild(water)
        streamLayer.addChild(waterCrop)

        let waterEdge = SKShapeNode(path: creekPath(
            center: center,
            width: streamWidth,
            height: streamHeight,
            wobble: streamHeight * 0.13,
            boardFacingWobble: streamHeight * 0.018
        ))
        waterEdge.fillColor = .clear
        waterEdge.strokeColor = SKColor(
            red: 0.48 + dangerFraction * 0.18,
            green: 0.90 - dangerFraction * 0.22,
            blue: 1,
            alpha: 0.60 + dangerFraction * 0.22
        )
        waterEdge.lineWidth = 1.4 + dangerFraction * 1.3
        waterEdge.glowWidth = 1.5 + dangerFraction * 3.5
        waterEdge.zPosition = -1.5
        streamLayer.addChild(waterEdge)

        let waveCount = 7 + Int(dangerFraction * 5)
        let flowDuration = max(0.7, 1.65 - TimeInterval(dangerFraction) * 0.72)
        for index in 0..<waveCount {
            let width = cellWidth * (0.38 + CGFloat(index % 3) * 0.13)
            let wave = SKShapeNode(
                rectOf: CGSize(width: width, height: max(1.5, streamHeight * 0.075)),
                cornerRadius: streamHeight * 0.04
            )
            let usableWidth = max(1, streamWidth - width)
            wave.position = CGPoint(
                x: center.x - streamWidth / 2 + CGFloat(index) / CGFloat(max(waveCount - 1, 1)) * usableWidth,
                y: center.y + CGFloat((index * 11) % 17) / 17 * streamHeight * 0.54 - streamHeight * 0.27
            )
            wave.fillColor = SKColor(white: 1, alpha: 0.34 + dangerFraction * 0.18)
            wave.strokeColor = .clear
            wave.zPosition = 1
            waterCrop.addChild(wave)
            wave.run(.repeatForever(.sequence([
                .moveBy(x: cellWidth * 0.55, y: 0, duration: flowDuration),
                .moveBy(x: -cellWidth * 0.55, y: 0, duration: 0)
            ])))
        }

    }

    private func creekPath(
        center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        wobble: CGFloat,
        boardFacingWobble: CGFloat? = nil
    ) -> CGPath {
        let left = center.x - width / 2
        let right = center.x + width / 2
        let top = center.y + height / 2
        let bottom = center.y - height / 2
        let topWobble = boardFacingWobble ?? wobble
        let path = CGMutablePath()
        path.move(to: CGPoint(x: left, y: top - topWobble * 0.25))
        path.addCurve(
            to: CGPoint(x: left + width * 0.34, y: top + topWobble * 0.30),
            control1: CGPoint(x: left + width * 0.10, y: top + topWobble),
            control2: CGPoint(x: left + width * 0.24, y: top - topWobble * 0.65)
        )
        path.addCurve(
            to: CGPoint(x: left + width * 0.68, y: top - topWobble * 0.18),
            control1: CGPoint(x: left + width * 0.45, y: top + topWobble * 0.72),
            control2: CGPoint(x: left + width * 0.58, y: top - topWobble * 0.82)
        )
        path.addCurve(
            to: CGPoint(x: right, y: top + topWobble * 0.12),
            control1: CGPoint(x: left + width * 0.79, y: top + topWobble * 0.52),
            control2: CGPoint(x: left + width * 0.91, y: top - topWobble * 0.55)
        )
        path.addLine(to: CGPoint(x: right, y: bottom - wobble * 0.18))
        path.addCurve(
            to: CGPoint(x: left + width * 0.66, y: bottom + wobble * 0.16),
            control1: CGPoint(x: left + width * 0.90, y: bottom - wobble * 0.74),
            control2: CGPoint(x: left + width * 0.78, y: bottom + wobble * 0.68)
        )
        path.addCurve(
            to: CGPoint(x: left + width * 0.31, y: bottom - wobble * 0.24),
            control1: CGPoint(x: left + width * 0.55, y: bottom - wobble * 0.64),
            control2: CGPoint(x: left + width * 0.43, y: bottom + wobble * 0.78)
        )
        path.addCurve(
            to: CGPoint(x: left, y: bottom + wobble * 0.10),
            control1: CGPoint(x: left + width * 0.20, y: bottom - wobble * 0.82),
            control2: CGPoint(x: left + width * 0.08, y: bottom + wobble * 0.72)
        )
        path.closeSubpath()
        return path
    }

    private var streamBankColor: SKColor {
        switch level.theme {
        case .lab:
            SKColor(red: 0.76, green: 0.58, blue: 0.34, alpha: 0.92)
        case .meadow:
            SKColor(red: 0.24, green: 0.43, blue: 0.20, alpha: 0.94)
        case .rehearsal:
            SKColor(red: 0.73, green: 0.84, blue: 0.92, alpha: 0.95)
        }
    }

    private func streamWaterTint(dangerFraction: CGFloat) -> SKColor {
        switch level.environment {
        case .desertCamp:
            SKColor(
                red: 0.10 + dangerFraction * 0.12,
                green: 0.62 - dangerFraction * 0.10,
                blue: 0.82 + dangerFraction * 0.08,
                alpha: 1
            )
        case .forestCampDay:
            SKColor(red: 0.07, green: 0.54, blue: 0.72, alpha: 1)
        case .forestCampNight:
            SKColor(
                red: 0.02 + dangerFraction * 0.10,
                green: 0.24 - dangerFraction * 0.05,
                blue: 0.44 + dangerFraction * 0.10,
                alpha: 1
            )
        case .snowyWoodland:
            SKColor(red: 0.44, green: 0.78, blue: 0.91, alpha: 1)
        }
    }

    private func streamWaterTintStrength(dangerFraction: CGFloat) -> CGFloat {
        let base: CGFloat = level.environment == .forestCampNight ? 0.38 : 0.18
        return min(0.52, base + dangerFraction * 0.14)
    }

    private func updateBunnies(_ board: Board, animateEntrants: Bool = false) {
        bunnyLayer.removeAllChildren()
        let occupants = board.occupants.sorted { lhs, rhs in
            if lhs.key.row != rhs.key.row { return lhs.key.row > rhs.key.row }
            return lhs.key.column < rhs.key.column
        }
        for (cell, bunny) in occupants {
            addBunnyNode(bunny, at: cell, on: board, animateEntrant: animateEntrants)
        }
    }

    /// Brings the presentation into agreement with a rules board while keeping
    /// surviving BunnyNodes alive. Rebuilding the entire crowd at every chain
    /// stage restarted sprite sheets and briefly restored pre-collapse poses,
    /// which read as a backward jump on high-refresh-rate devices.
    private func reconcileBunnies(with board: Board, animateEntrants: Bool = false) {
        let targetLocations = Dictionary(
            uniqueKeysWithValues: board.occupants.map { ($0.value.id, ($0.key, $0.value)) }
        )
        let existingNodes = bunnyLayer.children.compactMap { $0 as? BunnyNode }
        let existingIDs = Set(existingNodes.map(\.bunnyID))

        for node in existingNodes {
            guard let (cell, _) = targetLocations[node.bunnyID] else {
                node.removeFromParent()
                continue
            }

            node.removeAction(forKey: "boardTransition")
            node.position = point(for: cell)
            node.alpha = 1
            node.setScale(1)
            node.setPresentationScale(boardProjection.bunnyScale(for: cell.row))
            node.zPosition = boardProjection.depthPosition(for: cell.row)
            node.setDancing(showsDanceParty)
        }

        let occupants = board.occupants.sorted { lhs, rhs in
            if lhs.key.row != rhs.key.row { return lhs.key.row > rhs.key.row }
            return lhs.key.column < rhs.key.column
        }
        for (cell, bunny) in occupants where !existingIDs.contains(bunny.id) {
            addBunnyNode(bunny, at: cell, on: board, animateEntrant: animateEntrants)
        }
    }

    private func addBunnyNode(
        _ bunny: Bunny,
        at cell: Cell,
        on board: Board,
        animateEntrant: Bool
    ) {
        let node = BunnyNode(
            bunny: bunny,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            color: spriteColor(for: bunny.color),
            presentationScale: boardProjection.bunnyScale(for: cell.row)
        )
        node.position = point(for: cell)
        node.zPosition = boardProjection.depthPosition(for: cell.row)
        node.setDancing(showsDanceParty)
        if animateEntrant && cell.row == board.rowCount - 1 {
            node.alpha = 0
            node.setScale(0.45)
            node.run(.group([
                .fadeIn(withDuration: 0.18),
                .scale(to: 1, duration: 0.22)
            ]))
        }
        bunnyLayer.addChild(node)
    }

    // MARK: - HUD

    private func drawHUD() {
        let shot = level.shot(at: currentShotIndex)
#if os(tvOS)
        let televisionStatus: String? = "\(selectedSide.rawValue.uppercased())  •  LANE \((highlightedLane ?? 0) + 1)"
#else
        let televisionStatus: String? = nil
#endif
        HUD.render(in: hudLayer, context: HUD.Context(
            size: size,
            boardOriginY: boardOrigin.y,
            cellHeight: cellHeight,
            isTablet: isTabletLayout,
            isTelevision: isTelevisionLayout,
            hudScale: hudScale,
            levelName: level.displayName,
            appVersion: AppVersion.marketingVersion,
            subtitle: mode == .endless
                ? "Keep matching — pressure rises every 24 hops"
                : level.prompt(at: currentShotIndex),
            debugControlText: debugControlText(),
            debugLine: debugLine(),
            meters: [
                mode == .endless
                    ? HUD.Meter(
                        title: "STAGE \(state.endlessStage)",
                        value: state.totalLaunches % 24,
                        maximumValue: 24,
                        color: .systemGreen
                    )
                    : HUD.Meter(
                        title: "PROGRESS",
                        value: state.progress,
                        maximumValue: state.rules.progressTarget,
                        color: .systemGreen
                    ),
                HUD.Meter(
                    title: state.isDancePartyActive ? "DANCE ×2 (\(state.dancePartyTurnsRemaining))" : "DANCE",
                    value: state.danceMeter,
                    maximumValue: state.rules.danceTarget,
                    color: state.isDancePartyActive ? .systemYellow : .systemPurple
                ),
                HUD.Meter(
                    title: "DANGER",
                    value: state.danger,
                    maximumValue: state.rules.dangerLimit,
                    color: .systemRed
                ),
            ],
            previewBunny: shot.makeBunny(),
            previewTint: spriteColor(for: shot.color),
            shotKind: shot.kind,
            score: state.score,
            launchesUntilAdvance: state.launchesUntilAdvance,
            danceActive: state.isDancePartyActive,
            televisionStatus: televisionStatus
        ))
    }

    private func debugControlText() -> String? {
#if DEBUG
        showsDebug ? "DEBUG ON" : "DEBUG"
#else
        nil
#endif
    }

    private func debugLine() -> String? {
#if DEBUG
        guard showsDebug else { return nil }
        return "side=\(selectedSide.rawValue)  occupied=\(state.board.occupants.count)  state=\(state.status)"
#else
        return nil
#endif
    }

    private func projectileStartPosition(for side: LaunchSide, lane: Int) -> CGPoint {
        switch side {
        case .left:
            let bounds = boardProjection.rowBounds(for: lane)
            return CGPoint(
                x: bounds.lowerBound - cellWidth * boardProjection.rowWidthScale(for: lane) * 0.72,
                y: point(for: Cell(column: 0, row: lane)).y
            )
        case .right:
            let bounds = boardProjection.rowBounds(for: lane)
            return CGPoint(
                x: bounds.upperBound + cellWidth * boardProjection.rowWidthScale(for: lane) * 0.72,
                y: point(for: Cell(column: state.board.columnCount - 1, row: lane)).y
            )
        case .bottom:
            return CGPoint(
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

    private func launchTarget(at point: CGPoint) -> LaunchZones.Target? {
        LaunchZones.target(
            at: point,
            layout: LaunchZones.Layout(
                size: size,
                boardOrigin: boardOrigin,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                boardWidth: boardWidth,
                rowCount: state.board.rowCount,
                columnCount: state.board.columnCount,
                rowCenters: boardProjection.rowCenters,
                rowWidthScales: boardProjection.rowWidthScales
            )
        )
    }

    private func updateAimReactions() {
        let orderedCells: [Cell]
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
            orderedCells = Array(ordered.prefix(3))
        } else {
            orderedCells = []
        }

        let reactingCells = Set(orderedCells)
        let destinationCell = orderedCells.first
        drawAimGuide(to: destinationCell)
        updateBoardLean()

        for (cell, bunny) in state.board.occupants {
            guard let node = bunnyLayer.childNode(
                withName: "bunny:\(bunny.id.uuidString)"
            ) as? BunnyNode else { continue }

            node.setAiming(reactingCells.contains(cell))
            node.removeAction(forKey: "aimPull")
            let basePosition = point(for: cell)
            let isDestination = cell == destinationCell
            let destination = isDestination
                ? CGPoint(
                    x: basePosition.x + aimPullOffset.dx,
                    y: basePosition.y + aimPullOffset.dy
                )
                : basePosition
            let move = SKAction.move(to: destination, duration: 0.13)
            move.timingMode = .easeOut
            let scale = SKAction.scale(to: isDestination ? 1.07 : 1, duration: 0.13)
            node.zPosition = isDestination
                ? 12
                : boardProjection.depthPosition(for: cell.row)
            node.run(.group([move, scale]), withKey: "aimPull")
        }
    }

    private var aimPullOffset: CGVector {
        switch selectedSide {
        case .left:
            CGVector(dx: -cellWidth * 0.13, dy: cellHeight * 0.09)
        case .right:
            CGVector(dx: cellWidth * 0.13, dy: cellHeight * 0.09)
        case .bottom:
            CGVector(dx: 0, dy: -cellHeight * 0.07)
        }
    }

    private func drawAimGuide(to destinationCell: Cell?) {
        aimLayer.removeAllChildren()
        guard let lane = highlightedLane else { return }

        let start = projectileStartPosition(for: selectedSide, lane: lane)
        let fallback: CGPoint = switch selectedSide {
        case .left:
            point(for: Cell(column: state.board.columnCount - 1, row: lane))
        case .right:
            point(for: Cell(column: 0, row: lane))
        case .bottom:
            point(for: Cell(column: lane, row: state.board.rowCount - 1))
        }
        let end = destinationCell.map(point(for:)) ?? fallback

        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        let beam = SKShapeNode(path: path)
        beam.strokeColor = SKColor(red: 1, green: 0.96, blue: 0.60, alpha: 0.25)
        beam.lineWidth = max(2, cellWidth * 0.12)
        beam.glowWidth = cellWidth * 0.28
        beam.zPosition = 0
        aimLayer.addChild(beam)

        for index in 0..<9 {
            let progress = CGFloat(index + 1) / 9
            let spot = SKShapeNode(circleOfRadius: cellWidth * (0.08 + progress * 0.10))
            spot.position = CGPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            )
            spot.fillColor = SKColor(
                red: 1,
                green: 0.94,
                blue: 0.48,
                alpha: 0.035 + progress * 0.12
            )
            spot.strokeColor = .clear
            spot.glowWidth = cellWidth * progress * 0.16
            spot.zPosition = 1
            aimLayer.addChild(spot)
        }
    }

    private func updateBoardLean() {
        let angle: CGFloat
        if highlightedLane == nil {
            angle = 0
        } else {
            angle = switch selectedSide {
            case .left: -0.018
            case .right: 0.018
            case .bottom: 0
            }
        }
        let rotate = SKAction.rotate(toAngle: angle, duration: 0.15, shortestUnitArc: true)
        rotate.timingMode = .easeOut
        boardStageLayer.run(rotate, withKey: "aimLean")
    }

    private func point(for cell: Cell) -> CGPoint {
        boardProjection.point(for: cell)
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
            let rowBounds = boardProjection.rowBounds(for: activation.cell.row)
            let horizontal = SKShapeNode(
                rectOf: CGSize(
                    width: rowBounds.upperBound - rowBounds.lowerBound + cellWidth,
                    height: max(7, cellHeight * 0.22)
                ),
                cornerRadius: 4
            )
            horizontal.position = CGPoint(x: boardOrigin.x + boardWidth / 2, y: center.y)

            let verticalPath = CGMutablePath()
            let frontPoint = point(for: Cell(column: activation.cell.column, row: 0))
            verticalPath.move(to: CGPoint(x: frontPoint.x - center.x, y: frontPoint.y - center.y))
            for row in 1..<state.board.rowCount {
                let rowPoint = point(for: Cell(column: activation.cell.column, row: row))
                verticalPath.addLine(to: CGPoint(x: rowPoint.x - center.x, y: rowPoint.y - center.y))
            }
            let vertical = SKShapeNode(path: verticalPath)
            vertical.position = center
            vertical.strokeColor = .systemPurple.withAlphaComponent(0.64)
            vertical.lineWidth = max(7, cellWidth * 0.22)
            vertical.lineCap = .round
            vertical.glowWidth = 2

            for beam in [horizontal, vertical] {
                if beam === horizontal {
                    beam.fillColor = .systemPurple.withAlphaComponent(0.64)
                    beam.strokeColor = .white
                    beam.lineWidth = 2
                } else {
                    beam.strokeColor = .systemPurple.withAlphaComponent(0.82)
                }
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
            audio.play(.dance)
            audio.updateMix(danger: dangerFraction, danceActive: true, fadeDuration: 0.22)
            showsDanceParty = true
            renderEnvironmentEffects(danceMode: true)
            configureDancePartyBackdrop()
            reconcileBunnies(with: outcome.boardAfterResolution)
            flashMessage("DANCE PARTY!  2×", color: .systemYellow)
            addConfetti(for: 3)
        } else if outcome.dancePartyEnded {
            audio.updateMix(danger: dangerFraction, danceActive: false, fadeDuration: 0.55)
            showsDanceParty = false
            renderEnvironmentEffects(danceMode: false)
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

    // MARK: - End of Run

    private func showEndStateIfNeeded() {
        guard state.status != .playing else { return }
        if !didPlayEndCue {
            didPlayEndCue = true
            audio.play(state.status == .won ? .win : .lose)
            audio.updateMix(danger: dangerFraction, danceActive: false, fadeDuration: 0.8)
        }
        playtestStats.finish()
        effectLayer.addChild(EndPanel.makeNode(context: EndPanel.Context(
            status: state.status,
            score: state.score,
            stats: EndPanel.RunStats(
                launches: playtestStats.launches,
                falls: playtestStats.falls,
                specialActivations: playtestStats.specialActivations,
                danceParties: playtestStats.danceParties,
                elapsedSeconds: playtestStats.elapsedSeconds
            ),
            hasNextLevel: mode == .classic && hasNextLevel,
            size: size,
            boardCenter: CGPoint(x: boardOrigin.x + boardWidth / 2, y: boardOrigin.y + boardHeight / 2),
            isTablet: isTabletLayout,
            panelScale: isTelevisionLayout ? hudScale : 1
        )))
        if !didReportCompletion {
            didReportCompletion = true
            onRunEnded(state.score)
            if state.status == .won {
                onLevelCompleted(level.id, state.score)
            }
        }
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

    private func pulseLaunchTarget(side: LaunchSide, lane: Int) {
        let position: CGPoint
        let rowScale: CGFloat
        switch side {
        case .left:
            position = point(for: Cell(column: 0, row: lane))
            rowScale = boardProjection.rowWidthScale(for: lane)
        case .right:
            position = point(for: Cell(column: state.board.columnCount - 1, row: lane))
            rowScale = boardProjection.rowWidthScale(for: lane)
        case .bottom:
            position = CGPoint(
                x: point(for: Cell(column: lane, row: 0)).x,
                y: boardOrigin.y - cellHeight * 0.48
            )
            rowScale = 1
        }

        let pulse = SKShapeNode(
            rectOf: CGSize(width: (cellWidth - 2) * rowScale, height: cellHeight - 2),
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
        state = GameState(board: level.startingBoard(), rules: level.rules, mode: mode)
        currentShotIndex = 0
#if os(tvOS)
        selectedSide = .left
        highlightedLane = min(5, state.board.rowCount - 1)
#else
        selectedSide = .bottom
        highlightedLane = nil
#endif
        isAnimating = false
        showsDanceParty = false
        didReportCompletion = false
        didPlayEndCue = false
        playtestStats = PlaytestRunStats()
        partyLayer.removeAllChildren()
        backgroundColor = themeBackgroundColor
        renderAll()
        updateAudioMix()
        flashMessage("READY!", color: .systemGreen)
    }

    private var dangerFraction: Float {
        Float(state.danger) / Float(max(state.rules.dangerLimit, 1))
    }

    private func updateAudioMix() {
        audio.updateMix(danger: dangerFraction, danceActive: state.isDancePartyActive)
    }

#if os(tvOS)
    // MARK: - Television

    private var maximumTelevisionLane: Int {
        selectedSide == .bottom ? state.board.columnCount - 1 : state.board.rowCount - 1
    }

    func handleTelevisionNavigation(_ navigation: TelevisionNavigation) {
        guard !isAnimating else { return }

        let sides: [LaunchSide] = [.left, .bottom, .right]
        var lane = highlightedLane ?? 0
        switch navigation {
        case .previousSide:
            let index = sides.firstIndex(of: selectedSide) ?? 0
            selectedSide = sides[(index + sides.count - 1) % sides.count]
            lane = min(lane, maximumTelevisionLane)
        case .nextSide:
            let index = sides.firstIndex(of: selectedSide) ?? 0
            selectedSide = sides[(index + 1) % sides.count]
            lane = min(lane, maximumTelevisionLane)
        case .previousLane:
            lane = max(0, lane - 1)
        case .nextLane:
            lane = min(maximumTelevisionLane, lane + 1)
        }

        highlightedLane = lane
        drawGrid()
        updateAimReactions()
        drawHUD()
    }

    func handleTelevisionSelect() {
        guard !isAnimating else { return }

        switch state.status {
        case .playing:
            guard let lane = highlightedLane else { return }
            performLaunch(lane: lane)
        case .won:
            if hasNextLevel {
                onRequestNextLevel()
            } else {
                resetGame()
            }
        case .lost:
            resetGame()
        }
    }

    func toggleTelevisionPause() {
        isPaused.toggle()
        audio.setPaused(isPaused)
    }
#endif

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
