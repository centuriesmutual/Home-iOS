import Foundation
import UIKit

// MARK: - Qualtrics API Manager
class QualtricsAPIManager: ObservableObject {
    static let shared = QualtricsAPIManager()
    
    @Published var isInitialized = false
    @Published var adRevenue: Double = 0.0
    @Published var adLoadStatus: [String: AdLoadStatus] = [:]
    
    private var apiKey: String
    private var baseURL = "https://api.qualtrics.com/v1"
    
    private init() {
        self.apiKey = CenturiesMutualConfig.shared.qualtricsAPIKey
    }
    
    // MARK: - SDK Initialization
    func initialize() async throws {
        guard !isInitialized else { return }
        try await validateAPIKey()
        self.isInitialized = true
    }
    
    // MARK: - Survey Ads (Inbox)
    func loadSurveyAd(adUnitId: String) async throws -> QualtricsSurveyAd {
        let url = URL(string: "\(baseURL)/surveys/ads")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let adRequest = QualtricsAdRequest(
            adUnitId: adUnitId,
            adType: "survey",
            placement: "inbox"
        )
        
        request.httpBody = try JSONEncoder().encode(adRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw QualtricsError.adLoadFailed
        }
        
        let adResponse = try JSONDecoder().decode(QualtricsAdResponse.self, from: data)
        adLoadStatus[adUnitId] = .loaded
        
        return QualtricsSurveyAd(adData: adResponse, delegate: self)
    }
    
    // MARK: - Revenue Tracking
    func trackRevenue(adUnitId: String, revenue: Double, currency: String = "USD") {
        adRevenue += revenue
        
        let revenueData = AdRevenueData(
            adUnitId: adUnitId,
            revenue: revenue,
            currency: currency,
            timestamp: Date(),
            adType: "Qualtrics",
            placement: "inbox"
        )
        
        storeRevenueData(revenueData)
        
        Task {
            try? await sendRevenueToBackend(revenueData)
        }
    }
    
    // MARK: - Private Methods
    private func validateAPIKey() async throws {
        let url = URL(string: "\(baseURL)/auth/validate")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw QualtricsError.invalidAPIKey
        }
    }
    
    private func storeRevenueData(_ data: AdRevenueData) {
        Task {
            try? await SQLManager.shared.insertAdRevenue(data)
        }
    }
    
    private func sendRevenueToBackend(_ data: AdRevenueData) async throws {
        let url = URL(string: "\(CenturiesMutualConfig.shared.linodeBaseURL)/api/ad-revenue")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(CenturiesMutualConfig.shared.backendAPIKey)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONEncoder().encode(data)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw QualtricsError.revenueTrackingFailed
        }
    }
}

// MARK: - QualtricsSurveyDelegate
extension QualtricsAPIManager: QualtricsSurveyDelegate {
    func surveyDidComplete(_ surveyAd: QualtricsSurveyAd) {
        DispatchQueue.main.async {
            self.grantReward(for: surveyAd.adUnitId)
        }
    }
    
    func surveyDidFail(_ surveyAd: QualtricsSurveyAd, error: Error) {
        DispatchQueue.main.async {
            self.adLoadStatus[surveyAd.adUnitId] = .failed
        }
    }
}

// MARK: - Reward System
extension QualtricsAPIManager {
    private func grantReward(for adUnitId: String) {
        let rewardAmount = getRewardAmount(for: adUnitId)
        
        Task {
            try? await updateUserRewards(amount: rewardAmount)
        }
        
        showRewardNotification(amount: rewardAmount)
    }
    
    private func getRewardAmount(for adUnitId: String) -> Double {
        return CenturiesMutualConfig.shared.qualtricsRewardAmounts[adUnitId] ?? 0.05
    }
    
    private func updateUserRewards(amount: Double) async throws {
        try await SQLManager.shared.updateUserRewards(amount: amount)
    }
    
    private func showRewardNotification(amount: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Survey Reward Earned!"
        content.body = "You earned $\(String(format: "%.2f", amount)) for completing a Qualtrics survey."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "qualtrics_reward_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Supporting Types
struct QualtricsAdRequest: Codable {
    let adUnitId: String
    let adType: String
    let placement: String
    let userId: String?
    
    enum CodingKeys: String, CodingKey {
        case adUnitId = "ad_unit_id"
        case adType = "ad_type"
        case placement
        case userId = "user_id"
    }
}

struct QualtricsAdResponse: Codable {
    let adId: String
    let adUnitId: String
    let surveyId: String
    let title: String
    let description: String
    let reward: Double
    let estimatedTime: Int
    
    enum CodingKeys: String, CodingKey {
        case adId = "ad_id"
        case adUnitId = "ad_unit_id"
        case surveyId = "survey_id"
        case title, description, reward
        case estimatedTime = "estimated_time"
    }
}

class QualtricsSurveyAd: NSObject {
    let adData: QualtricsAdResponse
    weak var delegate: QualtricsSurveyDelegate?
    
    var adUnitId: String { adData.adUnitId }
    
    init(adData: QualtricsAdResponse, delegate: QualtricsSurveyDelegate) {
        self.adData = adData
        self.delegate = delegate
        super.init()
    }
    
    func showSurvey() {
        // Implement survey display
        delegate?.surveyDidComplete(self)
    }
}

protocol QualtricsSurveyDelegate: AnyObject {
    func surveyDidComplete(_ surveyAd: QualtricsSurveyAd)
    func surveyDidFail(_ surveyAd: QualtricsSurveyAd, error: Error)
}

enum QualtricsError: Error, LocalizedError {
    case sdkNotInitialized
    case adLoadFailed
    case revenueTrackingFailed
    case invalidAPIKey
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .sdkNotInitialized:
            return "Qualtrics SDK is not initialized."
        case .adLoadFailed:
            return "Failed to load survey ad."
        case .revenueTrackingFailed:
            return "Failed to track ad revenue."
        case .invalidAPIKey:
            return "Invalid Qualtrics API key."
        case .networkError:
            return "Network error occurred while loading ads."
        }
    }
}
