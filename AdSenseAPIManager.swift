import Foundation
import UIKit

// MARK: - AdSense API Manager (Radio View)
class AdSenseAPIManager: ObservableObject {
    static let shared = AdSenseAPIManager()
    
    @Published var isInitialized = false
    @Published var adRevenue: Double = 0.0
    @Published var adLoadStatus: [String: AdLoadStatus] = [:]
    
    private var apiKey: String
    private var baseURL = "https://www.googleapis.com/adsense/v2"
    
    private init() {
        self.apiKey = CenturiesMutualConfig.shared.adSenseAPIKey
    }
    
    // MARK: - SDK Initialization
    func initialize() async throws {
        guard !isInitialized else { return }
        try await validateAPIKey()
        self.isInitialized = true
    }
    
    // MARK: - Banner Ads (Radio View)
    func loadBannerAd(adUnitId: String, size: AdSenseAdSize = .banner) async throws -> AdSenseBannerView {
        let bannerView = AdSenseBannerView(adUnitId: adUnitId, size: size)
        bannerView.delegate = self
        
        // Add to view hierarchy for radio view
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addSubview(bannerView)
            setupBannerConstraints(bannerView: bannerView, in: window)
        }
        
        try await bannerView.loadAd()
        adLoadStatus[adUnitId] = .loading
        
        return bannerView
    }
    
    // MARK: - Interstitial Ads (Radio View)
    func loadInterstitialAd(adUnitId: String) async throws {
        let url = URL(string: "\(baseURL)/ads/interstitial")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let adRequest = AdSenseAdRequest(
            adUnitId: adUnitId,
            adType: "interstitial",
            placement: "radio"
        )
        
        request.httpBody = try JSONEncoder().encode(adRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AdSenseError.adLoadFailed
        }
        
        let adResponse = try JSONDecoder().decode(AdSenseAdResponse.self, from: data)
        adLoadStatus[adUnitId] = .loaded
        
        storeAdData(adUnitId: adUnitId, adData: adResponse)
    }
    
    func showInterstitialAd(adUnitId: String) async throws {
        guard let adData = getStoredAdData(adUnitId: adUnitId) else {
            throw AdSenseError.adNotReady
        }
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            let interstitialView = AdSenseInterstitialView(adData: adData)
            interstitialView.delegate = self
            interstitialView.show(in: rootViewController)
        } else {
            throw AdSenseError.noRootViewController
        }
    }
    
    // MARK: - Rewarded Ads (Radio View)
    func loadRewardedAd(adUnitId: String) async throws {
        let url = URL(string: "\(baseURL)/ads/rewarded")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let adRequest = AdSenseAdRequest(
            adUnitId: adUnitId,
            adType: "rewarded",
            placement: "radio"
        )
        
        request.httpBody = try JSONEncoder().encode(adRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AdSenseError.adLoadFailed
        }
        
        let adResponse = try JSONDecoder().decode(AdSenseAdResponse.self, from: data)
        adLoadStatus[adUnitId] = .loaded
        
        storeAdData(adUnitId: adUnitId, adData: adResponse)
    }
    
    func showRewardedAd(adUnitId: String) async throws -> Bool {
        guard let adData = getStoredAdData(adUnitId: adUnitId) else {
            throw AdSenseError.adNotReady
        }
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            let rewardedView = AdSenseRewardedView(adData: adData)
            rewardedView.delegate = self
            rewardedView.show(in: rootViewController)
            return true
        } else {
            throw AdSenseError.noRootViewController
        }
    }
    
    // MARK: - Revenue Tracking
    func trackRevenue(adUnitId: String, revenue: Double, currency: String = "USD") {
        adRevenue += revenue
        
        let revenueData = AdRevenueData(
            adUnitId: adUnitId,
            revenue: revenue,
            currency: currency,
            timestamp: Date(),
            adType: "AdSense",
            placement: "radio"
        )
        
        storeRevenueData(revenueData)
        
        Task {
            try? await sendRevenueToBackend(revenueData)
        }
    }
    
    // MARK: - Analytics
    func getAdSenseAnalytics(startDate: String, endDate: String) async throws -> AdSenseAnalytics {
        let url = URL(string: "\(baseURL)/reports")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "startDate", value: startDate),
            URLQueryItem(name: "endDate", value: endDate),
            URLQueryItem(name: "dimension", value: "AD_UNIT"),
            URLQueryItem(name: "metric", value: "EARNINGS,IMPRESSIONS,CLICKS")
        ]
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AdSenseError.analyticsFailed
        }
        
        return try JSONDecoder().decode(AdSenseAnalytics.self, from: data)
    }
    
    // MARK: - Private Methods
    private func validateAPIKey() async throws {
        let url = URL(string: "\(baseURL)/accounts")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AdSenseError.invalidAPIKey
        }
    }
    
    private func setupBannerConstraints(bannerView: AdSenseBannerView, in view: UIView) {
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func storeAdData(adUnitId: String, adData: AdSenseAdResponse) {
        UserDefaults.standard.set(try? JSONEncoder().encode(adData), forKey: "adsense_ad_\(adUnitId)")
    }
    
    private func getStoredAdData(adUnitId: String) -> AdSenseAdResponse? {
        guard let data = UserDefaults.standard.data(forKey: "adsense_ad_\(adUnitId)") else { return nil }
        return try? JSONDecoder().decode(AdSenseAdResponse.self, from: data)
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
            throw AdSenseError.revenueTrackingFailed
        }
    }
}

// MARK: - AdSenseBannerDelegate
extension AdSenseAPIManager: AdSenseBannerDelegate {
    func bannerDidLoad(_ bannerView: AdSenseBannerView) {
        DispatchQueue.main.async {
            self.adLoadStatus[bannerView.adUnitId] = .loaded
        }
    }
    
    func bannerDidFailToLoad(_ bannerView: AdSenseBannerView, error: Error) {
        DispatchQueue.main.async {
            self.adLoadStatus[bannerView.adUnitId] = .failed
        }
    }
    
    func bannerDidClick(_ bannerView: AdSenseBannerView) {
        print("AdSense banner clicked")
    }
}

// MARK: - AdSenseInterstitialDelegate
extension AdSenseAPIManager: AdSenseInterstitialDelegate {
    func interstitialDidShow(_ interstitialView: AdSenseInterstitialView) {
        print("AdSense interstitial shown")
    }
    
    func interstitialDidClose(_ interstitialView: AdSenseInterstitialView) {
        print("AdSense interstitial closed")
    }
    
    func interstitialDidClick(_ interstitialView: AdSenseInterstitialView) {
        print("AdSense interstitial clicked")
    }
}

// MARK: - AdSenseRewardedDelegate
extension AdSenseAPIManager: AdSenseRewardedDelegate {
    func rewardedDidShow(_ rewardedView: AdSenseRewardedView) {
        print("AdSense rewarded ad shown")
    }
    
    func rewardedDidClose(_ rewardedView: AdSenseRewardedView) {
        print("AdSense rewarded ad closed")
    }
    
    func rewardedDidClick(_ rewardedView: AdSenseRewardedView) {
        print("AdSense rewarded ad clicked")
    }
    
    func rewardedDidReward(_ rewardedView: AdSenseRewardedView, amount: Double) {
        print("AdSense rewarded ad rewarded: \(amount)")
        
        DispatchQueue.main.async {
            self.grantReward(for: rewardedView.adUnitId, amount: amount)
        }
    }
}

// MARK: - Reward System
extension AdSenseAPIManager {
    private func grantReward(for adUnitId: String, amount: Double) {
        let rewardAmount = getRewardAmount(for: adUnitId)
        
        Task {
            try? await updateUserRewards(amount: rewardAmount)
        }
        
        showRewardNotification(amount: rewardAmount)
    }
    
    private func getRewardAmount(for adUnitId: String) -> Double {
        return CenturiesMutualConfig.shared.adSenseRewardAmounts[adUnitId] ?? 0.01
    }
    
    private func updateUserRewards(amount: Double) async throws {
        try await SQLManager.shared.updateUserRewards(amount: amount)
    }
    
    private func showRewardNotification(amount: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Reward Earned!"
        content.body = "You earned $\(String(format: "%.2f", amount)) for watching an AdSense ad."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "adsense_reward_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Supporting Types
enum AdSenseAdSize {
    case banner
    case largeBanner
    case mediumRectangle
    case fullBanner
    case leaderboard
    case smartBanner
}

struct AdSenseAdRequest: Codable {
    let adUnitId: String
    let adType: String
    let placement: String
    let userId: String?
    let consent: Bool?
    
    enum CodingKeys: String, CodingKey {
        case adUnitId = "ad_unit_id"
        case adType = "ad_type"
        case placement
        case userId = "user_id"
        case consent
    }
}

struct AdSenseAdResponse: Codable {
    let adId: String
    let adUnitId: String
    let adType: String
    let content: AdSenseAdContent
    let tracking: AdSenseTrackingData
    
    enum CodingKeys: String, CodingKey {
        case adId = "ad_id"
        case adUnitId = "ad_unit_id"
        case adType = "ad_type"
        case content, tracking
    }
}

struct AdSenseAdContent: Codable {
    let title: String?
    let description: String?
    let imageUrl: String?
    let videoUrl: String?
    let clickUrl: String?
    let ctaText: String?
    
    enum CodingKeys: String, CodingKey {
        case title, description
        case imageUrl = "image_url"
        case videoUrl = "video_url"
        case clickUrl = "click_url"
        case ctaText = "cta_text"
    }
}

struct AdSenseTrackingData: Codable {
    let impressionUrl: String?
    let clickUrl: String?
    let completionUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case impressionUrl = "impression_url"
        case clickUrl = "click_url"
        case completionUrl = "completion_url"
    }
}

struct AdSenseAnalytics: Codable {
    let rows: [[String]]
    let totals: AdSenseTotals
    
    enum CodingKeys: String, CodingKey {
        case rows, totals
    }
}

struct AdSenseTotals: Codable {
    let earnings: Double
    let impressions: Int
    let clicks: Int
    let ctr: Double
    let rpm: Double
    
    enum CodingKeys: String, CodingKey {
        case earnings, impressions, clicks, ctr, rpm
    }
}

// MARK: - Custom Views
class AdSenseBannerView: UIView {
    let adUnitId: String
    let size: AdSenseAdSize
    weak var delegate: AdSenseBannerDelegate?
    
    init(adUnitId: String, size: AdSenseAdSize) {
        self.adUnitId = adUnitId
        self.size = size
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func loadAd() async throws {
        // Implement banner ad loading
        delegate?.bannerDidLoad(self)
    }
}

class AdSenseInterstitialView: UIView {
    let adData: AdSenseAdResponse
    weak var delegate: AdSenseInterstitialDelegate?
    
    init(adData: AdSenseAdResponse) {
        self.adData = adData
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show(in viewController: UIViewController) {
        // Implement interstitial display
        delegate?.interstitialDidShow(self)
    }
}

class AdSenseRewardedView: UIView {
    let adData: AdSenseAdResponse
    weak var delegate: AdSenseRewardedDelegate?
    
    var adUnitId: String { adData.adUnitId }
    
    init(adData: AdSenseAdResponse) {
        self.adData = adData
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show(in viewController: UIViewController) {
        // Implement rewarded ad display
        delegate?.rewardedDidShow(self)
    }
}

// MARK: - Delegates
protocol AdSenseBannerDelegate: AnyObject {
    func bannerDidLoad(_ bannerView: AdSenseBannerView)
    func bannerDidFailToLoad(_ bannerView: AdSenseBannerView, error: Error)
    func bannerDidClick(_ bannerView: AdSenseBannerView)
}

protocol AdSenseInterstitialDelegate: AnyObject {
    func interstitialDidShow(_ interstitialView: AdSenseInterstitialView)
    func interstitialDidClose(_ interstitialView: AdSenseInterstitialView)
    func interstitialDidClick(_ interstitialView: AdSenseInterstitialView)
}

protocol AdSenseRewardedDelegate: AnyObject {
    func rewardedDidShow(_ rewardedView: AdSenseRewardedView)
    func rewardedDidClose(_ rewardedView: AdSenseRewardedView)
    func rewardedDidClick(_ rewardedView: AdSenseRewardedView)
    func rewardedDidReward(_ rewardedView: AdSenseRewardedView, amount: Double)
}

enum AdSenseError: Error, LocalizedError {
    case sdkNotInitialized
    case adNotReady
    case noRootViewController
    case adLoadFailed
    case revenueTrackingFailed
    case analyticsFailed
    case invalidAPIKey
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .sdkNotInitialized:
            return "AdSense SDK is not initialized."
        case .adNotReady:
            return "Ad is not ready for display."
        case .noRootViewController:
            return "No root view controller found."
        case .adLoadFailed:
            return "Failed to load ad."
        case .revenueTrackingFailed:
            return "Failed to track ad revenue."
        case .analyticsFailed:
            return "Failed to fetch analytics data."
        case .invalidAPIKey:
            return "Invalid AdSense API key."
        case .networkError:
            return "Network error occurred while loading ads."
        }
    }
}
