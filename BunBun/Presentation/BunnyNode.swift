import CoreImage
import SpriteKit
import UIKit

private enum BunnyMotion: String {
    case idle = "BunnyIdleSheet"
    case celebration = "BunnyCelebrateSheet"
    case advance = "BunnyAdvanceSheet"
    case dance = "BunnyDanceSheet"
}

/// Splits the generated 4x2 sheets and hue-shifts the blue master art so every
/// gameplay color keeps the same silhouette, lighting, eyes, and animation.
@MainActor
private final class BunnyAnimationLibrary {
    static let shared = BunnyAnimationLibrary()

    private let context = CIContext(options: [.cacheIntermediates: true])
    private var cache: [String: [SKTexture]] = [:]

    func textures(for motion: BunnyMotion, color: BunnyColor) -> [SKTexture] {
        let key = "\(motion.rawValue):\(color.rawValue)"
        if let cached = cache[key] {
            return cached
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

        cache[key] = textures
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
    private var sprite: SKSpriteNode?
    private let cellWidth: CGFloat
    private let cellHeight: CGFloat

    init(bunny: Bunny, cellWidth: CGFloat, cellHeight: CGFloat, color: SKColor) {
        bunnyID = bunny.id
        bunnyColor = bunny.color
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        super.init()
        name = "bunny:\(bunny.id.uuidString)"

        let bodyWidth = cellWidth * 0.66
        let bodyHeight = cellHeight * 0.63

        let idleTextures = BunnyAnimationLibrary.shared.textures(for: .idle, color: bunny.color)
        if let firstTexture = idleTextures.first {
            let sprite = SKSpriteNode(
                texture: firstTexture,
                size: CGSize(width: cellWidth * 1.08, height: cellHeight * 1.08)
            )
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

    func playCelebration() {
        guard play(.celebration, timePerFrame: 0.065, repeats: false) else {
            run(.sequence([
                .scaleY(to: 0.84, duration: 0.08),
                .scaleY(to: 1.18, duration: 0.12),
                .scaleY(to: 1, duration: 0.12)
            ]))
            return
        }
    }

    func playAdvanceReaction() {
        guard play(.advance, timePerFrame: 0.07, repeats: false) else {
            run(.sequence([
                .scaleY(to: 0.82, duration: 0.14),
                .scaleY(to: 1, duration: 0.18)
            ]))
            return
        }
    }

    func setDancing(_ dancing: Bool) {
        removeAction(forKey: "fallbackDance")
        zRotation = 0

        if dancing, play(.dance, timePerFrame: 0.10, repeats: true) {
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
        let seed = bunnyID.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let delay = Double(seed % 8) * 0.018
        let animation = SKAction.repeatForever(.animate(with: textures, timePerFrame: 0.12))
        sprite.run(.sequence([.wait(forDuration: delay), animation]), withKey: "textureAnimation")
    }

    @discardableResult
    private func play(_ motion: BunnyMotion, timePerFrame: TimeInterval, repeats: Bool) -> Bool {
        guard let sprite else { return false }
        let textures = BunnyAnimationLibrary.shared.textures(for: motion, color: bunnyColor)
        guard !textures.isEmpty else { return false }

        sprite.removeAction(forKey: "textureAnimation")
        let animation = SKAction.animate(with: textures, timePerFrame: timePerFrame)
        if repeats {
            sprite.run(.repeatForever(animation), withKey: "textureAnimation")
        } else {
            sprite.run(.sequence([
                animation,
                .run { [weak self] in self?.playIdle() }
            ]), withKey: "textureAnimation")
        }
        return true
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
