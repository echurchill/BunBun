import SpriteKit

/// Builds the end-of-run panel (title, score, playtest stats, buttons).
/// Pure layout: the scene keeps audio cues, completion callbacks, and the
/// win confetti, which are side effects rather than geometry.
@MainActor
enum EndPanel {
    struct RunStats: Equatable {
        let launches: Int
        let falls: Int
        let specialActivations: Int
        let danceParties: Int
        let elapsedSeconds: Int
    }

    struct Context {
        let status: PlayStatus
        let score: Int
        let stats: RunStats
        let hasNextLevel: Bool
        let size: CGSize
        let boardCenter: CGPoint
        let isTablet: Bool
        /// 1 on phone/tablet, where the geometry stays exactly as tuned;
        /// `hudScale` on television for viewing distance.
        let panelScale: CGFloat
    }

    static func makeNode(context: Context) -> SKNode {
        let scale = context.panelScale
        let panelHeight: CGFloat = (context.status == .won ? 250 : 222) * scale
        let panel = SKShapeNode(
            rectOf: CGSize(
                width: min((context.isTablet ? 420 : 330) * scale, context.size.width - 38 * scale),
                height: panelHeight
            ),
            cornerRadius: 18 * scale
        )
        panel.fillColor = SKColor(white: 0.05, alpha: 0.92)
        panel.strokeColor = context.status == .won ? .systemGreen : .systemPink
        panel.lineWidth = 3 * scale
        panel.position = context.boardCenter
        panel.zPosition = 60

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = context.status == .won ? "LEVEL COMPLETE!" : "BUNNIES NEED A BREAK"
        title.fontSize = (context.status == .won ? 23 : 18) * scale
        title.fontColor = .white
        title.verticalAlignmentMode = .center
        title.position.y = panelHeight / 2 - 35 * scale
        panel.addChild(title)

        let prompt = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        prompt.text = context.status == .won
            ? "Score \(context.score)"
            : "Score \(context.score)  •  Ready to try again"
        prompt.fontSize = 12 * scale
        prompt.fontColor = SKColor(white: 0.75, alpha: 1)
        prompt.verticalAlignmentMode = .center
        prompt.position.y = panelHeight / 2 - 64 * scale
        panel.addChild(prompt)

        let activity = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        activity.text = "Launches \(context.stats.launches)  •  Falls \(context.stats.falls)"
        activity.fontSize = 11 * scale
        activity.fontColor = SKColor(white: 0.82, alpha: 1)
        activity.verticalAlignmentMode = .center
        activity.position.y = panelHeight / 2 - 90 * scale
        panel.addChild(activity)

        let events = SKLabelNode(fontNamed: "AvenirNext-Medium")
        events.text = "Specials \(context.stats.specialActivations)  •  Parties \(context.stats.danceParties)  •  \(context.stats.elapsedSeconds)s"
        events.fontSize = 10 * scale
        events.fontColor = SKColor(white: 0.68, alpha: 1)
        events.verticalAlignmentMode = .center
        events.position.y = panelHeight / 2 - 111 * scale
        panel.addChild(events)

        if context.status == .won {
            if context.hasNextLevel {
                addEndButton(to: panel, name: "next", text: "NEXT LEVEL", y: -24 * scale, scale: scale)
            }
            addEndButton(
                to: panel,
                name: "replay",
                text: "REPLAY",
                y: (context.hasNextLevel ? -62 : -38) * scale,
                scale: scale
            )
            addEndButton(
                to: panel,
                name: "levels",
                text: "LEVELS",
                y: (context.hasNextLevel ? -100 : -80) * scale,
                scale: scale
            )
        } else {
            addEndButton(to: panel, name: "replay", text: "RETRY", y: -43 * scale, scale: scale)
            addEndButton(to: panel, name: "levels", text: "LEVELS", y: -83 * scale, scale: scale)
        }
        return panel
    }

    private static func addEndButton(
        to panel: SKNode,
        name: String,
        text: String,
        y: CGFloat,
        scale: CGFloat
    ) {
        let button = SKShapeNode(
            rectOf: CGSize(width: 174 * scale, height: 31 * scale),
            cornerRadius: 10 * scale
        )
        button.name = "control:\(name)"
        button.position.y = y
        button.fillColor = name == "next" ? .systemGreen : SKColor(white: 0.18, alpha: 1)
        button.strokeColor = name == "next" ? .white : SKColor(white: 0.46, alpha: 1)
        button.lineWidth = (name == "next" ? 2 : 1) * scale
        panel.addChild(button)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.name = button.name
        label.text = text
        label.fontSize = 12 * scale
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        button.addChild(label)
    }
}
