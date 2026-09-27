import XCTest
import UIKit
@testable import BunBun

final class LevelDefinitionTests: XCTestCase {
    func testEveryStartingBoardIsValidAndMatchFree() {
        for level in LevelCatalog.levels {
            let board = level.startingBoard()

            XCTAssertFalse(board.occupants.isEmpty, level.displayName)
            XCTAssertTrue(
                board.occupiedCells.allSatisfy(board.contains),
                "\(level.displayName) contains an out-of-bounds starting cell"
            )
            XCTAssertTrue(
                MatchEngine().allMatches(on: board).isEmpty,
                "\(level.displayName) should not begin with a passive match"
            )
        }
    }

    func testStartingBoardsOfferSeveralNearMatchPairs() {
        for level in LevelCatalog.levels {
            let board = level.startingBoard()
            let pairEdges = board.occupiedCells.reduce(into: 0) { count, cell in
                guard let bunny = board[cell] else { return }
                let right = cell.neighbor(columnDelta: 1, rowDelta: 0)
                let above = cell.neighbor(columnDelta: 0, rowDelta: 1)
                if board[right]?.color == bunny.color { count += 1 }
                if board[above]?.color == bunny.color { count += 1 }
            }

            XCTAssertGreaterThanOrEqual(
                pairEdges,
                3,
                "\(level.displayName) should begin with useful almost-matches"
            )
        }
    }

    func testLevelRulesReachGameState() {
        for level in LevelCatalog.levels {
            let state = GameState(board: level.startingBoard(), rules: level.rules)
            XCTAssertEqual(state.rules, level.rules)
        }
    }

    func testSeededArrivalPatternsAreDeterministicAndUseMarchingColumns() {
        for level in LevelCatalog.levels {
            let first = level.arrivalPattern(forTurn: 19)
            let second = level.arrivalPattern(forTurn: 19)

            XCTAssertEqual(first, second)
            XCTAssertTrue(first.keys.allSatisfy(Board.marchingColumns.contains))
            XCTAssertNil(first[0])
            XCTAssertNil(first[11])
        }
    }

    func testSeededArrivalsFavorAdjacentPairsWithoutFreeTriples() {
        for level in LevelCatalog.levels {
            var adjacentPairs = 0
            for turn in 0..<12 {
                let pattern = level.arrivalPattern(forTurn: turn)
                for column in Board.marchingColumns.dropLast() {
                    guard let color = pattern[column]?.color else { continue }
                    if pattern[column + 1]?.color == color {
                        adjacentPairs += 1
                    }
                    XCTAssertFalse(
                        pattern[column + 1]?.color == color
                            && pattern[column + 2]?.color == color,
                        "\(level.displayName) should seed pairs, not automatic triples"
                    )
                }
            }

            XCTAssertGreaterThanOrEqual(
                adjacentPairs,
                24,
                "\(level.displayName) should regularly generate tempting pairs"
            )
        }
    }

    func testLevelsHaveMeaningfullyDifferentRulesAndSequences() {
        XCTAssertNotEqual(LevelCatalog.bunnyLab.rules, LevelCatalog.moonlightMeadow.rules)
        XCTAssertNotEqual(LevelCatalog.moonlightMeadow.rules, LevelCatalog.danceRehearsal.rules)
        XCTAssertNotEqual(LevelCatalog.bunnyLab.shotSequence, LevelCatalog.danceRehearsal.shotSequence)
        XCTAssertEqual(LevelCatalog.levels.count, 12)
        XCTAssertEqual(LevelCatalog.levels.map(\.id), LevelID.allCases)
        XCTAssertEqual(LevelCatalog.bunnyLab.theme, LevelCatalog.carrotWorks.theme)
        XCTAssertEqual(LevelCatalog.moonlightMeadow.theme, LevelCatalog.fireflyFalls.theme)
        XCTAssertEqual(LevelCatalog.danceRehearsal.theme, LevelCatalog.birthdayBash.theme)
    }

    func testEveryEnvironmentHasABundledBackground() {
        for environment in LevelEnvironment.allCases {
            XCTAssertNotNil(
                UIImage(named: environment.backgroundAssetName),
                "Missing bundled background for \(environment.rawValue)"
            )
        }
    }

    func testRenderedCreekPlateIsBundled() {
        XCTAssertNotNil(UIImage(named: "CreekWaterRendered"))
    }

    func testEnvironmentProfilesStayIndependentFromRulesThemes() {
        XCTAssertEqual(LevelCatalog.bunnyLab.environment, .desertCamp)
        XCTAssertEqual(LevelCatalog.carrotWorks.environment, .desertCamp)
        XCTAssertEqual(LevelCatalog.sunsetShuffle.environment, .desertCamp)
        XCTAssertEqual(LevelCatalog.meadowWarmup.environment, .forestCampDay)
        XCTAssertEqual(LevelCatalog.riversideRomp.environment, .forestCampDay)
        XCTAssertEqual(LevelCatalog.campfireCadence.environment, .forestCampDay)
        XCTAssertEqual(LevelCatalog.moonlightMeadow.environment, .forestCampNight)
        XCTAssertEqual(LevelCatalog.fireflyFalls.environment, .forestCampNight)
        XCTAssertEqual(LevelCatalog.midnightEncore.environment, .forestCampNight)
        XCTAssertEqual(LevelCatalog.danceRehearsal.environment, .snowyWoodland)
        XCTAssertEqual(LevelCatalog.snowflakeShuffle.environment, .snowyWoodland)
        XCTAssertEqual(LevelCatalog.birthdayBash.environment, .snowyWoodland)

        for environment in LevelEnvironment.allCases {
            XCTAssertEqual(
                LevelCatalog.levels.filter { $0.environment == environment }.count,
                3,
                "\(environment.displayName) should contain a three-stage arc"
            )
        }
    }
}

final class CampaignStateTests: XCTestCase {
    func testCompletingLevelUnlocksExactlyTheNextLevel() {
        var campaign = CampaignState()

        campaign.record(levelID: .bunnyLab, score: 800, result: .won)

        XCTAssertTrue(campaign.isCompleted(.bunnyLab))
        XCTAssertTrue(campaign.isUnlocked(.carrotWorks))
        XCTAssertFalse(campaign.isUnlocked(.moonlightMeadow))
    }

    func testLosingDoesNotUnlockALevel() {
        var campaign = CampaignState()

        campaign.record(levelID: .bunnyLab, score: 900, result: .lost)

        XCTAssertFalse(campaign.isCompleted(.bunnyLab))
        XCTAssertFalse(campaign.isUnlocked(.moonlightMeadow))
        XCTAssertNil(campaign.bestScore(for: .bunnyLab))
    }

    func testBestScoreOnlyImproves() {
        var campaign = CampaignState()

        campaign.record(levelID: .bunnyLab, score: 1_200, result: .won)
        campaign.record(levelID: .bunnyLab, score: 700, result: .won)
        XCTAssertEqual(campaign.bestScore(for: .bunnyLab), 1_200)

        campaign.record(levelID: .bunnyLab, score: 1_600, result: .won)
        XCTAssertEqual(campaign.bestScore(for: .bunnyLab), 1_600)
    }

    func testFinalLevelDoesNotUnlockAnInvalidLevel() {
        var campaign = CampaignState(
            unlockedLevels: Set(LevelID.allCases),
            completedLevels: Set(LevelID.allCases.dropLast())
        )

        campaign.record(levelID: .birthdayBash, score: 2_500, result: .won)

        XCTAssertEqual(campaign.unlockedLevels, Set(LevelID.allCases))
        XCTAssertTrue(campaign.isCompleted(.birthdayBash))
    }

    func testCampaignEncodingRoundTrips() throws {
        var original = CampaignState()
        original.record(levelID: .bunnyLab, score: 1_234, result: .won)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CampaignState.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testLoadingAnOlderFrontierUnlocksInsertedStagesWithoutLosingProgress() throws {
        let oldCampaign = CampaignState(
            unlockedLevels: [.bunnyLab, .carrotWorks, .moonlightMeadow],
            completedLevels: [.bunnyLab, .carrotWorks],
            bestScores: [.bunnyLab: 900, .carrotWorks: 1_100]
        )
        let storage = MemoryCampaignPersistence(
            campaignData: try JSONEncoder().encode(oldCampaign)
        )

        let migrated = CampaignRepository(persistence: storage).load()

        XCTAssertTrue(migrated.isUnlocked(.sunsetShuffle))
        XCTAssertTrue(migrated.isUnlocked(.meadowWarmup))
        XCTAssertTrue(migrated.isUnlocked(.campfireCadence))
        XCTAssertTrue(migrated.isUnlocked(.moonlightMeadow))
        XCTAssertEqual(migrated.bestScore(for: .carrotWorks), 1_100)
    }

    func testMissingAndCorruptSaveDataFallBackSafely() {
        let emptyStorage = MemoryCampaignPersistence()
        XCTAssertEqual(CampaignRepository(persistence: emptyStorage).load(), CampaignState())

        let corruptStorage = MemoryCampaignPersistence(campaignData: Data("not json".utf8))
        XCTAssertEqual(CampaignRepository(persistence: corruptStorage).load(), CampaignState())
    }

    func testRepositoryPersistsAndResetsCampaign() {
        let storage = MemoryCampaignPersistence()
        let repository = CampaignRepository(persistence: storage)
        var campaign = CampaignState()
        campaign.record(levelID: .bunnyLab, score: 500, result: .won)

        repository.save(campaign)
        XCTAssertEqual(repository.load(), campaign)
        XCTAssertEqual(repository.reset(), CampaignState())
        XCTAssertNil(storage.campaignData)
    }
}
