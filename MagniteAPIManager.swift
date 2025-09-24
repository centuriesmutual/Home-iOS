import Foundation
import UIKit

// MARK: - Magnite API Manager
class MagniteAPIManager: ObservableObject {
    static let shared = MagniteAPIManager()
    
    @Published var isInitialized = false
    @Published var adRevenue: Double = 0.0
    @Published var adLoadStatus: [String: AdLoadStatus] = [:]
    
    private var apiKey: String
    private var baseURL = "https://api.magnite.com/v1"
    
    private init() {
        self.apiKey = CenturiesMutualConfig.shared.magniteAPIKey
    }
    
    // MARK: - SDK Initialization
    func initialize() async throws {
        guard !isInitialized else { return }
        
        // Initialize Magnite SDK
        try await validateAPIKey()
        self.isInitialized = true
    }
    
    // MARK: - Banner Ads (Inbox)
    func loadBannerAd(adUnitId: String, size: MagniteAdSize = .banner) async throws -> MagniteBannerView {
        let bannerView = MagniteBannerView(adUnitId: adUnitId, size: size)
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
        
        let adRequest = MagniteAdRequest(
            adUnitId: adUnitId,
            adType: "interstitial",
            placement: "inbox"
        )
        
        request.httpBody = try JSONEncoder().encode(adRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MagniteError.adLoadFailed
        }
        
        let adResponse = try JSONDecoder().decode(MagniteAdResponse.self, from: data)
        adLoadStatus[adUnitId] = .loaded
        
        // Store ad data for later display
        storeAdData(adUnitId: adUnitId, adData: adResponse)
    }
    
    func showInterstitialAd(adUnitId: String) async throws {
        guard let adData = getStoredAdData(adUnitId: adUnitId) else {
            throw MagniteError.adNotReady
        }
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            let interstitialView = MagniteInterstitialView(adData: adData)
            interstitialView.delegate = self
            interstitialView.show(in: rootViewController)
        } else {
            throw MagniteError.noRootViewController
        }
    }
    
    // MARK: - Rewarded Ads (Inbox)
    func loadRewardedAd(adUnitId: String) async throws {
        let url = URL(string: "\(baseURL)/ads/rewarded")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let adRequest = MagniteAdRequest(
            adUnitId: adUnitId,
            adType: "rewarded",
            placement: "inbox"
        )
        
        request.httpBody = try JSONEncoder().encode(adRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MagniteError.adLoadFailed
        }
        
        let adResponse = try JSONDecoder().decode(MagniteAdResponse.self, from: data)
        adLoadStatus[adUnitId] = .loaded
        
        storeAdData(adUnitId: adUnitId, adData: adResponse)
    }
    
    func showRewardedAd(adUnitId: String) async throws -> Bool {
        guard let adData = getStoredAdData(adUnitId: adUnitId) else {
            throw MagniteError.adNotReady
        }
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            let rewardedView = MagniteRewardedView(adData: adData)
            rewardedView.delegate = self
            rewardedView.show(in: rootViewController)
            return true
        } else {
            throw MagniteError.noRootViewController
        }
    }
    
    // MARK: - Native Ads (Inbox)
    func loadNativeAd(adUnitId: String) async throws -> MagniteNativeAd {
        let url = URL(string: "\(baseURL)/ads/native")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let adRequest = MagniteAdRequest(
            adUnitId: adUnitId,
            adType: "native",
            placement: "inbox"
        )
        
        request.httpBody = try JSONEncoder().encode(adRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MagniteError.adLoadFailed
        }
        
        let adResponse = try JSONDecoder().decode(MagniteAdResponse.self, from: data)
        adLoadStatus[adUnitId] = .loaded
        
        return MagniteNativeAd(adData: adResponse, delegate: self)
    }
    
    // MARK: - Revenue Tracking
    func trackRevenue(adUnitId: String, revenue: Double, currency: String = "USD") {
        adRevenue += revenue
        
        let revenueData = AdRevenueData(
            adUnitId: adUnitId,
            revenue: revenue,
            currency: currency,
            timestamp: Date(),
            adType: "Magnite",
            placement: "inbox"
        )
        
        storeRevenueData(revenueData)
        
        Task {
            try? await sendRevenueToBackend(revenueData)
        }
    }
    
    // MARK: - User Targeting
    func setUserConsent(hasConsent: Bool) {
        // Magnite consent handling
        let consentData = MagniteConsentData(hasConsent: hasConsent)
        storeConsentData(consentData)
    }
    
    func setUserId(_ userId: String) {
        let userData = MagniteUserData(userId: userId)
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
            throw MagniteError.invalidAPIKey
        }
    }
    
    private func setupBannerConstraints(bannerView: MagniteBannerView, in view: UIView) {
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func storeAdData(adUnitId: String, adData: MagniteAdResponse) {
        // Store ad data in memory or local storage
        UserDefaults.standard.set(try? JSONEncoder().encode(adData), forKey: "magnite_ad_\(adUnitId)")
    }
    
    private func getStoredAdData(adUnitId: String) -> MagniteAdResponse? {
        guard let data = UserDefaults.standard.data(forKey: "magnite_ad_\(adUnitId)") else { return nil }
        return try? JSONDecoder().decode(MagniteAdResponse.self, from: data)
    }
    
    private func storeConsentData(_ consentData: MagniteConsentData) {
        UserDefaults.standard.set(try? JSONEncoder().encode(consentData), forKey: "magnite_consent")
    }
    
    private func storeUserData(_ userData: MagniteUserData) {
        UserDefaults.standard.set(try? JSONEncoder().encode(userData), forKey: "magnite_user")
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
            throw MagniteError.revenueTrackingFailed
        }
    }
}

// MARK: - MagniteBannerDelegate
extension MagniteAPIManager: MagniteBannerDelegate {
    func bannerDidLoad(_ bannerView: MagniteBannerView) {
        DispatchQueue.main.async {
            self.adLoadStatus[bannerView.adUnitId] = .loaded
        }
    }
    
    func bannerDidFailToLoad(_ bannerView: MagniteBannerView, error: Error) {
        DispatchQueue.main.async {
            self.adLoadStatus[bannerView.adUnitId] = .failed
        }
    }
    
    func bannerDidClick(_ bannerView: MagniteBannerView) {
        print("Magnite banner clicked")
    }
}

// MARK: - MagniteInterstitialDelegate
extension MagniteAPIManager: MagniteInterstitialDelegate {
    func interstitialDidShow(_ interstitialView: MagniteInterstitialView) {
        print("Magnite interstitial shown")
    }
    
    func interstitialDidClose(_ interstitialView: MagniteInterstitialView) {
        print("Magnite interstitial closed")
    }
    
    func interstitialDidClick(_ interstitialView: MagniteInterstitialView) {
        print("Magnite interstitial clicked")
    }
}

// MARK: - MagniteRewardedDelegate
extension MagniteAPIManager: MagniteRewardedDelegate {
    func rewardedDidShow(_ rewardedView: MagniteRewardedView) {
        print("Magnite rewarded ad shown")
    }
    
    func rewardedDidClose(_ rewardedView: MagniteRewardedView) {
        print("Magnite rewarded ad closed")
    }
    
    func rewardedDidClick(_ rewardedView: MagniteRewardedView) {
        print("Magnite rewarded ad clicked")
    }
    
    func rewardedDidReward(_ rewardedView: MagniteRewardedView, amount: Double) {
        print("Magnite rewarded ad rewarded: \(amount)")
        
        DispatchQueue.main.async {
            self.grantReward(for: rewardedView.adUnitId, amount: amount)
        }
    }
}

// MARK: - MagniteNativeDelegate
extension MagniteAPIManager: MagniteNativeDelegate {
    func nativeAdDidLoad(_ nativeAd: MagniteNativeAd) {
        DispatchQueue.main.async {
            self.adLoadStatus[nativeAd.adUnitId] = .loaded
        }
    }
    
    func nativeAdDidFailToLoad(_ nativeAd: MagniteNativeAd, error: Error) {
        DispatchQueue.main.async {
            self.adLoadStatus[nativeAd.adUnitId] = .failed
        }
    }
    
    func nativeAdDidClick(_ nativeAd: MagniteNativeAd) {
        print("Magnite native ad clicked")
    }
}

// MARK: - Reward System
extension MagniteAPIManager {
    private func grantReward(for adUnitId: String, amount: Double) {
        let rewardAmount = getRewardAmount(for: adUnitId)
        
        Task {
            try? await updateUserRewards(amount: rewardAmount)
        }
        
        showRewardNotification(amount: rewardAmount)
    }
    
    private func getRewardAmount(for adUnitId: String) -> Double {
        return CenturiesMutualConfig.shared.magniteRewardAmounts[adUnitId] ?? 0.01
    }
    
    private func updateUserRewards(amount: Double) async throws {
        try await SQLManager.shared.updateUserRewards(amount: amount)
    }
    
    private func showRewardNotification(amount: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Reward Earned!"
        content.body = "You earned $\(String(format: "%.2f", amount)) for watching a Magnite ad."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "magnite_reward_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Supporting Types
enum MagniteAdSize {
    case banner
    case largeBanner
    case mediumRectangle
    case fullBanner
    case leaderboard
    case smartBanner
}

struct MagniteAdRequest: Codable {
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

struct MagniteAdResponse: Codable {
    let adId: String
    let adUnitId: String
    let adType: String
    let content: MagniteAdContent
    let tracking: MagniteTrackingData
    
    enum CodingKeys: String, CodingKey {
        case adId = "ad_id"
        case adUnitId = "ad_unit_id"
        case adType = "ad_type"
        case content, tracking
    }
}

struct MagniteAdContent: Codable {
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

struct MagniteTrackingData: Codable {
    let impressionUrl: String?
    let clickUrl: String?
    let completionUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case impressionUrl = "impression_url"
        case clickUrl = "click_url"
        case completionUrl = "completion_url"
    }
}

struct MagniteConsentData: Codable {
    let hasConsent: Bool
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case hasConsent = "has_consent"
        case timestamp
    }
}

struct MagniteUserData: Codable {
    let userId: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case timestamp
    }
}

// MARK: - Custom Views
class MagniteBannerView: UIView {
    let adUnitId: String
    let size: MagniteAdSize
    weak var delegate: MagniteBannerDelegate?
    
    init(adUnitId: String, size: MagniteAdSize) {
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

class MagniteInterstitialView: UIView {
    let adData: MagniteAdResponse
    weak var delegate: MagniteInterstitialDelegate?
    
    init(adData: MagniteAdResponse) {
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

class MagniteRewardedView: UIView {
    let adData: MagniteAdResponse
    weak var delegate: MagniteRewardedDelegate?
    
    var adUnitId: String { adData.adUnitId }
    
    init(adData: MagniteAdResponse) {
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

class MagniteNativeAd: NSObject {
    let adData: MagniteAdResponse
    weak var delegate: MagniteNativeDelegate?
    
    var adUnitId: String { adData.adUnitId }
    
    init(adData: MagniteAdResponse, delegate: MagniteNativeDelegate) {
        self.adData = adData
        self.delegate = delegate
        super.init()
        delegate.nativeAdDidLoad(self)
    }
}

// MARK: - Delegates
protocol MagniteBannerDelegate: AnyObject {
    func bannerDidLoad(_ bannerView: MagniteBannerView)
    func bannerDidFailToLoad(_ bannerView: MagniteBannerView, error: Error)
    func bannerDidClick(_ bannerView: MagniteBannerView)
}

protocol MagniteInterstitialDelegate: AnyObject {
    func interstitialDidShow(_ interstitialView: MagniteInterstitialView)
    func interstitialDidClose(_ interstitialView: MagniteInterstitialView)
    func interstitialDidClick(_ interstitialView: MagniteInterstitialView)
}

protocol MagniteRewardedDelegate: AnyObject {
    func rewardedDidShow(_ rewardedView: MagniteRewardedView)
    func rewardedDidClose(_ rewardedView: MagniteRewardedView)
    func rewardedDidClick(_ rewardedView: MagniteRewardedView)
    func rewardedDidReward(_ rewardedView: MagniteRewardedView, amount: Double)
}

protocol MagniteNativeDelegate: AnyObject {
    func nativeAdDidLoad(_ nativeAd: MagniteNativeAd)
    func nativeAdDidFailToLoad(_ nativeAd: MagniteNativeAd, error: Error)
    func nativeAdDidClick(_ nativeAd: MagniteNativeAd)
}

enum MagniteError: Error, LocalizedError {
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
            return "Magnite SDK is not initialized."
        case .adNotReady:
            return "Ad is not ready for display."
        case .noRootViewController:
            return "No root view controller found."
        case .adLoadFailed:
            return "Failed to load ad."
        case .revenueTrackingFailed:
            return "Failed to track ad revenue."
        case .invalidAPIKey:
            return "Invalid Magnite API key."
        case .networkError:
            return "Network error occurred while loading ads."
        }
    }
}
