import SpriteKit

/// Builds the ambient environment effects (desert dust, stars, lantern glow,
/// tree eyes, fireflies, campfire, snowfall, ice sparkles) that live on the
/// scene's ambient-light layer.
///
/// Pure builder: the caller owns the layer and passes a snapshot of
/// everything the effects need, so this type holds no scene state and every
/// configuration is reproducible from its context alone.
@MainActor
enum SceneEnvironment {
    struct Context {
        let size: CGSize
        let environment: LevelEnvironment
        let backgroundFrame: CGRect
        let isTablet: Bool
        let danceMode: Bool
    }

    nonisolated static func shadeAlpha(for environment: LevelEnvironment, isTablet: Bool) -> CGFloat {
        switch environment {
        case .desertCamp: isTablet ? 0.31 : 0.27
        case .forestCampDay: isTablet ? 0.30 : 0.26
        case .forestCampNight: isTablet ? 0.16 : 0.12
        case .snowyWoodland: isTablet ? 0.34 : 0.30
        }
    }

    static func configure(_ layer: SKNode, context: Context) {
        layer.removeAllChildren()
        switch context.environment {
        case .desertCamp:
            addDesertDust(to: layer, context: context)
        case .forestCampDay:
            addFireflies(to: layer, context: context)
            addCampfire(to: layer, context: context)
        case .forestCampNight:
            addStarTwinkles(to: layer, context: context)
            addLanternGlows(to: layer, context: context)
            addFriendlyTreeEyes(to: layer, context: context)
            addFireflies(to: layer, context: context)
            addCampfire(to: layer, context: context)
        case .snowyWoodland:
            addSnowfall(to: layer, context: context)
            addWinterSparkles(to: layer, context: context)
        }
    }

    private static func backgroundPoint(x: CGFloat, yFromTop: CGFloat, in frame: CGRect) -> CGPoint {
        CGPoint(
            x: frame.minX + x * frame.width,
            y: frame.maxY - yFromTop * frame.height
        )
    }

    private static func addPulsingGlow(
        to layer: SKNode,
        at position: CGPoint,
        radius: CGFloat,
        color: SKColor,
        delay: TimeInterval,
        context: Context
    ) {
        let danceMode = context.danceMode
        let light = SKShapeNode(circleOfRadius: radius)
        light.position = position
        light.fillColor = color
        light.strokeColor = color.withAlphaComponent(0.42)
        light.lineWidth = 0.8
        light.glowWidth = radius * (danceMode ? 3.4 : 2.3)
        light.blendMode = .add
        light.alpha = 0.08
        layer.addChild(light)
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

    private static func addStarTwinkles(to layer: SKNode, context: Context) {
        let anchors = [
            CGPoint(x: 0.26, y: 0.91), CGPoint(x: 0.34, y: 0.86),
            CGPoint(x: 0.43, y: 0.94), CGPoint(x: 0.55, y: 0.88),
            CGPoint(x: 0.66, y: 0.93), CGPoint(x: 0.75, y: 0.84),
            CGPoint(x: 0.48, y: 0.80), CGPoint(x: 0.59, y: 0.77)
        ]
        let count = context.danceMode ? anchors.count : 4
        for (index, point) in anchors.prefix(count).enumerated() {
            addPulsingGlow(
                to: layer,
                at: CGPoint(x: point.x * context.size.width, y: point.y * context.size.height),
                radius: context.isTablet ? 2.6 : 1.8,
                color: SKColor(white: 1, alpha: 0.88),
                delay: Double(index) * 0.17,
                context: context
            )
        }
    }

    private static func addLanternGlows(to layer: SKNode, context: Context) {
        let anchors = [
            backgroundPoint(x: 0.064, yFromTop: 0.214, in: context.backgroundFrame),
            backgroundPoint(x: 0.908, yFromTop: 0.115, in: context.backgroundFrame),
            backgroundPoint(x: 0.795, yFromTop: 0.220, in: context.backgroundFrame)
        ]
        for (index, point) in anchors.enumerated()
        where point.x > -20 && point.x < context.size.width + 20 {
            addPulsingGlow(
                to: layer,
                at: point,
                radius: (context.isTablet ? 7 : 5) + CGFloat(index),
                color: SKColor(red: 1, green: 0.60, blue: 0.16, alpha: 0.72),
                delay: Double(index) * 0.31,
                context: context
            )
        }
    }

    private static func addFriendlyTreeEyes(to layer: SKNode, context: Context) {
        let danceMode = context.danceMode
        let anchors = [
            CGPoint(x: 0.10, y: 0.69), CGPoint(x: 0.91, y: 0.64),
            CGPoint(x: 0.18, y: 0.79), CGPoint(x: 0.83, y: 0.75)
        ]
        let count = danceMode ? anchors.count : 2
        for (index, anchor) in anchors.prefix(count).enumerated() {
            let pair = SKNode()
            pair.position = CGPoint(x: anchor.x * context.size.width, y: anchor.y * context.size.height)
            pair.alpha = 0
            for direction in [-1.0, 1.0] {
                let eye = SKShapeNode(ellipseOf: CGSize(width: 3.2, height: 5.2))
                eye.position.x = CGFloat(direction) * 4.2
                eye.fillColor = SKColor(red: 1, green: 0.70, blue: 0.20, alpha: 0.86)
                eye.strokeColor = .clear
                eye.glowWidth = 3
                pair.addChild(eye)
            }
            layer.addChild(pair)
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

    private static func addFireflies(to layer: SKNode, context: Context) {
        let danceMode = context.danceMode
        let count = danceMode ? 14 : 7
        for index in 0..<count {
            let x = CGFloat((index * 37 + 18) % 88 + 6) / 100
            let y = CGFloat((index * 23 + 31) % 42 + 33) / 100
            let radius: CGFloat = context.isTablet ? 3.2 : 2.2
            let firefly = SKShapeNode(circleOfRadius: radius)
            firefly.position = CGPoint(x: x * context.size.width, y: y * context.size.height)
            firefly.fillColor = SKColor(red: 0.92, green: 1, blue: 0.30, alpha: 0.86)
            firefly.strokeColor = SKColor(white: 1, alpha: 0.38)
            firefly.lineWidth = 0.7
            firefly.glowWidth = radius * (danceMode ? 3.4 : 2.4)
            firefly.blendMode = .add
            firefly.alpha = 0.08
            layer.addChild(firefly)

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

    private static func addCampfire(to layer: SKNode, context: Context) {
        let danceMode = context.danceMode
        let fire = SKNode()
        fire.position = backgroundPoint(x: 0.755, yFromTop: 0.245, in: context.backgroundFrame)
        fire.setScale(context.isTablet ? 1.45 : 1)

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
        layer.addChild(fire)

        for index in 0..<(danceMode ? 5 : 3) {
            let smoke = SKShapeNode(circleOfRadius: CGFloat(5 + index % 2 * 2))
            smoke.position = CGPoint(
                x: fire.position.x + CGFloat(index - 2) * 3 * fire.xScale,
                y: fire.position.y + 28 * fire.yScale
            )
            smoke.fillColor = SKColor(white: 0.76, alpha: 0.20)
            smoke.strokeColor = .clear
            layer.addChild(smoke)
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

    private static func addDesertDust(to layer: SKNode, context: Context) {
        let danceMode = context.danceMode
        let count = danceMode ? 12 : 6
        for index in 0..<count {
            let mote = SKShapeNode(circleOfRadius: CGFloat(1 + index % 3))
            mote.position = CGPoint(
                x: CGFloat((index * 53 + 21) % 94 + 3) / 100 * context.size.width,
                y: CGFloat((index * 29 + 18) % 54 + 22) / 100 * context.size.height
            )
            mote.fillColor = SKColor(red: 1, green: 0.78, blue: 0.42, alpha: 0.24)
            mote.strokeColor = .clear
            layer.addChild(mote)
            let travel = danceMode ? context.size.width * 0.13 : context.size.width * 0.07
            mote.run(.repeatForever(.sequence([
                .group([.moveBy(x: travel, y: 5, duration: danceMode ? 0.9 : 1.8), .fadeAlpha(to: 0.48, duration: 0.5)]),
                .group([.moveBy(x: -travel, y: -5, duration: danceMode ? 1.0 : 2.0), .fadeAlpha(to: 0.12, duration: 0.7)])
            ])))
        }
    }

    private static func addSnowfall(to layer: SKNode, context: Context) {
        let danceMode = context.danceMode
        let count = danceMode ? 22 : 11
        for index in 0..<count {
            let flake = SKShapeNode(circleOfRadius: CGFloat(1 + index % 3))
            flake.position = CGPoint(
                x: CGFloat((index * 47 + 13) % 96 + 2) / 100 * context.size.width,
                y: CGFloat((index * 31 + 20) % 68 + 26) / 100 * context.size.height
            )
            flake.fillColor = SKColor(white: 1, alpha: 0.46)
            flake.strokeColor = .clear
            layer.addChild(flake)
            let fall = danceMode ? context.size.height * 0.08 : context.size.height * 0.05
            flake.run(.repeatForever(.sequence([
                .moveBy(x: CGFloat(index % 2 == 0 ? 9 : -9), y: -fall, duration: danceMode ? 0.8 : 1.6),
                .moveBy(x: CGFloat(index % 2 == 0 ? -9 : 9), y: fall, duration: 0)
            ])))
        }
    }

    private static func addWinterSparkles(to layer: SKNode, context: Context) {
        let anchors = [
            CGPoint(x: 0.08, y: 0.74), CGPoint(x: 0.18, y: 0.85),
            CGPoint(x: 0.82, y: 0.82), CGPoint(x: 0.93, y: 0.70),
            CGPoint(x: 0.33, y: 0.91), CGPoint(x: 0.69, y: 0.92)
        ]
        for (index, anchor) in anchors.prefix(context.danceMode ? anchors.count : 3).enumerated() {
            addPulsingGlow(
                to: layer,
                at: CGPoint(x: anchor.x * context.size.width, y: anchor.y * context.size.height),
                radius: context.isTablet ? 3.5 : 2.5,
                color: SKColor(red: 0.68, green: 0.91, blue: 1, alpha: 0.76),
                delay: Double(index) * 0.24,
                context: context
            )
        }
    }
}
