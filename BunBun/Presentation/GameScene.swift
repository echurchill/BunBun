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

    private struct LaunchTarget {
        let side: LaunchSide
        let lane: Int
    }

    private let level: LevelDefinition
    private let hasNextLevel: Bool
    private let onLevelCompleted: (LevelID, Int) -> Void
    private let onRequestLevels: () -> Void
    private let onRequestNextLevel: () -> Void
    private let audio = AudioDirector()

    private var state: GameState
    private var currentShotIndex = 0
    private var selectedSide: LaunchSide = .bottom
    private var highlightedLane: Int?
    private var isAnimating = false
    private var showsDebug = false
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
        enforceBunnyDisplaySizes(in: self)
    }

    private func enforceBunnyDisplaySizes(in parent: SKNode) {
        for child in parent.children {
            if let bunny = child as? BunnyNode {
                bunny.enforceDisplaySize()
            } else {
                enforceBunnyDisplaySizes(in: child)
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
            audio.play(.launch)
            end = point(for: cell)
        case .passedThrough:
            audio.play(.launch)
            let rowY = point(for: Cell(column: 0, row: lane)).y
            end = CGPoint(
                x: side == .left ? boardOrigin.x + boardWidth + cellWidth : boardOrigin.x - cellWidth,
                y: rowY
            )
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
            .group([move, .scale(to: 1, duration: duration)]),
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
        updateBunnies(state.board)
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
        updateBunnies(oldBoard)
        let newLocations = Dictionary(uniqueKeysWithValues: newBoard.occupants.map { ($0.value.id, $0.key) })

        for (cell, bunny) in oldBoard.occupants {
            guard let node = bunnyLayer.childNode(withName: "bunny:\(bunny.id.uuidString)") else { continue }
            if let newCell = newLocations[bunny.id] {
                let action = SKAction.move(to: point(for: newCell), duration: duration)
                action.timingMode = .easeInEaseOut
                node.run(action)
            } else if rescuesMissingBunnies, let bunnyNode = node as? BunnyNode {
                animateTubeRescue(bunnyNode, from: cell)
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
                self?.updateBunnies(newBoard, animateEntrants: animatesEntrants)
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
        shade.fillColor = SKColor(white: 0, alpha: backgroundShadeAlpha)
        shade.strokeColor = .clear
        shade.zPosition = -99
        backgroundLayer.addChild(shade)

        configureEnvironmentEffects(danceMode: showsDanceParty)
    }

    private var backgroundShadeAlpha: CGFloat {
        switch level.environment {
        case .desertCamp: isTabletLayout ? 0.31 : 0.27
        case .forestCampDay: isTabletLayout ? 0.30 : 0.26
        case .forestCampNight: isTabletLayout ? 0.16 : 0.12
        case .snowyWoodland: isTabletLayout ? 0.34 : 0.30
        }
    }

    private func configureEnvironmentEffects(danceMode: Bool) {
        ambientLightLayer.removeAllChildren()
        switch level.environment {
        case .desertCamp:
            addDesertDust(danceMode: danceMode)
        case .forestCampDay:
            addFireflies(danceMode: danceMode)
            addCampfire(danceMode: danceMode)
        case .forestCampNight:
            addStarTwinkles(danceMode: danceMode)
            addLanternGlows(danceMode: danceMode)
            addFriendlyTreeEyes(danceMode: danceMode)
            addFireflies(danceMode: danceMode)
            addCampfire(danceMode: danceMode)
        case .snowyWoodland:
            addSnowfall(danceMode: danceMode)
            addWinterSparkles(danceMode: danceMode)
        }
    }

    private func backgroundPoint(x: CGFloat, yFromTop: CGFloat) -> CGPoint {
        CGPoint(
            x: backgroundImageFrame.minX + x * backgroundImageFrame.width,
            y: backgroundImageFrame.maxY - yFromTop * backgroundImageFrame.height
        )
    }

    private func addPulsingGlow(
        at position: CGPoint,
        radius: CGFloat,
        color: SKColor,
        delay: TimeInterval,
        danceMode: Bool
    ) {
        let light = SKShapeNode(circleOfRadius: radius)
        light.position = position
        light.fillColor = color
        light.strokeColor = color.withAlphaComponent(0.42)
        light.lineWidth = 0.8
        light.glowWidth = radius * (danceMode ? 3.4 : 2.3)
        light.blendMode = .add
        light.alpha = 0.08
        ambientLightLayer.addChild(light)
        light.run(.sequence([
            .wait(forDuration: delay),
            .repeatForever(.sequence([
                .group([
                    .fadeAlpha(to: danceMode ? 0.78 : 0.46, duration: danceMode ? 0.20 : 0.55),
                    .scale(to: danceMode ? 1.18 : 1.08, duration: danceMode ? 0.20 : 0.55)
                ]),
                .group([
                    .fadeAlpha(to: danceMode ? 0.18 : 0.10, duration: danceMode ? 0.28 : 0.70),
                    .scale(to: 0.90, duration: danceMode ? 0.28 : 0.70)
                ]),
                .wait(forDuration: danceMode ? 0.06 : 0.30)
            ]))
        ]))
    }

    private func addStarTwinkles(danceMode: Bool) {
        let anchors = [
            CGPoint(x: 0.26, y: 0.91), CGPoint(x: 0.34, y: 0.86),
            CGPoint(x: 0.43, y: 0.94), CGPoint(x: 0.55, y: 0.88),
            CGPoint(x: 0.66, y: 0.93), CGPoint(x: 0.75, y: 0.84),
            CGPoint(x: 0.48, y: 0.80), CGPoint(x: 0.59, y: 0.77)
        ]
        let count = danceMode ? anchors.count : 4
        for (index, point) in anchors.prefix(count).enumerated() {
            addPulsingGlow(
                at: CGPoint(x: point.x * size.width, y: point.y * size.height),
                radius: isTabletLayout ? 2.6 : 1.8,
                color: SKColor(white: 1, alpha: 0.88),
                delay: Double(index) * 0.17,
                danceMode: danceMode
            )
        }
    }

    private func addLanternGlows(danceMode: Bool) {
        let anchors = [
            backgroundPoint(x: 0.064, yFromTop: 0.214),
            backgroundPoint(x: 0.908, yFromTop: 0.115),
            backgroundPoint(x: 0.795, yFromTop: 0.220)
        ]
        for (index, point) in anchors.enumerated()
        where point.x > -20 && point.x < size.width + 20 {
            addPulsingGlow(
                at: point,
                radius: (isTabletLayout ? 7 : 5) + CGFloat(index),
                color: SKColor(red: 1, green: 0.60, blue: 0.16, alpha: 0.72),
                delay: Double(index) * 0.31,
                danceMode: danceMode
            )
        }
    }

    private func addFriendlyTreeEyes(danceMode: Bool) {
        let anchors = [
            CGPoint(x: 0.10, y: 0.69), CGPoint(x: 0.91, y: 0.64),
            CGPoint(x: 0.18, y: 0.79), CGPoint(x: 0.83, y: 0.75)
        ]
        let count = danceMode ? anchors.count : 2
        for (index, anchor) in anchors.prefix(count).enumerated() {
            let pair = SKNode()
            pair.position = CGPoint(x: anchor.x * size.width, y: anchor.y * size.height)
            pair.alpha = 0
            for direction in [-1.0, 1.0] {
                let eye = SKShapeNode(ellipseOf: CGSize(width: 3.2, height: 5.2))
                eye.position.x = CGFloat(direction) * 4.2
                eye.fillColor = SKColor(red: 1, green: 0.70, blue: 0.20, alpha: 0.86)
                eye.strokeColor = .clear
                eye.glowWidth = 3
                pair.addChild(eye)
            }
            ambientLightLayer.addChild(pair)
            pair.run(.sequence([
                .wait(forDuration: 0.9 + Double(index) * 0.7),
                .repeatForever(.sequence([
                    .fadeAlpha(to: danceMode ? 0.82 : 0.50, duration: 0.35),
                    .wait(forDuration: danceMode ? 0.65 : 1.45),
                    .scaleY(to: 0.08, duration: 0.08),
                    .scaleY(to: 1, duration: 0.10),
                    .wait(forDuration: danceMode ? 0.45 : 1.6),
                    .fadeOut(withDuration: 0.45),
                    .wait(forDuration: danceMode ? 0.6 : 2.2)
                ]))
            ]))
        }
    }

    private func addFireflies(danceMode: Bool) {
        let count = danceMode ? 14 : 7
        for index in 0..<count {
            let x = CGFloat((index * 37 + 18) % 88 + 6) / 100
            let y = CGFloat((index * 23 + 31) % 42 + 33) / 100
            let radius: CGFloat = isTabletLayout ? 3.2 : 2.2
            let firefly = SKShapeNode(circleOfRadius: radius)
            firefly.position = CGPoint(x: x * size.width, y: y * size.height)
            firefly.fillColor = SKColor(red: 0.92, green: 1, blue: 0.30, alpha: 0.86)
            firefly.strokeColor = SKColor(white: 1, alpha: 0.38)
            firefly.lineWidth = 0.7
            firefly.glowWidth = radius * (danceMode ? 3.4 : 2.4)
            firefly.blendMode = .add
            firefly.alpha = 0.08
            ambientLightLayer.addChild(firefly)

            let bright: CGFloat = danceMode ? 0.84 : 0.54
            let dim: CGFloat = danceMode ? 0.18 : 0.10
            let blinkDuration = danceMode ? 0.12 : 0.24
            let flicker = SKAction.repeat(.sequence([
                .fadeAlpha(to: bright, duration: blinkDuration),
                .fadeAlpha(to: dim, duration: blinkDuration * 1.25)
            ]), count: 2 + index % 2)
            let dx = CGFloat((index % 3) - 1) * (danceMode ? 24 : 15)
                + CGFloat(index % 2 == 0 ? 7 : -7)
            let dy = CGFloat(index % 2 == 0 ? 1 : -1) * (danceMode ? 17 : 10)
            let secondDX = CGFloat(index % 2 == 0 ? -18 : 18)
            let secondDY = CGFloat(index % 3 - 1) * (danceMode ? 13 : 8)
            let moveDuration = danceMode ? 0.42 : 0.78
            let relocate = { (x: CGFloat, y: CGFloat) in
                SKAction.group([
                    .moveBy(x: x, y: y, duration: moveDuration),
                    .fadeAlpha(to: 0.06, duration: moveDuration * 0.45)
                ])
            }
            firefly.run(.sequence([
                .wait(forDuration: Double(index % 5) * 0.16),
                .repeatForever(.sequence([
                    flicker,
                    relocate(dx, dy),
                    flicker,
                    relocate(secondDX, secondDY),
                    flicker,
                    relocate(-dx - secondDX, -dy - secondDY),
                    .wait(forDuration: danceMode ? 0.08 : 0.35)
                ]))
            ]))
        }
    }

    private func addCampfire(danceMode: Bool) {
        let fire = SKNode()
        fire.position = backgroundPoint(x: 0.755, yFromTop: 0.245)
        fire.setScale(isTabletLayout ? 1.45 : 1)

        for angle in [-0.34, 0.34] {
            let log = SKShapeNode(rectOf: CGSize(width: 30, height: 6), cornerRadius: 3)
            log.zRotation = angle
            log.fillColor = SKColor(red: 0.24, green: 0.10, blue: 0.04, alpha: 0.95)
            log.strokeColor = SKColor(red: 0.55, green: 0.25, blue: 0.08, alpha: 0.9)
            fire.addChild(log)
        }
        let glow = SKShapeNode(circleOfRadius: danceMode ? 25 : 19)
        glow.fillColor = SKColor(red: 1, green: 0.30, blue: 0.04, alpha: 0.12)
        glow.strokeColor = .clear
        glow.glowWidth = 16
        glow.blendMode = .add
        glow.zPosition = -1
        fire.addChild(glow)
        for (index, spec) in [(22.0, SKColor.systemOrange), (14.0, SKColor.systemYellow)].enumerated() {
            let flame = SKShapeNode(ellipseOf: CGSize(width: CGFloat(spec.0) * 0.72, height: CGFloat(spec.0)))
            flame.position.y = CGFloat(8 + index * 2)
            flame.fillColor = spec.1.withAlphaComponent(0.88)
            flame.strokeColor = .clear
            flame.blendMode = .add
            fire.addChild(flame)
            flame.run(.repeatForever(.sequence([
                .group([.scaleX(to: 0.74, duration: 0.16), .scaleY(to: 1.13, duration: 0.16)]),
                .group([.scaleX(to: 1.08, duration: 0.20), .scaleY(to: 0.88, duration: 0.20)])
            ])))
        }
        ambientLightLayer.addChild(fire)

        for index in 0..<(danceMode ? 5 : 3) {
            let smoke = SKShapeNode(circleOfRadius: CGFloat(5 + index % 2 * 2))
            smoke.position = CGPoint(
                x: fire.position.x + CGFloat(index - 2) * 3 * fire.xScale,
                y: fire.position.y + 28 * fire.yScale
            )
            smoke.fillColor = SKColor(white: 0.76, alpha: 0.20)
            smoke.strokeColor = .clear
            ambientLightLayer.addChild(smoke)
            let rise = CGFloat(42 + index * 7)
            smoke.run(.sequence([
                .wait(forDuration: Double(index) * 0.32),
                .repeatForever(.sequence([
                    .group([
                        .moveBy(x: CGFloat(index % 2 == 0 ? -8 : 8), y: rise, duration: danceMode ? 1.15 : 1.8),
                        .fadeOut(withDuration: danceMode ? 1.15 : 1.8),
                        .scale(to: 1.8, duration: danceMode ? 1.15 : 1.8)
                    ]),
                    .moveBy(x: CGFloat(index % 2 == 0 ? 8 : -8), y: -rise, duration: 0),
                    .scale(to: 1, duration: 0),
                    .fadeAlpha(to: 0.20, duration: 0)
                ]))
            ]))
        }
    }

    private func addDesertDust(danceMode: Bool) {
        let count = danceMode ? 12 : 6
        for index in 0..<count {
            let mote = SKShapeNode(circleOfRadius: CGFloat(1 + index % 3))
            mote.position = CGPoint(
                x: CGFloat((index * 53 + 21) % 94 + 3) / 100 * size.width,
                y: CGFloat((index * 29 + 18) % 54 + 22) / 100 * size.height
            )
            mote.fillColor = SKColor(red: 1, green: 0.78, blue: 0.42, alpha: 0.24)
            mote.strokeColor = .clear
            ambientLightLayer.addChild(mote)
            let travel = danceMode ? size.width * 0.13 : size.width * 0.07
            mote.run(.repeatForever(.sequence([
                .group([.moveBy(x: travel, y: 5, duration: danceMode ? 0.9 : 1.8), .fadeAlpha(to: 0.48, duration: 0.5)]),
                .group([.moveBy(x: -travel, y: -5, duration: danceMode ? 1.0 : 2.0), .fadeAlpha(to: 0.12, duration: 0.7)])
            ])))
        }
    }

    private func addSnowfall(danceMode: Bool) {
        let count = danceMode ? 22 : 11
        for index in 0..<count {
            let flake = SKShapeNode(circleOfRadius: CGFloat(1 + index % 3))
            flake.position = CGPoint(
                x: CGFloat((index * 47 + 13) % 96 + 2) / 100 * size.width,
                y: CGFloat((index * 31 + 20) % 68 + 26) / 100 * size.height
            )
            flake.fillColor = SKColor(white: 1, alpha: 0.46)
            flake.strokeColor = .clear
            ambientLightLayer.addChild(flake)
            let fall = danceMode ? size.height * 0.08 : size.height * 0.05
            flake.run(.repeatForever(.sequence([
                .moveBy(x: CGFloat(index % 2 == 0 ? 9 : -9), y: -fall, duration: danceMode ? 0.8 : 1.6),
                .moveBy(x: CGFloat(index % 2 == 0 ? -9 : 9), y: fall, duration: 0)
            ])))
        }
    }

    private func addWinterSparkles(danceMode: Bool) {
        let anchors = [
            CGPoint(x: 0.08, y: 0.74), CGPoint(x: 0.18, y: 0.85),
            CGPoint(x: 0.82, y: 0.82), CGPoint(x: 0.93, y: 0.70),
            CGPoint(x: 0.33, y: 0.91), CGPoint(x: 0.69, y: 0.92)
        ]
        for (index, anchor) in anchors.prefix(danceMode ? anchors.count : 3).enumerated() {
            addPulsingGlow(
                at: CGPoint(x: anchor.x * size.width, y: anchor.y * size.height),
                radius: isTabletLayout ? 3.5 : 2.5,
                color: SKColor(red: 0.68, green: 0.91, blue: 1, alpha: 0.76),
                delay: Double(index) * 0.24,
                danceMode: danceMode
            )
        }
    }

    private func layoutBoard() {
        let horizontalPadding: CGFloat
        let maximumCellWidth: CGFloat
        let boardHeightFraction: CGFloat
        if isTelevisionLayout {
            horizontalPadding = max(180, size.width * 0.17)
            maximumCellWidth = 76
            boardHeightFraction = 0.54
        } else if isTabletLayout {
            horizontalPadding = max(54, size.width * 0.08)
            maximumCellWidth = 64
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

        let controlInset: CGFloat = isTelevisionLayout ? 150 : (isTabletLayout ? 90 : 58)
        addControl(name: "debug", text: showsDebug ? "DEBUG ON" : "DEBUG", x: controlInset)
        addControl(name: "restart", text: "RESTART", x: size.width - controlInset)

        let preferredMeterWidth: CGFloat = isTelevisionLayout ? 230 : (isTabletLayout ? 150 : 92)
        let meterWidth = min(preferredMeterWidth, (size.width - 48) / 3)
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
        let previewY = isLargeScreenLayout ? max(72, boardOrigin.y - cellHeight * 1.6) : 69
        let previewOffset: CGFloat = isTelevisionLayout ? 150 : (isTabletLayout ? 95 : 75)
        preview.position = CGPoint(x: size.width / 2 - previewOffset, y: previewY)
        preview.setScale(isTelevisionLayout ? 1.35 : (isTabletLayout ? 1.05 : 0.82))
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

#if os(tvOS)
        let remoteHelp = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        remoteHelp.text = "◀︎ ▶︎ SIDE    ▲ ▼ LANE    SELECT LAUNCH    PLAY/PAUSE PAUSE    MENU LEVELS"
        remoteHelp.fontSize = 12 * hudScale
        remoteHelp.fontColor = SKColor(white: 0.86, alpha: 0.92)
        remoteHelp.position = CGPoint(x: size.width / 2, y: 42)
        hudLayer.addChild(remoteHelp)

        let selection = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        selection.text = "\(selectedSide.rawValue.uppercased())  •  LANE \((highlightedLane ?? 0) + 1)"
        selection.fontSize = 13 * hudScale
        selection.fontColor = .systemYellow
        selection.position = CGPoint(x: size.width / 2, y: 75)
        hudLayer.addChild(selection)
#endif

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

        // Game-state meters are bounded, but clamp at the presentation boundary
        // as well so malformed/debug state can never draw outside its track.
        let fraction = min(
            1,
            max(0, CGFloat(value) / CGFloat(max(maximumValue, 1)))
        )
        let fillWidth = width * fraction
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
            node.zPosition = isDestination ? 12 : 2
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
            audio.play(.dance)
            audio.updateMix(danger: dangerFraction, danceActive: true, fadeDuration: 0.22)
            showsDanceParty = true
            configureEnvironmentEffects(danceMode: true)
            configureDancePartyBackdrop()
            updateBunnies(outcome.boardAfterResolution)
            flashMessage("DANCE PARTY!  2×", color: .systemYellow)
            addConfetti(for: 3)
        } else if outcome.dancePartyEnded {
            audio.updateMix(danger: dangerFraction, danceActive: false, fadeDuration: 0.55)
            showsDanceParty = false
            configureEnvironmentEffects(danceMode: false)
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
        if !didPlayEndCue {
            didPlayEndCue = true
            audio.play(state.status == .won ? .win : .lose)
            audio.updateMix(danger: dangerFraction, danceActive: false, fadeDuration: 0.8)
        }
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
