import SpriteKit

/// Temporary art with the tall proportions Eddie remembers. The rules layer
/// never sees this type, so finished sprites or 3D characters can replace it.
final class BunnyNode: SKNode {
    let bunnyID: UUID

    init(bunny: Bunny, cellWidth: CGFloat, cellHeight: CGFloat, color: SKColor) {
        bunnyID = bunny.id
        super.init()
        name = "bunny:\(bunny.id.uuidString)"

        let bodyWidth = cellWidth * 0.66
        let bodyHeight = cellHeight * 0.63
        let body = SKShapeNode(ellipseOf: CGSize(width: bodyWidth, height: bodyHeight))
        body.position.y = -cellHeight * 0.06
        body.fillColor = color
        body.strokeColor = .white.withAlphaComponent(0.72)
        body.lineWidth = 1.4
        addChild(body)

        let earSize = CGSize(width: bodyWidth * 0.27, height: cellHeight * 0.34)
        for direction: CGFloat in [-1, 1] {
            let ear = SKShapeNode(ellipseOf: earSize)
            ear.position = CGPoint(
                x: direction * bodyWidth * 0.22,
                y: bodyHeight * 0.38
            )
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
            eye.position = CGPoint(
                x: direction * bodyWidth * 0.16,
                y: body.position.y + bodyHeight * 0.08
            )
            eye.fillColor = SKColor(white: 0.08, alpha: 0.9)
            eye.strokeColor = .clear
            eye.zPosition = 2
            addChild(eye)
        }
    }

    func setDancing(_ dancing: Bool) {
        removeAction(forKey: "dance")
        zRotation = 0
        guard dancing else { return }

        let sway = SKAction.sequence([
            .rotate(toAngle: -0.09, duration: 0.12, shortestUnitArc: true),
            .rotate(toAngle: 0.09, duration: 0.20, shortestUnitArc: true),
            .rotate(toAngle: 0, duration: 0.12, shortestUnitArc: true),
            .scaleY(to: 0.88, duration: 0.08),
            .scaleY(to: 1.08, duration: 0.10),
            .scaleY(to: 1, duration: 0.08)
        ])
        run(.repeatForever(sway), withKey: "dance")
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
