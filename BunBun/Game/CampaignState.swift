import Foundation

struct CampaignState: Equatable, Codable, Sendable {
    private(set) var unlockedLevels: Set<LevelID>
    private(set) var completedLevels: Set<LevelID>
    private(set) var bestScores: [LevelID: Int]

    init(
        unlockedLevels: Set<LevelID> = [.bunnyLab],
        completedLevels: Set<LevelID> = [],
        bestScores: [LevelID: Int] = [:]
    ) {
        self.unlockedLevels = unlockedLevels.isEmpty ? [.bunnyLab] : unlockedLevels
        self.completedLevels = completedLevels
        self.bestScores = bestScores
    }

    func isUnlocked(_ levelID: LevelID) -> Bool {
        unlockedLevels.contains(levelID)
    }

    func isCompleted(_ levelID: LevelID) -> Bool {
        completedLevels.contains(levelID)
    }

    func bestScore(for levelID: LevelID) -> Int? {
        bestScores[levelID]
    }

    mutating func record(
        levelID: LevelID,
        score: Int,
        result: PlayStatus,
        orderedLevels: [LevelID] = LevelID.allCases
    ) {
        guard result == .won, unlockedLevels.contains(levelID) else { return }

        completedLevels.insert(levelID)
        bestScores[levelID] = max(bestScores[levelID] ?? 0, score)

        guard let index = orderedLevels.firstIndex(of: levelID),
              orderedLevels.indices.contains(index + 1) else { return }
        unlockedLevels.insert(orderedLevels[index + 1])
    }
}
