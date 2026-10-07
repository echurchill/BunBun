import SpriteKit

/// Builds the heads-up display (title, prompt, controls, meters, next-shot
/// preview, television labels, debug line). Pure layout over a snapshot of
/// game values: the scene resolves level and state into the context, so this
/// type never reads game state directly and every configuration — including
/// television and debug — is reproducible from its context alone.
@MainActor
enum HUD {
    struct Meter {
        let title: String
        let value: Int
        let maximumValue: Int
        let color: SKColor
    }

    struct Context {
        let size: CGSize
        let boardOriginY: CGFloat
        let cellHeight: CGFloat
        let isTablet: Bool
        let isTelevision: Bool
        let hudScale: CGFloat
        let levelName: String
        let campaignStatus: String
        let appVersion: String
        let subtitle: String
        /// Text for the debug toggle, or nil when the toggle is hidden
        /// (Release builds and the standard HUD).
        let debugControlText: String?
        /// Debug status line, or nil when hidden.
        let debugLine: String?
        /// Exactly three meters: progress, dance, danger.
        let meters: [Meter]
        let previewBunny: Bunny
        let previewTint: SKColor
        let shotKind: BunnyKind
        let score: Int
        let launchesUntilAdvance: Int
        let danceActive: Bool
        /// Television side/lane status, or nil off tvOS.
        let televisionStatus: String?
    }

    static func render(in layer: SKNode, context: Context) {
        layer.removeAllChildren()

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "BUNBUN  •  \(context.levelName.uppercased()) \(context.appVersion)"
        title.fontSize = (context.levelName.count > 14 ? 16 : 19) * context.hudScale
        title.fontColor = .white
        title.position = CGPoint(x: context.size.width / 2, y: context.size.height - 82)
        layer.addChild(title)

        let topInset: CGFloat = context.isTelevision ? 150 : (context.isTablet ? 86 : 54)
        let score = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        score.name = "score"
        score.text = String(format: "%07d", context.score)
        score.fontSize = 13 * context.hudScale
        score.fontColor = .white
        score.horizontalAlignmentMode = .left
        score.position = CGPoint(x: topInset, y: context.size.height - 51)
        layer.addChild(score)

        let campaign = SKLabelNode(fontNamed: "AvenirNext-Bold")
        campaign.name = "campaign-status"
        campaign.text = context.campaignStatus
        campaign.fontSize = 9 * context.hudScale
        campaign.fontColor = SKColor(white: 0.82, alpha: 1)
        campaign.horizontalAlignmentMode = .right
        campaign.position = CGPoint(x: context.size.width - topInset, y: context.size.height - 49)
        layer.addChild(campaign)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitle.text = context.subtitle
        subtitle.fontSize = 12 * context.hudScale
        subtitle.fontColor = SKColor(white: 0.72, alpha: 1)
        subtitle.position = CGPoint(x: context.size.width / 2, y: title.position.y - 24)
        layer.addChild(subtitle)

        let controlInset: CGFloat = context.isTelevision ? 150 : (context.isTablet ? 90 : 58)
        if let debugControlText = context.debugControlText {
            addControl(to: layer, name: "debug", text: debugControlText, x: controlInset, context: context)
        }
        addControl(to: layer, name: "restart", text: "RESTART", x: context.size.width - controlInset, context: context)

        let preferredMeterWidth: CGFloat = context.isTelevision ? 230 : (context.isTablet ? 150 : 92)
        let meterWidth = min(preferredMeterWidth, (context.size.width - 48) / 3)
        let meterY = context.size.height - 166
        let meterX = [0.22, 0.50, 0.78]
        for (index, meter) in context.meters.enumerated() {
            addMeter(
                to: layer,
                title: meter.title,
                value: meter.value,
                maximumValue: meter.maximumValue,
                color: meter.color,
                x: context.size.width * meterX[index % meterX.count],
                y: meterY,
                width: meterWidth,
                context: context
            )
        }

        let preview = BunnyNode(
            bunny: context.previewBunny,
            cellWidth: 22,
            cellHeight: 31,
            color: context.previewTint
        )
        let isLargeScreen = context.isTablet || context.isTelevision
        let previewY = isLargeScreen ? max(72, context.boardOriginY - context.cellHeight * 1.6) : 69
        let previewOffset: CGFloat = context.isTelevision ? 150 : (context.isTablet ? 95 : 75)
        preview.position = CGPoint(x: context.size.width / 2 - previewOffset, y: previewY)
        preview.setScale(context.isTelevision ? 1.35 : (context.isTablet ? 1.05 : 0.82))
        layer.addChild(preview)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = previewCaption(
            shotKind: context.shotKind,
            launchesUntilAdvance: context.launchesUntilAdvance,
            danceActive: context.danceActive
        )
        label.fontSize = 12 * context.hudScale
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: preview.position.x + 20, y: preview.position.y)
        layer.addChild(label)

        if context.isTelevision {
            let remoteHelp = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            remoteHelp.text = "◀︎ ▶︎ SIDE    ▲ ▼ LANE    SELECT LAUNCH    PLAY/PAUSE PAUSE    MENU LEVELS"
            remoteHelp.fontSize = 12 * context.hudScale
            remoteHelp.fontColor = SKColor(white: 0.86, alpha: 0.92)
            remoteHelp.position = CGPoint(x: context.size.width / 2, y: 42)
            layer.addChild(remoteHelp)

            if let televisionStatus = context.televisionStatus {
                let selection = SKLabelNode(fontNamed: "AvenirNext-Heavy")
                selection.text = televisionStatus
                selection.fontSize = 13 * context.hudScale
                selection.fontColor = .systemYellow
                selection.position = CGPoint(x: context.size.width / 2, y: 75)
                layer.addChild(selection)
            }
        }

        if let debugLine = context.debugLine {
            let debug = SKLabelNode(fontNamed: "Menlo")
            debug.text = debugLine
            debug.fontSize = 9 * context.hudScale
            debug.fontColor = .systemGreen
            debug.position = CGPoint(x: context.size.width / 2, y: 38)
            layer.addChild(debug)
        }
    }

    private static func previewCaption(
        shotKind: BunnyKind,
        launchesUntilAdvance: Int,
        danceActive: Bool
    ) -> String {
        let multiplier = danceActive ? "   •   2×" : ""
        let nextName = switch shotKind {
        case .normal: "Next"
        case .redBomb: "Next BOMB"
        case .lineClear: "Next LINE"
        }
        return "\(nextName)   •   Hop in \(launchesUntilAdvance)\(multiplier)"
    }

    private static func addControl(
        to layer: SKNode,
        name: String,
        text: String,
        x: CGFloat,
        context: Context
    ) {
        let node = SKLabelNode(fontNamed: "AvenirNext-Bold")
        node.name = "control:\(name)"
        node.text = text
        node.fontSize = 10 * context.hudScale
        node.fontColor = SKColor(white: 0.70, alpha: 1)
        node.position = CGPoint(x: x, y: context.size.height - 132)
        layer.addChild(node)
    }

    private static func addMeter(
        to layer: SKNode,
        title: String,
        value: Int,
        maximumValue: Int,
        color: SKColor,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        context: Context
    ) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = 8 * context.hudScale
        label.fontColor = SKColor(white: 0.72, alpha: 1)
        label.position = CGPoint(x: x, y: y + 9)
        layer.addChild(label)

        let track = SKShapeNode(rectOf: CGSize(width: width, height: 7), cornerRadius: 3.5)
        track.position = CGPoint(x: x, y: y - 2)
        track.fillColor = SKColor(white: 0.17, alpha: 1)
        track.strokeColor = SKColor(white: 0.35, alpha: 1)
        track.lineWidth = 1
        layer.addChild(track)

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
        layer.addChild(fill)
    }
}
