import SpriteKit
import UIKit

private enum BunnyMotion: String, CaseIterable {
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

/// Recolors the shared blue animation art on the GPU. Hue rotation preserves
/// black eyes, white highlights, and shading while avoiding six full texture
/// copies of every motion in memory.
@MainActor
private enum BunnyHueShaderLibrary {
    private static let source = """
    vec3 rotateHue(vec3 color, float angle) {
        float y = dot(color, vec3(0.299, 0.587, 0.114));
        float i = dot(color, vec3(0.596, -0.274, -0.322));
        float q = dot(color, vec3(0.211, -0.523, 0.312));
        float cosine = cos(angle);
        float sine = sin(angle);
        float rotatedI = i * cosine - q * sine;
        float rotatedQ = i * sine + q * cosine;
        return vec3(
            y + 0.956 * rotatedI + 0.621 * rotatedQ,
            y - 0.272 * rotatedI - 0.647 * rotatedQ,
            y - 1.106 * rotatedI + 1.703 * rotatedQ
        );
    }

    void main() {
        vec4 pixel = texture2D(u_texture, v_tex_coord);
        vec3 shifted = rotateHue(pixel.rgb, u_hueAngle);
        shifted = clamp(shifted, vec3(0.0), vec3(pixel.a));
        gl_FragColor = vec4(shifted, pixel.a) * v_color_mix.a;
    }
    """

    private static let shaders: [BunnyColor: SKShader] = Dictionary(
        uniqueKeysWithValues: BunnyColor.allCases.compactMap { color in
            guard color != .blue else { return nil }
            let shader = SKShader(
                source: source,
                uniforms: [SKUniform(name: "u_hueAngle", float: Float(-hueAngle(for: color)))]
            )
            return (color, shader)
        }
    )

    static func shader(for color: BunnyColor) -> SKShader? {
        shaders[color]
    }

    private static func hueAngle(for color: BunnyColor) -> CGFloat {
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

/// Splits the pre-cleaned 4x2 sheets once per motion. Color is supplied by the
/// sprite shader, so every bunny shares these textures and the live animation
/// path never performs image cleanup or Core Image rendering.
@MainActor
private final class BunnyAnimationLibrary {
    private final class TextureSet: NSObject {
        let textures: [SKTexture]

        init(_ textures: [SKTexture]) {
            self.textures = textures
        }
    }

    static let shared = BunnyAnimationLibrary()

    private let cache: NSCache<NSString, TextureSet> = {
        let cache = NSCache<NSString, TextureSet>()
        // There is one texture set per motion now, rather than one per
        // motion/color pair. All ten animation sets fit inside this budget.
        cache.countLimit = BunnyMotion.allCases.count
        cache.totalCostLimit = 72 * 1_024 * 1_024
        return cache
    }()

    func textures(for motion: BunnyMotion) -> [SKTexture] {
        let key = motion.rawValue
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
            let texture = SKTexture(cgImage: frame)
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

    func preloadGameplayTextures() {
        let textures = BunnyMotion.allCases.flatMap { self.textures(for: $0) }
        SKTexture.preload(textures, withCompletionHandler: {})
    }
}

/// Presentation-only bunny. The rules layer never sees this type, so richer
/// sprite sheets or a 3D character can replace it without changing game rules.
@MainActor
final class BunnyNode: SKNode {
    static func preloadAnimationTextures() {
        BunnyAnimationLibrary.shared.preloadGameplayTextures()
    }

    let bunnyID: UUID

    private let visualRoot = SKNode()
    private let bunnyKind: BunnyKind
    private var sprite: SKSpriteNode?
    private weak var specialBadge: SKNode?
    private let cellWidth: CGFloat
    private let cellHeight: CGFloat
    private let animationSeed: Int
    private var presentationScale: CGFloat
    private var spriteDisplaySize = CGSize.zero
    private var isAiming = false
    private var isDancing = false
    private var isPerformingOneShot = false

    init(
        bunny: Bunny,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        color: SKColor,
        presentationScale: CGFloat = 1
    ) {
        bunnyID = bunny.id
        bunnyKind = bunny.kind
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        self.presentationScale = presentationScale
        animationSeed = bunny.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        super.init()
        name = "bunny:\(bunny.id.uuidString)"
        // Grow the artwork upward from a stable ground contact instead of
        // scaling around its center. The outer BunnyNode remains at scale 1,
        // so aim, entrance, chain, and dance actions stay relative and cannot
        // erase the row's permanent perspective scale.
        applyPresentationScale(presentationScale)
        addChild(visualRoot)

        let bodyWidth = cellWidth * 0.66
        let bodyHeight = cellHeight * 0.63

        let idleTextures = BunnyAnimationLibrary.shared.textures(for: .idle)
        if let firstTexture = idleTextures.first {
            let displaySize = CGSize(
                width: cellWidth * (1.05 + CGFloat(animationSeed % 3) * 0.025),
                height: cellHeight * (1.05 + CGFloat(animationSeed % 3) * 0.025)
            )
            let sprite = SKSpriteNode(
                texture: firstTexture,
                size: displaySize
            )
            sprite.name = "artwork"
            spriteDisplaySize = displaySize
            sprite.position.y = cellHeight * 0.04
            sprite.zPosition = 0
            sprite.shader = BunnyHueShaderLibrary.shader(for: bunny.color)
            visualRoot.addChild(sprite)
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

    /// Changes the row-perspective scale around the bunny's feet. Keeping this
    /// animation on the artwork root leaves the outer node free for travel and
    /// one-shot emphasis, so a chain can no longer briefly reset a bunny to a
    /// different size before it settles into the next row.
    func setPresentationScale(_ scale: CGFloat, duration: TimeInterval = 0) {
        presentationScale = scale
        visualRoot.removeAction(forKey: "presentationScale")
        let groundOffset = (scale - 1) * cellHeight * 0.485
        guard duration > 0 else {
            applyPresentationScale(scale)
            return
        }

        let resize = SKAction.scale(to: scale, duration: duration)
        resize.timingMode = .easeInEaseOut
        let anchor = SKAction.moveTo(y: groundOffset, duration: duration)
        anchor.timingMode = .easeInEaseOut
        visualRoot.run(.group([resize, anchor]), withKey: "presentationScale")
    }

    func playCelebration(chainDepth: Int) {
        isPerformingOneShot = true
        let speed = max(0.075, 0.087 - Double(chainDepth - 1) * 0.006)
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
        guard play(.advance, timePerFrame: 0.085, repeats: false) else {
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

    func setDancing(_ dancing: Bool, forceRestart: Bool = false) {
        guard forceRestart || dancing != isDancing else { return }
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
        let textures = BunnyAnimationLibrary.shared.textures(for: .idle)
        guard !textures.isEmpty else { return }

        sprite.removeAction(forKey: "textureAnimation")
        // Boogie Bunnies held readable poses between short gestures. Divide the
        // crowd into seven stable cohorts so only a small portion is moving at
        // once, then return every bunny to the neutral first frame.
        let idleSpeed = [0.155, 0.163, 0.171][animationSeed % 3]
        let gestureDuration = idleSpeed * Double(textures.count)
        let cohortSlot: TimeInterval = 1.10
        let cycleDuration = cohortSlot * 7
        let cohort = animationSeed % 7
        let personalityOffset = Double((animationSeed / 7) % 4) * 0.035
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
        let textures = BunnyAnimationLibrary.shared.textures(for: motion)
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
            setDancing(true, forceRestart: true)
        } else if isAiming {
            _ = play(.aim, timePerFrame: 0.135, repeats: true)
        } else {
            playIdle()
        }
    }

    private func applyPresentationScale(_ scale: CGFloat) {
        visualRoot.setScale(scale)
        visualRoot.position.y = (scale - 1) * cellHeight * 0.485
    }

    private func addPlaceholder(color: SKColor, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        let body = SKShapeNode(ellipseOf: CGSize(width: bodyWidth, height: bodyHeight))
        body.position.y = -cellHeight * 0.06
        body.fillColor = color
        body.strokeColor = .white.withAlphaComponent(0.72)
        body.lineWidth = 1.4
        visualRoot.addChild(body)

        let earSize = CGSize(width: bodyWidth * 0.27, height: cellHeight * 0.34)
        for direction: CGFloat in [-1, 1] {
            let ear = SKShapeNode(ellipseOf: earSize)
            ear.position = CGPoint(x: direction * bodyWidth * 0.22, y: bodyHeight * 0.38)
            ear.zRotation = direction * -0.10
            ear.fillColor = color
            ear.strokeColor = .white.withAlphaComponent(0.72)
            ear.lineWidth = 1.2
            ear.zPosition = -1
            visualRoot.addChild(ear)
        }

        let eyeRadius = max(1.2, cellWidth * 0.045)
        for direction: CGFloat in [-1, 1] {
            let eye = SKShapeNode(circleOfRadius: eyeRadius)
            eye.position = CGPoint(x: direction * bodyWidth * 0.16, y: body.position.y + bodyHeight * 0.08)
            eye.fillColor = SKColor(white: 0.08, alpha: 0.9)
            eye.strokeColor = .clear
            eye.zPosition = 2
            visualRoot.addChild(eye)
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
        visualRoot.addChild(badge)
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
            visualRoot.addChild(fuse)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
