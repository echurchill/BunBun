import CoreImage
import SpriteKit
import UIKit

private enum BunnyMotion: String {
    case idle = "BunnyIdleSheet"
    case aim = "BunnyAimSheet"
    case celebration = "BunnyCelebrateSheet"
    case advance = "BunnyAdvanceSheet"
    case dance = "BunnyDanceSheet"
    case danceTwoStep = "BunnyDanceTwoStepSheet"
    case danceHop = "BunnyDanceHopSheet"
    case bomb = "BunnyBombSheet"
    case line = "BunnyLineSheet"
    case rescue = "BunnyRescueSheet"
}

/// Splits the generated 4x2 sheets and hue-shifts the blue master art so every
/// gameplay color keeps the same silhouette, lighting, eyes, and animation.
@MainActor
private final class BunnyAnimationLibrary {
    private final class TextureSet: NSObject {
        let textures: [SKTexture]

        init(_ textures: [SKTexture]) {
            self.textures = textures
        }
    }

    static let shared = BunnyAnimationLibrary()

    private let context = CIContext(options: [.cacheIntermediates: false])
    private let cache: NSCache<NSString, TextureSet> = {
        let cache = NSCache<NSString, TextureSet>()
        // Keep the six idle colors plus a handful of current action sets, but
        // allow old motions to be regenerated instead of retaining hundreds
        // of full-resolution frames for the life of the process.
        cache.countLimit = 14
        cache.totalCostLimit = 80 * 1_024 * 1_024
        return cache
    }()

    func textures(for motion: BunnyMotion, color: BunnyColor) -> [SKTexture] {
        let key = "\(motion.rawValue):\(color.rawValue)"
        if let cached = cache.object(forKey: key as NSString) {
            return cached.textures
        }

        guard let source = UIImage(named: motion.rawValue)?.cgImage else {
            return []
        }

        let textures = (0..<8).compactMap { index -> SKTexture? in
            let column = index % 4
            let row = index / 4
            let x0 = Int((Double(source.width) * Double(column) / 4.0).rounded())
            let x1 = Int((Double(source.width) * Double(column + 1) / 4.0).rounded())
            let y0 = Int((Double(source.height) * Double(row) / 2.0).rounded())
            let y1 = Int((Double(source.height) * Double(row + 1) / 2.0).rounded())
            let rect = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
            guard let frame = source.cropping(to: rect) else { return nil }

            let output: CGImage
            if color == .blue {
                output = frame
            } else {
                let input = CIImage(cgImage: frame)
                let filter = CIFilter(name: "CIHueAdjust")
                filter?.setValue(input, forKey: kCIInputImageKey)
                filter?.setValue(hueAngle(for: color), forKey: kCIInputAngleKey)
                guard let result = filter?.outputImage,
                      let shifted = context.createCGImage(result, from: input.extent) else {
                    return nil
                }
                output = shifted
            }

            let texture = SKTexture(cgImage: output)
            texture.filteringMode = .linear
            return texture
        }

        let approximateBytes = textures.count
            * max(source.width / 4, 1)
            * max(source.height / 2, 1)
            * 4
        cache.setObject(TextureSet(textures), forKey: key as NSString, cost: approximateBytes)
        return textures
    }

    private func hueAngle(for color: BunnyColor) -> CGFloat {
        switch color {
        case .blue: 0
        case .green: -1.30
        case .orange: -2.95
        case .pink: 2.10
        case .purple: 1.15
        case .red: 2.62
        }
    }
}

/// Presentation-only bunny. The rules layer never sees this type, so richer
/// sprite sheets or a 3D character can replace it without changing game rules.
@MainActor
final class BunnyNode: SKNode {
    let bunnyID: UUID

    private let bunnyColor: BunnyColor
    private let bunnyKind: BunnyKind
    private var sprite: SKSpriteNode?
    private weak var specialBadge: SKNode?
    private let cellWidth: CGFloat
    private let cellHeight: CGFloat
    private let animationSeed: Int
    private var spriteDisplaySize = CGSize.zero
    private var isAiming = false
    private var isDancing = false
    private var isPerformingOneShot = false

    init(bunny: Bunny, cellWidth: CGFloat, cellHeight: CGFloat, color: SKColor) {
        bunnyID = bunny.id
        bunnyColor = bunny.color
        bunnyKind = bunny.kind
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        animationSeed = bunny.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        super.init()
        name = "bunny:\(bunny.id.uuidString)"

        let bodyWidth = cellWidth * 0.66
        let bodyHeight = cellHeight * 0.63

        let idleTextures = BunnyAnimationLibrary.shared.textures(for: .idle, color: bunny.color)
        if let firstTexture = idleTextures.first {
            let displaySize = CGSize(
                width: cellWidth * (1.05 + CGFloat(animationSeed % 3) * 0.025),
                height: cellHeight * (1.05 + CGFloat(animationSeed % 3) * 0.025)
            )
            let sprite = SKSpriteNode(
                texture: firstTexture,
                size: displaySize
            )
            spriteDisplaySize = displaySize
            sprite.position.y = cellHeight * 0.04
            sprite.zPosition = 0
            addChild(sprite)
            self.sprite = sprite
            playIdle()
        } else {
            addPlaceholder(color: color, bodyWidth: bodyWidth, bodyHeight: bodyHeight)
        }

        addSpecialMarker(for: bunny.kind, bodyWidth: bodyWidth, bodyHeight: bodyHeight)
    }

    func setAiming(_ aiming: Bool) {
        guard aiming != isAiming else { return }
        isAiming = aiming
        guard !isDancing, !isPerformingOneShot else { return }

        if aiming {
            _ = play(.aim, timePerFrame: 0.135, repeats: true)
        } else {
            playIdle()
        }
    }

    /// Final render-pass safety net for SpriteKit texture actions. The scene
    /// calls this after actions have been evaluated so no generated sheet can
    /// reach the renderer at its native pixel dimensions.
    func enforceDisplaySize() {
        guard let sprite, sprite.size != spriteDisplaySize else { return }
        sprite.size = spriteDisplaySize
    }

    func playCelebration(chainDepth: Int) {
        isPerformingOneShot = true
        let speed = max(0.042, 0.068 - Double(chainDepth - 1) * 0.008)
        guard play(.celebration, timePerFrame: speed, repeats: false) else {
            run(.sequence([
                .scaleY(to: 0.84, duration: 0.08),
                .scaleY(to: 1.18, duration: 0.12),
                .scaleY(to: 1, duration: 0.12)
            ]))
            return
        }

        guard chainDepth > 1 else { return }
        let emphasis = min(1.10 + CGFloat(chainDepth) * 0.05, 1.35)
        run(.sequence([
            .scale(to: emphasis, duration: 0.12),
            .rotate(toAngle: chainDepth.isMultiple(of: 2) ? -0.08 : 0.08, duration: 0.08),
            .rotate(toAngle: 0, duration: 0.08),
            .scale(to: 1, duration: 0.12)
        ]), withKey: "chainEmphasis")
    }

    func playAdvanceReaction() {
        isPerformingOneShot = true
        guard play(.advance, timePerFrame: 0.07, repeats: false) else {
            run(.sequence([
                .scaleY(to: 0.82, duration: 0.14),
                .scaleY(to: 1, duration: 0.18)
            ]))
            return
        }
    }

    func playSpecialAnticipation() {
        let motion: BunnyMotion
        switch bunnyKind {
        case .normal:
            return
        case .redBomb:
            motion = .bomb
            specialBadge?.run(.repeat(.sequence([
                .scale(to: 1.35, duration: 0.08),
                .scale(to: 0.88, duration: 0.08)
            ]), count: 3))
        case .lineClear:
            motion = .line
            specialBadge?.run(.sequence([
                .rotate(toAngle: .pi / 4, duration: 0.12, shortestUnitArc: true),
                .scale(to: 1.35, duration: 0.10),
                .scale(to: 1, duration: 0.08),
                .rotate(toAngle: 0, duration: 0.12, shortestUnitArc: true)
            ]))
        }

        isPerformingOneShot = true
        _ = play(motion, timePerFrame: 0.055, repeats: false)
    }

    func playRescue() {
        isPerformingOneShot = true
        _ = play(.rescue, timePerFrame: 0.07, repeats: false)
    }

    func setDancing(_ dancing: Bool) {
        isDancing = dancing
        removeAction(forKey: "fallbackDance")
        zRotation = 0

        let danceMotion: BunnyMotion = switch animationSeed % 3 {
        case 0: .dance
        case 1: .danceTwoStep
        default: .danceHop
        }
        let danceDelay = Double(animationSeed % 7) * 0.045
        if dancing, play(
            danceMotion,
            timePerFrame: 0.115,
            repeats: true,
            initialDelay: danceDelay
        ) {
            return
        }
        if sprite != nil {
            playIdle()
            return
        }
        guard dancing else { return }

        let sway = SKAction.sequence([
            .rotate(toAngle: -0.09, duration: 0.12, shortestUnitArc: true),
            .rotate(toAngle: 0.09, duration: 0.20, shortestUnitArc: true),
            .rotate(toAngle: 0, duration: 0.12, shortestUnitArc: true),
            .scaleY(to: 0.88, duration: 0.08),
            .scaleY(to: 1.08, duration: 0.10),
            .scaleY(to: 1, duration: 0.08)
        ])
        run(.repeatForever(sway), withKey: "fallbackDance")
    }

    private func playIdle() {
        guard let sprite else { return }
        let textures = BunnyAnimationLibrary.shared.textures(for: .idle, color: bunnyColor)
        guard !textures.isEmpty else { return }

        sprite.removeAction(forKey: "textureAnimation")
        // Boogie Bunnies held readable poses between short gestures. Divide the
        // crowd into five stable cohorts so only about one fifth is moving at
        // once, then return every bunny to the neutral first frame.
        let idleSpeed = [0.125, 0.132, 0.138][animationSeed % 3]
        let gestureDuration = idleSpeed * Double(textures.count)
        let cohortSlot: TimeInterval = 1.15
        let cycleDuration = cohortSlot * 5
        let cohort = animationSeed % 5
        let personalityOffset = Double((animationSeed / 5) % 4) * 0.035
        let initialDelay = Double(cohort) * cohortSlot + personalityOffset
        let restDuration = max(0.2, cycleDuration - gestureDuration)
        let gesture = fixedSizeAnimation(
            textures: textures,
            timePerFrame: idleSpeed,
            on: sprite
        )
        let cadence = SKAction.repeatForever(.sequence([
            gesture,
            textureFrameAction(textures[0], on: sprite),
            .wait(forDuration: restDuration)
        ]))
        sprite.run(
            .sequence([.wait(forDuration: initialDelay), cadence]),
            withKey: "textureAnimation"
        )
    }

    @discardableResult
    private func play(
        _ motion: BunnyMotion,
        timePerFrame: TimeInterval,
        repeats: Bool,
        initialDelay: TimeInterval = 0
    ) -> Bool {
        guard let sprite else { return false }
        let textures = BunnyAnimationLibrary.shared.textures(for: motion, color: bunnyColor)
        guard !textures.isEmpty else { return false }

        sprite.removeAction(forKey: "textureAnimation")
        let animation = fixedSizeAnimation(
            textures: textures,
            timePerFrame: timePerFrame,
            on: sprite
        )
        if repeats {
            sprite.run(
                .sequence([
                    .wait(forDuration: initialDelay),
                    .repeatForever(animation)
                ]),
                withKey: "textureAnimation"
            )
        } else {
            sprite.run(.sequence([
                animation,
                .run { [weak self] in
                    self?.isPerformingOneShot = false
                    self?.resumeAmbientMotion()
                }
            ]), withKey: "textureAnimation")
        }
        return true
    }

    /// SpriteKit 27 can resize a sprite to a generated texture's native pixel
    /// dimensions while advancing an `SKAction.setTexture` animation, even when
    /// that action's resize flag is false. Worse, interrupting the action while
    /// changing from idle to celebration can strand the sprite at that enormous
    /// source size. Assigning the texture and display size inside one run block
    /// makes the frame change atomic from the scene's point of view.
    private func fixedSizeAnimation(
        textures: [SKTexture],
        timePerFrame: TimeInterval,
        on sprite: SKSpriteNode
    ) -> SKAction {
        let frames = textures.map { texture in
            SKAction.sequence([
                textureFrameAction(texture, on: sprite),
                .wait(forDuration: timePerFrame)
            ])
        }
        return .sequence(frames)
    }

    private func textureFrameAction(_ texture: SKTexture, on sprite: SKSpriteNode) -> SKAction {
        let displaySize = spriteDisplaySize
        return .run { [weak sprite] in
            sprite?.texture = texture
            sprite?.size = displaySize
        }
    }

    private func resumeAmbientMotion() {
        if isDancing {
            setDancing(true)
        } else if isAiming {
            _ = play(.aim, timePerFrame: 0.135, repeats: true)
        } else {
            playIdle()
        }
    }

    private func addPlaceholder(color: SKColor, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        let body = SKShapeNode(ellipseOf: CGSize(width: bodyWidth, height: bodyHeight))
        body.position.y = -cellHeight * 0.06
        body.fillColor = color
        body.strokeColor = .white.withAlphaComponent(0.72)
        body.lineWidth = 1.4
        addChild(body)

        let earSize = CGSize(width: bodyWidth * 0.27, height: cellHeight * 0.34)
        for direction: CGFloat in [-1, 1] {
            let ear = SKShapeNode(ellipseOf: earSize)
            ear.position = CGPoint(x: direction * bodyWidth * 0.22, y: bodyHeight * 0.38)
            ear.zRotation = direction * -0.10
            ear.fillColor = color
            ear.strokeColor = .white.withAlphaComponent(0.72)
            ear.lineWidth = 1.2
            ear.zPosition = -1
            addChild(ear)
        }

        let eyeRadius = max(1.2, cellWidth * 0.045)
        for direction: CGFloat in [-1, 1] {
            let eye = SKShapeNode(circleOfRadius: eyeRadius)
            eye.position = CGPoint(x: direction * bodyWidth * 0.16, y: body.position.y + bodyHeight * 0.08)
            eye.fillColor = SKColor(white: 0.08, alpha: 0.9)
            eye.strokeColor = .clear
            eye.zPosition = 2
            addChild(eye)
        }
    }

    private func addSpecialMarker(for kind: BunnyKind, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        guard kind != .normal else { return }

        let badge = SKShapeNode(circleOfRadius: bodyWidth * 0.18)
        badge.position = CGPoint(x: 0, y: -bodyHeight * 0.13)
        badge.fillColor = SKColor(white: 0.08, alpha: 0.82)
        badge.strokeColor = .white
        badge.lineWidth = 1.2
        badge.zPosition = 3
        addChild(badge)
        specialBadge = badge

        let symbol = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        symbol.text = kind == .redBomb ? "✹" : "✚"
        symbol.fontSize = bodyWidth * 0.28
        symbol.fontColor = kind == .redBomb ? .systemYellow : .white
        symbol.verticalAlignmentMode = .center
        symbol.horizontalAlignmentMode = .center
        symbol.position.y = -1
        badge.addChild(symbol)

        if kind == .redBomb {
            let fusePath = CGMutablePath()
            fusePath.move(to: CGPoint(x: bodyWidth * 0.20, y: bodyHeight * 0.25))
            fusePath.addCurve(
                to: CGPoint(x: bodyWidth * 0.31, y: bodyHeight * 0.49),
                control1: CGPoint(x: bodyWidth * 0.32, y: bodyHeight * 0.30),
                control2: CGPoint(x: bodyWidth * 0.19, y: bodyHeight * 0.42)
            )
            let fuse = SKShapeNode(path: fusePath)
            fuse.strokeColor = .systemYellow
            fuse.lineWidth = 2
            fuse.lineCap = .round
            fuse.zPosition = 4
            addChild(fuse)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
