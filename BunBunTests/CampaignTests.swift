import XCTest
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

    func testLevelsHaveMeaningfullyDifferentRulesAndSequences() {
        XCTAssertNotEqual(LevelCatalog.bunnyLab.rules, LevelCatalog.moonlightMeadow.rules)
        XCTAssertNotEqual(LevelCatalog.moonlightMeadow.rules, LevelCatalog.danceRehearsal.rules)
        XCTAssertNotEqual(LevelCatalog.bunnyLab.shotSequence, LevelCatalog.danceRehearsal.shotSequence)
    }
}

final class CampaignStateTests: XCTestCase {
    func testCompletingLevelUnlocksExactlyTheNextLevel() {
        var campaign = CampaignState()

        campaign.record(levelID: .bunnyLab, score: 800, result: .won)

        XCTAssertTrue(campaign.isCompleted(.bunnyLab))
        XCTAssertTrue(campaign.isUnlocked(.moonlightMeadow))
        XCTAssertFalse(campaign.isUnlocked(.danceRehearsal))
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
            completedLevels: [.bunnyLab, .moonlightMeadow]
        )

        campaign.record(levelID: .danceRehearsal, score: 2_500, result: .won)

        XCTAssertEqual(campaign.unlockedLevels, Set(LevelID.allCases))
        XCTAssertTrue(campaign.isCompleted(.danceRehearsal))
    }

    func testCampaignEncodingRoundTrips() throws {
        var original = CampaignState()
        original.record(levelID: .bunnyLab, score: 1_234, result: .won)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CampaignState.self, from: data)

        XCTAssertEqual(decoded, original)
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
