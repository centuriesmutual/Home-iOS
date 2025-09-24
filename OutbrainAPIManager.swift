import Foundation
import UIKit

// MARK: - Outbrain API Manager
class OutbrainAPIManager: ObservableObject {
    static let shared = OutbrainAPIManager()
    
    @Published var isInitialized = false
    @Published var adRevenue: Double = 0.0
    @Published var adLoadStatus: [String: AdLoadStatus] = [:]
    
    private var apiKey: String
    private var baseURL = "https://api.outbrain.com/v1"
    
    private init() {
        self.apiKey = CenturiesMutualConfig.shared.outbrainAPIKey
    }
    
    // MARK: - SDK Initialization
    func initialize() async throws {
        guard !isInitialized else { return }
        
        // Initialize Outbrain SDK
        try await validateAPIKey()
        self.isInitialized = true
    }
    
    // MARK: - Banner Ads (Inbox)
    func loadBannerAd(adUnitId: String, size: OutbrainAdSize = .banner) async throws -> OutbrainBannerView {
        let bannerView = OutbrainBannerView(adUnitId: adUnitId, size: size)
        bannerView.delegate = self
        
        // Add to view hierarchy for inbox
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addSubview(bannerView)
            setupBannerConstraints(bannerView: bannerView, in: window)
        }
        
        try await bannerView.loadAd()
        adLoadStatus[adUnitId] = .loading
        
        return bannerView
    }
    
    // MARK: - Interstitial Ads (Inbox)
    func loadInterstitialAd(adUnitId: String) async throws {
        let url = URL(string: "\(baseURL)/ads/interstitial")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let adRequest = OutbrainAdRequest(
            adUnitId: adUnitId,
            adType: "interstitial",
            placement: "inbox"
        )
        
        request.httpBody = try JSONEncoder().encode(adRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OutbrainError.adLoadFailed
        }
        
        let adResponse = try JSONDecoder().decode(OutbrainAdResponse.self, from: data)
        adLoadStatus[adUnitId] = .loaded
        
        storeAdData(adUnitId: adUnitId, adData: adResponse)
    }
    
    func showInterstitialAd(adUnitId: String) async throws {
        guard let adData = getStoredAdData(adUnitId: adUnitId) else {
            throw OutbrainError.adNotReady
        }
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            let interstitialView = OutbrainInterstitialView(adData: adData)
            interstitialView.delegate = self
            interstitialView.show(in: rootViewController)
        } else {
            throw OutbrainError.noRootViewController
        }
    }
    
    // MARK: - Rewarded Ads (Inbox)
    func loadRewardedAd(adUnitId: String) async throws {
        let url = URL(string: "\(baseURL)/ads/rewarded")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let adRequest = OutbrainAdRequest(
            adUnitId: adUnitId,
            adType: "rewarded",
            placement: "inbox"
        )
        
        request.httpBody = try JSONEncoder().encode(adRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OutbrainError.adLoadFailed
        }
        
        let adResponse = try JSONDecoder().decode(OutbrainAdResponse.self, from: data)
        adLoadStatus[adUnitId] = .loaded
        
        storeAdData(adUnitId: adUnitId, adData: adResponse)
    }
    
    func showRewardedAd(adUnitId: String) async throws -> Bool {
        guard let adData = getStoredAdData(adUnitId: adUnitId) else {
            throw OutbrainError.adNotReady
        }
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            let rewardedView = OutbrainRewardedView(adData: adData)
            rewardedView.delegate = self
            rewardedView.show(in: rootViewController)
            return true
        } else {
            throw OutbrainError.noRootViewController
        }
    }
    
    // MARK: - Native Ads (Inbox)
    func loadNativeAd(adUnitId: String) async throws -> OutbrainNativeAd {
        let url = URL(string: "\(baseURL)/ads/native")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let adRequest = OutbrainAdRequest(
            adUnitId: adUnitId,
            adType: "native",
            placement: "inbox"
        )
        
        request.httpBody = try JSONEncoder().encode(adRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OutbrainError.adLoadFailed
        }
        
        let adResponse = try JSONDecoder().decode(OutbrainAdResponse.self, from: data)
        adLoadStatus[adUnitId] = .loaded
        
        return OutbrainNativeAd(adData: adResponse, delegate: self)
    }
    
    // MARK: - Revenue Tracking
    func trackRevenue(adUnitId: String, revenue: Double, currency: String = "USD") {
        adRevenue += revenue
        
        let revenueData = AdRevenueData(
            adUnitId: adUnitId,
            revenue: revenue,
            currency: currency,
            timestamp: Date(),
            adType: "Outbrain",
            placement: "inbox"
        )
        
        storeRevenueData(revenueData)
        
        Task {
            try? await sendRevenueToBackend(revenueData)
        }
    }
    
    // MARK: - User Targeting
    func setUserConsent(hasConsent: Bool) {
        let consentData = OutbrainConsentData(hasConsent: hasConsent)
        storeConsentData(consentData)
    }
    
    func setUserId(_ userId: String) {
        let userData = OutbrainUserData(userId: userId)
        storeUserData(userData)
    }
    
    // MARK: - Private Methods
    private func validateAPIKey() async throws {
        let url = URL(string: "\(baseURL)/auth/validate")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OutbrainError.invalidAPIKey
        }
    }
    
    private func setupBannerConstraints(bannerView: OutbrainBannerView, in view: UIView) {
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func storeAdData(adUnitId: String, adData: OutbrainAdResponse) {
        UserDefaults.standard.set(try? JSONEncoder().encode(adData), forKey: "outbrain_ad_\(adUnitId)")
    }
    
    private func getStoredAdData(adUnitId: String) -> OutbrainAdResponse? {
        guard let data = UserDefaults.standard.data(forKey: "outbrain_ad_\(adUnitId)") else { return nil }
        return try? JSONDecoder().decode(OutbrainAdResponse.self, from: data)
    }
    
    private func storeConsentData(_ consentData: OutbrainConsentData) {
        UserDefaults.standard.set(try? JSONEncoder().encode(consentData), forKey: "outbrain_consent")
    }
    
    private func storeUserData(_ userData: OutbrainUserData) {
        UserDefaults.standard.set(try? JSONEncoder().encode(userData), forKey: "outbrain_user")
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
            throw OutbrainError.revenueTrackingFailed
        }
    }
}

// MARK: - OutbrainBannerDelegate
extension OutbrainAPIManager: OutbrainBannerDelegate {
    func bannerDidLoad(_ bannerView: OutbrainBannerView) {
        DispatchQueue.main.async {
            self.adLoadStatus[bannerView.adUnitId] = .loaded
        }
    }
    
    func bannerDidFailToLoad(_ bannerView: OutbrainBannerView, error: Error) {
        DispatchQueue.main.async {
            self.adLoadStatus[bannerView.adUnitId] = .failed
        }
    }
    
    func bannerDidClick(_ bannerView: OutbrainBannerView) {
        print("Outbrain banner clicked")
    }
}

// MARK: - OutbrainInterstitialDelegate
extension OutbrainAPIManager: OutbrainInterstitialDelegate {
    func interstitialDidShow(_ interstitialView: OutbrainInterstitialView) {
        print("Outbrain interstitial shown")
    }
    
    func interstitialDidClose(_ interstitialView: OutbrainInterstitialView) {
        print("Outbrain interstitial closed")
    }
    
    func interstitialDidClick(_ interstitialView: OutbrainInterstitialView) {
        print("Outbrain interstitial clicked")
    }
}

// MARK: - OutbrainRewardedDelegate
extension OutbrainAPIManager: OutbrainRewardedDelegate {
    func rewardedDidShow(_ rewardedView: OutbrainRewardedView) {
        print("Outbrain rewarded ad shown")
    }
    
    func rewardedDidClose(_ rewardedView: OutbrainRewardedView) {
        print("Outbrain rewarded ad closed")
    }
    
    func rewardedDidClick(_ rewardedView: OutbrainRewardedView) {
        print("Outbrain rewarded ad clicked")
    }
    
    func rewardedDidReward(_ rewardedView: OutbrainRewardedView, amount: Double) {
        print("Outbrain rewarded ad rewarded: \(amount)")
        
        DispatchQueue.main.async {
            self.grantReward(for: rewardedView.adUnitId, amount: amount)
        }
    }
}

// MARK: - OutbrainNativeDelegate
extension OutbrainAPIManager: OutbrainNativeDelegate {
    func nativeAdDidLoad(_ nativeAd: OutbrainNativeAd) {
        DispatchQueue.main.async {
            self.adLoadStatus[nativeAd.adUnitId] = .loaded
        }
    }
    
    func nativeAdDidFailToLoad(_ nativeAd: OutbrainNativeAd, error: Error) {
        DispatchQueue.main.async {
            self.adLoadStatus[nativeAd.adUnitId] = .failed
        }
    }
    
    func nativeAdDidClick(_ nativeAd: OutbrainNativeAd) {
        print("Outbrain native ad clicked")
    }
}

// MARK: - Reward System
extension OutbrainAPIManager {
    private func grantReward(for adUnitId: String, amount: Double) {
        let rewardAmount = getRewardAmount(for: adUnitId)
        
        Task {
            try? await updateUserRewards(amount: rewardAmount)
        }
        
        showRewardNotification(amount: rewardAmount)
    }
    
    private func getRewardAmount(for adUnitId: String) -> Double {
        return CenturiesMutualConfig.shared.outbrainRewardAmounts[adUnitId] ?? 0.01
    }
    
    private func updateUserRewards(amount: Double) async throws {
        try await SQLManager.shared.updateUserRewards(amount: amount)
    }
    
    private func showRewardNotification(amount: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Reward Earned!"
        content.body = "You earned $\(String(format: "%.2f", amount)) for watching an Outbrain ad."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "outbrain_reward_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Supporting Types
enum OutbrainAdSize {
    case banner
    case largeBanner
    case mediumRectangle
    case fullBanner
    case leaderboard
    case smartBanner
}

struct OutbrainAdRequest: Codable {
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

struct OutbrainAdResponse: Codable {
    let adId: String
    let adUnitId: String
    let adType: String
    let content: OutbrainAdContent
    let tracking: OutbrainTrackingData
    
    enum CodingKeys: String, CodingKey {
        case adId = "ad_id"
        case adUnitId = "ad_unit_id"
        case adType = "ad_type"
        case content, tracking
    }
}

struct OutbrainAdContent: Codable {
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

struct OutbrainTrackingData: Codable {
    let impressionUrl: String?
    let clickUrl: String?
    let completionUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case impressionUrl = "impression_url"
        case clickUrl = "click_url"
        case completionUrl = "completion_url"
    }
}

struct OutbrainConsentData: Codable {
    let hasConsent: Bool
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case hasConsent = "has_consent"
        case timestamp
    }
}

struct OutbrainUserData: Codable {
    let userId: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case timestamp
    }
}

// MARK: - Custom Views
class OutbrainBannerView: UIView {
    let adUnitId: String
    let size: OutbrainAdSize
    weak var delegate: OutbrainBannerDelegate?
    
    init(adUnitId: String, size: OutbrainAdSize) {
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

class OutbrainInterstitialView: UIView {
    let adData: OutbrainAdResponse
    weak var delegate: OutbrainInterstitialDelegate?
    
    init(adData: OutbrainAdResponse) {
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

class OutbrainRewardedView: UIView {
    let adData: OutbrainAdResponse
    weak var delegate: OutbrainRewardedDelegate?
    
    var adUnitId: String { adData.adUnitId }
    
    init(adData: OutbrainAdResponse) {
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

class OutbrainNativeAd: NSObject {
    let adData: OutbrainAdResponse
    weak var delegate: OutbrainNativeDelegate?
    
    var adUnitId: String { adData.adUnitId }
    
    init(adData: OutbrainAdResponse, delegate: OutbrainNativeDelegate) {
        self.adData = adData
        self.delegate = delegate
        super.init()
        delegate.nativeAdDidLoad(self)
    }
}

// MARK: - Delegates
protocol OutbrainBannerDelegate: AnyObject {
    func bannerDidLoad(_ bannerView: OutbrainBannerView)
    func bannerDidFailToLoad(_ bannerView: OutbrainBannerView, error: Error)
    func bannerDidClick(_ bannerView: OutbrainBannerView)
}

protocol OutbrainInterstitialDelegate: AnyObject {
    func interstitialDidShow(_ interstitialView: OutbrainInterstitialView)
    func interstitialDidClose(_ interstitialView: OutbrainInterstitialView)
    func interstitialDidClick(_ interstitialView: OutbrainInterstitialView)
}

protocol OutbrainRewardedDelegate: AnyObject {
    func rewardedDidShow(_ rewardedView: OutbrainRewardedView)
    func rewardedDidClose(_ rewardedView: OutbrainRewardedView)
    func rewardedDidClick(_ rewardedView: OutbrainRewardedView)
    func rewardedDidReward(_ rewardedView: OutbrainRewardedView, amount: Double)
}

protocol OutbrainNativeDelegate: AnyObject {
    func nativeAdDidLoad(_ nativeAd: OutbrainNativeAd)
    func nativeAdDidFailToLoad(_ nativeAd: OutbrainNativeAd, error: Error)
    func nativeAdDidClick(_ nativeAd: OutbrainNativeAd)
}

enum OutbrainError: Error, LocalizedError {
    case sdkNotInitialized
    case adNotReady
    case noRootViewController
    case adLoadFailed
    case revenueTrackingFailed
    case invalidAPIKey
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .sdkNotInitialized:
            return "Outbrain SDK is not initialized."
        case .adNotReady:
            return "Ad is not ready for display."
        case .noRootViewController:
            return "No root view controller found."
        case .adLoadFailed:
            return "Failed to load ad."
        case .revenueTrackingFailed:
            return "Failed to track ad revenue."
        case .invalidAPIKey:
            return "Invalid Outbrain API key."
        case .networkError:
            return "Network error occurred while loading ads."
        }
    }
}
