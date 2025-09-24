import Foundation
import UIKit

// MARK: - Typeform API Manager
class TypeformAPIManager: ObservableObject {
    static let shared = TypeformAPIManager()
    
    @Published var isInitialized = false
    @Published var adRevenue: Double = 0.0
    @Published var adLoadStatus: [String: AdLoadStatus] = [:]
    
    private var apiKey: String
    private var baseURL = "https://api.typeform.com/v1"
    
    private init() {
        self.apiKey = CenturiesMutualConfig.shared.typeformAPIKey
    }
    
    // MARK: - SDK Initialization
    func initialize() async throws {
        guard !isInitialized else { return }
        try await validateAPIKey()
        self.isInitialized = true
    }
    
    // MARK: - Form Ads (Inbox)
    func loadFormAd(adUnitId: String) async throws -> TypeformFormAd {
        let url = URL(string: "\(baseURL)/forms/ads")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let adRequest = TypeformAdRequest(
            adUnitId: adUnitId,
            adType: "form",
            placement: "inbox"
        )
        
        request.httpBody = try JSONEncoder().encode(adRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TypeformError.adLoadFailed
        }
        
        let adResponse = try JSONDecoder().decode(TypeformAdResponse.self, from: data)
        adLoadStatus[adUnitId] = .loaded
        
        return TypeformFormAd(adData: adResponse, delegate: self)
    }
    
    // MARK: - Revenue Tracking
    func trackRevenue(adUnitId: String, revenue: Double, currency: String = "USD") {
        adRevenue += revenue
        
        let revenueData = AdRevenueData(
            adUnitId: adUnitId,
            revenue: revenue,
            currency: currency,
            timestamp: Date(),
            adType: "Typeform",
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
            throw TypeformError.invalidAPIKey
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
            throw TypeformError.revenueTrackingFailed
        }
    }
}

// MARK: - TypeformFormDelegate
extension TypeformAPIManager: TypeformFormDelegate {
    func formDidComplete(_ formAd: TypeformFormAd) {
        DispatchQueue.main.async {
            self.grantReward(for: formAd.adUnitId)
        }
    }
    
    func formDidFail(_ formAd: TypeformFormAd, error: Error) {
        DispatchQueue.main.async {
            self.adLoadStatus[formAd.adUnitId] = .failed
        }
    }
}

// MARK: - Reward System
extension TypeformAPIManager {
    private func grantReward(for adUnitId: String) {
        let rewardAmount = getRewardAmount(for: adUnitId)
        
        Task {
            try? await updateUserRewards(amount: rewardAmount)
        }
        
        showRewardNotification(amount: rewardAmount)
    }
    
    private func getRewardAmount(for adUnitId: String) -> Double {
        return CenturiesMutualConfig.shared.typeformRewardAmounts[adUnitId] ?? 0.05
    }
    
    private func updateUserRewards(amount: Double) async throws {
        try await SQLManager.shared.updateUserRewards(amount: amount)
    }
    
    private func showRewardNotification(amount: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Form Reward Earned!"
        content.body = "You earned $\(String(format: "%.2f", amount)) for completing a Typeform."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "typeform_reward_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Supporting Types
struct TypeformAdRequest: Codable {
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

struct TypeformAdResponse: Codable {
    let adId: String
    let adUnitId: String
    let formId: String
    let title: String
    let description: String
    let reward: Double
    let estimatedTime: Int
    
    enum CodingKeys: String, CodingKey {
        case adId = "ad_id"
        case adUnitId = "ad_unit_id"
        case formId = "form_id"
        case title, description, reward
        case estimatedTime = "estimated_time"
    }
}

class TypeformFormAd: NSObject {
    let adData: TypeformAdResponse
    weak var delegate: TypeformFormDelegate?
    
    var adUnitId: String { adData.adUnitId }
    
    init(adData: TypeformAdResponse, delegate: TypeformFormDelegate) {
        self.adData = adData
        self.delegate = delegate
        super.init()
    }
    
    func showForm() {
        // Implement form display
        delegate?.formDidComplete(self)
    }
}

protocol TypeformFormDelegate: AnyObject {
    func formDidComplete(_ formAd: TypeformFormAd)
    func formDidFail(_ formAd: TypeformFormAd, error: Error)
}

enum TypeformError: Error, LocalizedError {
    case sdkNotInitialized
    case adLoadFailed
    case revenueTrackingFailed
    case invalidAPIKey
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .sdkNotInitialized:
            return "Typeform SDK is not initialized."
        case .adLoadFailed:
            return "Failed to load form ad."
        case .revenueTrackingFailed:
            return "Failed to track ad revenue."
        case .invalidAPIKey:
            return "Invalid Typeform API key."
        case .networkError:
            return "Network error occurred while loading ads."
        }
    }
}
