import Combine
import Foundation

protocol CampaignPersistence: AnyObject {
    var campaignData: Data? { get set }
}

final class UserDefaultsCampaignPersistence: CampaignPersistence {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "BunBun.campaign.v1") {
        self.defaults = defaults
        self.key = key
    }

    var campaignData: Data? {
        get { defaults.data(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}

final class MemoryCampaignPersistence: CampaignPersistence {
    var campaignData: Data?

    init(campaignData: Data? = nil) {
        self.campaignData = campaignData
    }
}

struct CampaignRepository {
    let persistence: any CampaignPersistence

    func load() -> CampaignState {
        guard let data = persistence.campaignData,
              var campaign = try? JSONDecoder().decode(CampaignState.self, from: data) else {
            return CampaignState()
        }
        campaign.reconcileUnlocks()
        return campaign
    }

    func save(_ campaign: CampaignState) {
        persistence.campaignData = try? JSONEncoder().encode(campaign)
    }

    func reset() -> CampaignState {
        persistence.campaignData = nil
        return CampaignState()
    }
}

@MainActor
final class CampaignController: ObservableObject {
    @Published private(set) var campaign: CampaignState
    private let repository: CampaignRepository

    init(repository: CampaignRepository = CampaignRepository(
        persistence: UserDefaultsCampaignPersistence()
    )) {
        self.repository = repository
        campaign = repository.load()
    }

    func recordCompletion(levelID: LevelID, score: Int) {
        campaign.record(levelID: levelID, score: score, result: .won)
        repository.save(campaign)
    }

    func resetProgress() {
        campaign = repository.reset()
    }
}
