import SpriteKit
import SwiftUI

struct ContentView: View {
    private let scene: SKScene = {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        SpriteView(scene: scene, options: [.ignoresSiblingOrder])
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
    }
}
