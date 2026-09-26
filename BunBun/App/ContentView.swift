import SpriteKit
import SwiftUI

struct ContentView: View {
    @StateObject private var campaignController = CampaignController()
    @State private var selectedLevelID: LevelID?

    var body: some View {
        Group {
            if let selectedLevelID {
                let level = LevelCatalog.definition(for: selectedLevelID)
                GameContainerView(
                    level: level,
                    hasNextLevel: LevelCatalog.nextLevel(after: selectedLevelID) != nil,
                    onCompleted: { levelID, score in
                        campaignController.recordCompletion(levelID: levelID, score: score)
                    },
                    onLevels: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            self.selectedLevelID = nil
                        }
                    },
                    onNext: {
                        guard let next = LevelCatalog.nextLevel(after: selectedLevelID) else { return }
                        withAnimation(.easeInOut(duration: 0.22)) {
                            self.selectedLevelID = next.id
                        }
                    }
                )
                .id(selectedLevelID)
                .transition(.opacity)
            } else {
                LevelSelectionView(
                    controller: campaignController,
                    onSelect: { levelID in
                        withAnimation(.easeInOut(duration: 0.22)) {
                            selectedLevelID = levelID
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct LevelSelectionView: View {
    @ObservedObject var controller: CampaignController
    let onSelect: (LevelID) -> Void
    @State private var showsResetConfirmation = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.035, green: 0.05, blue: 0.11),
                    Color(red: 0.11, green: 0.035, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 5) {
                        Text("BUNBUN")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                        Text("BETH EDITION • PROTOTYPE 0.5")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.58))
                            .tracking(1.2)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 5)

                    ForEach(Array(LevelCatalog.levels.enumerated()), id: \.element.id) { index, level in
                        levelCard(level, number: index + 1)
                    }

                    Button("RESET PROGRESS", role: .destructive) {
                        showsResetConfirmation = true
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 22)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .confirmationDialog(
            "Reset all unlocked levels and best scores?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Progress", role: .destructive) {
                controller.resetProgress()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func levelCard(_ level: LevelDefinition, number: Int) -> some View {
        let unlocked = controller.campaign.isUnlocked(level.id)
        let completed = controller.campaign.isCompleted(level.id)
        let score = controller.campaign.bestScore(for: level.id)

        return Button {
            guard unlocked else { return }
            onSelect(level.id)
        } label: {
            HStack(spacing: 15) {
                ZStack {
                    Image(level.theme.backgroundAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 58, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .saturation(unlocked ? 1 : 0)
                        .opacity(unlocked ? 0.92 : 0.28)
                    RoundedRectangle(cornerRadius: 15)
                        .fill(themeColor(level.theme).opacity(unlocked ? 0.20 : 0.30))
                        .frame(width: 58, height: 68)
                    Text(unlocked ? "\(number)" : "🔒")
                        .font(.system(size: unlocked ? 25 : 20, weight: .black, design: .rounded))
                        .shadow(color: .black.opacity(0.75), radius: 3)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(level.displayName)
                            .font(.title3.weight(.heavy))
                        if completed {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    Text(unlocked ? level.subtitle : "Complete the previous level to unlock")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.64))
                        .multilineTextAlignment(.leading)
                    if let score {
                        Text("BEST SCORE  \(score)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.yellow.opacity(0.9))
                    }
                }

                Spacer(minLength: 0)
                if unlocked {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 98)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(unlocked ? 0.085 : 0.04))
                    .stroke(Color.white.opacity(unlocked ? 0.18 : 0.08), lineWidth: 1)
            )
            .opacity(unlocked ? 1 : 0.7)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }

    private func themeColor(_ theme: LevelTheme) -> Color {
        switch theme {
        case .lab: .orange
        case .meadow: .green
        case .rehearsal: .cyan
        }
    }
}

@MainActor
private final class GameSceneHolder: ObservableObject {
    let scene: GameScene

    init(
        level: LevelDefinition,
        hasNextLevel: Bool,
        onCompleted: @escaping (LevelID, Int) -> Void,
        onLevels: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        scene = GameScene(
            size: CGSize(width: 390, height: 844),
            level: level,
            hasNextLevel: hasNextLevel,
            onLevelCompleted: onCompleted,
            onRequestLevels: onLevels,
            onRequestNextLevel: onNext
        )
        scene.scaleMode = .resizeFill
    }
}

private struct GameContainerView: View {
    let level: LevelDefinition
    @StateObject private var holder: GameSceneHolder
    @State private var showsLevelIntro = true

    init(
        level: LevelDefinition,
        hasNextLevel: Bool,
        onCompleted: @escaping (LevelID, Int) -> Void,
        onLevels: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.level = level
        _holder = StateObject(wrappedValue: GameSceneHolder(
            level: level,
            hasNextLevel: hasNextLevel,
            onCompleted: onCompleted,
            onLevels: onLevels,
            onNext: onNext
        ))
    }

    var body: some View {
        ZStack {
            SpriteView(scene: holder.scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            if showsLevelIntro {
                ZStack {
                    Color.black.opacity(0.82).ignoresSafeArea()
                    VStack(spacing: 8) {
                        Text(level.displayName.uppercased())
                            .font(.system(size: 28, weight: .black, design: .rounded))
                        Text(level.subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(850))
            withAnimation(.easeOut(duration: 0.28)) {
                showsLevelIntro = false
            }
        }
    }
}
