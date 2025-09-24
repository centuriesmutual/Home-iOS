import Foundation
import UIKit

// MARK: - AppLovin Integration Manager
class AppLovinManager: ObservableObject {
    static let shared = AppLovinManager()
    
    @Published var isInitialized = false
    @Published var adRevenue: Double = 0.0
    @Published var adLoadStatus: [String: AdLoadStatus] = [:]
    
    private var sdkKey: String
    private var interstitialAd: ALInterstitialAd?
    private var rewardedAd: ALRewardedAd?
    private var bannerAd: ALAdView?
    
    private init() {
        self.sdkKey = CenturiesMutualConfig.shared.appLovinSDKKey
    }
    
    // MARK: - SDK Initialization
    func initialize() async throws {
        guard !isInitialized else { return }
        
        // Initialize AppLovin SDK
        ALSdk.shared()?.mediationProvider = "max"
        ALSdk.shared()?.initialize(with: sdkKey) { (configuration: ALSdkConfiguration) in
            DispatchQueue.main.async {
                self.isInitialized = true
            }
        }
        
        // Set up mediation callbacks
        setupMediationCallbacks()
        
        // Preload ads
        try await preloadAds()
    }
    
    // MARK: - Banner Ads
    func loadBannerAd(
        adUnitId: String,
        size: ALAdSize = .banner,
        position: BannerPosition = .bottom
    ) async throws -> ALAdView {
        let bannerAd = ALAdView(size: size, sdk: ALSdk.shared())
        bannerAd.adUnitId = adUnitId
        bannerAd.delegate = self
        
        // Add to view hierarchy
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addSubview(bannerAd)
            setupBannerConstraints(bannerAd: bannerAd, position: position, in: window)
        }
        
        bannerAd.loadAd()
        self.bannerAd = bannerAd
        
        return bannerAd
    }
    
    func hideBannerAd() {
        bannerAd?.isHidden = true
    }
    
    func showBannerAd() {
        bannerAd?.isHidden = false
    }
    
    func removeBannerAd() {
        bannerAd?.removeFromSuperview()
        bannerAd = nil
    }
    
    // MARK: - Interstitial Ads
    func loadInterstitialAd(adUnitId: String) async throws {
        interstitialAd = ALInterstitialAd(sdk: ALSdk.shared())
        interstitialAd?.adLoadDelegate = self
        interstitialAd?.adDisplayDelegate = self
        interstitialAd?.adUnitId = adUnitId
        
        interstitialAd?.load()
        adLoadStatus[adUnitId] = .loading
    }
    
    func showInterstitialAd() async throws {
        guard let ad = interstitialAd, ad.isReadyForDisplay else {
            throw AppLovinError.adNotReady
        }
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            ad.show()
        } else {
            throw AppLovinError.noRootViewController
        }
    }
    
    // MARK: - Rewarded Ads
    func loadRewardedAd(adUnitId: String) async throws {
        rewardedAd = ALRewardedAd.shared(with: ALSdk.shared())
        rewardedAd?.adLoadDelegate = self
        rewardedAd?.adDisplayDelegate = self
        rewardedAd?.adVideoPlaybackDelegate = self
        rewardedAd?.adUnitId = adUnitId
        
        rewardedAd?.load()
        adLoadStatus[adUnitId] = .loading
    }
    
    func showRewardedAd() async throws -> Bool {
        guard let ad = rewardedAd, ad.isReadyForDisplay else {
            throw AppLovinError.adNotReady
        }
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            ad.show()
            return true
        } else {
            throw AppLovinError.noRootViewController
        }
    }
    
    // MARK: - Native Ads
    func loadNativeAd(adUnitId: String) async throws -> ALNativeAd {
        let nativeAd = ALNativeAd(sdk: ALSdk.shared())
        nativeAd.adUnitId = adUnitId
        nativeAd.delegate = self
        
        nativeAd.load()
        adLoadStatus[adUnitId] = .loading
        
        return nativeAd
    }
    
    // MARK: - Revenue Tracking
    func trackRevenue(adUnitId: String, revenue: Double, currency: String = "USD") {
        adRevenue += revenue
        
        // Track with analytics
        let revenueData = AdRevenueData(
            adUnitId: adUnitId,
            revenue: revenue,
            currency: currency,
            timestamp: Date()
        )
        
        // Store revenue data
        storeRevenueData(revenueData)
        
        // Send to backend if needed
        Task {
            try? await sendRevenueToBackend(revenueData)
        }
    }
    
    // MARK: - Ad Targeting
    func setUserConsent(hasConsent: Bool) {
        ALPrivacySettings.setHasUserConsent(hasConsent)
    }
    
    func setAgeRestrictedUser(isAgeRestricted: Bool) {
        ALPrivacySettings.setIsAgeRestrictedUser(isAgeRestricted)
    }
    
    func setDoNotSell(doNotSell: Bool) {
        ALPrivacySettings.setDoNotSell(doNotSell)
    }
    
    func setUserId(userId: String) {
        ALSdk.shared()?.userIdentifier = userId
    }
    
    func setKeywords(keywords: [String]) {
        ALSdk.shared()?.targetingData.setKeywords(keywords)
    }
    
    func setInterests(interests: [String]) {
        ALSdk.shared()?.targetingData.setInterests(interests)
    }
    
    // MARK: - Private Methods
    private func setupMediationCallbacks() {
        // Set up mediation callbacks for better ad performance
        ALSdk.shared()?.mediationProvider = "max"
    }
    
    private func preloadAds() async throws {
        // Preload common ad units
        let commonAdUnits = CenturiesMutualConfig.shared.appLovinAdUnitIds
        
        for adUnit in commonAdUnits {
            switch adUnit.type {
            case .interstitial:
                try await loadInterstitialAd(adUnitId: adUnit.id)
            case .rewarded:
                try await loadRewardedAd(adUnitId: adUnit.id)
            case .banner:
                try await loadBannerAd(adUnitId: adUnit.id)
            case .native:
                try await loadNativeAd(adUnitId: adUnit.id)
            }
        }
    }
    
    private func setupBannerConstraints(bannerAd: ALAdView, position: BannerPosition, in view: UIView) {
        bannerAd.translatesAutoresizingMaskIntoConstraints = false
        
        switch position {
        case .top:
            NSLayoutConstraint.activate([
                bannerAd.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                bannerAd.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bannerAd.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        case .bottom:
            NSLayoutConstraint.activate([
                bannerAd.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                bannerAd.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bannerAd.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }
    }
    
    private func storeRevenueData(_ data: AdRevenueData) {
        // Store in local database
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
            throw AppLovinError.revenueTrackingFailed
        }
    }
}

// MARK: - ALAdLoadDelegate
extension AppLovinManager: ALAdLoadDelegate {
    func adService(_ adService: ALAdService, didLoad ad: ALAd) {
        DispatchQueue.main.async {
            self.adLoadStatus[ad.adUnitId] = .loaded
        }
    }
    
    func adService(_ adService: ALAdService, didFailToLoadAdWithError code: Int) {
        DispatchQueue.main.async {
            self.adLoadStatus[adService.adUnitId] = .failed
        }
    }
}

// MARK: - ALAdDisplayDelegate
extension AppLovinManager: ALAdDisplayDelegate {
    func ad(_ ad: ALAd, wasDisplayedIn view: UIView) {
        // Track ad display
        print("Ad displayed: \(ad.adUnitId)")
    }
    
    func ad(_ ad: ALAd, wasHiddenIn view: UIView) {
        // Track ad hidden
        print("Ad hidden: \(ad.adUnitId)")
    }
    
    func ad(_ ad: ALAd, wasClickedIn view: UIView) {
        // Track ad click
        print("Ad clicked: \(ad.adUnitId)")
    }
}

// MARK: - ALAdVideoPlaybackDelegate
extension AppLovinManager: ALAdVideoPlaybackDelegate {
    func videoPlaybackBegan(in ad: ALAd) {
        print("Video playback began: \(ad.adUnitId)")
    }
    
    func videoPlaybackEnded(in ad: ALAd, atPlaybackPercent percentPlayed: NSNumber, wasFullyWatched wasFullyWatched: Bool) {
        print("Video playback ended: \(ad.adUnitId), \(percentPlayed)% watched, fully watched: \(wasFullyWatched)")
        
        if wasFullyWatched {
            // Grant reward
            DispatchQueue.main.async {
                self.grantReward(for: ad.adUnitId)
            }
        }
    }
}

// MARK: - ALAdViewDelegate
extension AppLovinManager: ALAdViewDelegate {
    func adView(_ adView: ALAdView, didLoad ad: ALAd) {
        DispatchQueue.main.async {
            self.adLoadStatus[adView.adUnitId] = .loaded
        }
    }
    
    func adView(_ adView: ALAdView, didFailToLoadAdWithError code: Int) {
        DispatchQueue.main.async {
            self.adLoadStatus[adView.adUnitId] = .failed
        }
    }
    
    func adView(_ adView: ALAdView, didDisplay ad: ALAd) {
        print("Banner ad displayed: \(adView.adUnitId)")
    }
    
    func adView(_ adView: ALAdView, didHide ad: ALAd) {
        print("Banner ad hidden: \(adView.adUnitId)")
    }
    
    func adView(_ adView: ALAdView, didClick ad: ALAd) {
        print("Banner ad clicked: \(adView.adUnitId)")
    }
}

// MARK: - ALNativeAdDelegate
extension AppLovinManager: ALNativeAdDelegate {
    func nativeAd(_ nativeAd: ALNativeAd, didLoad ad: ALAd) {
        DispatchQueue.main.async {
            self.adLoadStatus[nativeAd.adUnitId] = .loaded
        }
    }
    
    func nativeAd(_ nativeAd: ALNativeAd, didFailToLoadAdWithError code: Int) {
        DispatchQueue.main.async {
            self.adLoadStatus[nativeAd.adUnitId] = .failed
        }
    }
}

// MARK: - Supporting Types
enum AdLoadStatus {
    case loading
    case loaded
    case failed
    case notLoaded
}

enum BannerPosition {
    case top
    case bottom
}

struct AdRevenueData: Codable {
    let adUnitId: String
    let revenue: Double
    let currency: String
    let timestamp: Date
    let adType: String
    let placement: String?
    
    enum CodingKeys: String, CodingKey {
        case adUnitId = "ad_unit_id"
        case revenue, currency, timestamp
        case adType = "ad_type"
        case placement
    }
}

enum AppLovinError: Error, LocalizedError {
    case sdkNotInitialized
    case adNotReady
    case noRootViewController
    case revenueTrackingFailed
    case invalidAdUnitId
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .sdkNotInitialized:
            return "AppLovin SDK is not initialized."
        case .adNotReady:
            return "Ad is not ready for display."
        case .noRootViewController:
            return "No root view controller found."
        case .revenueTrackingFailed:
            return "Failed to track ad revenue."
        case .invalidAdUnitId:
            return "Invalid ad unit ID."
        case .networkError:
            return "Network error occurred while loading ads."
        }
    }
}

// MARK: - Reward System
extension AppLovinManager {
    private func grantReward(for adUnitId: String) {
        // Grant reward based on ad unit
        let rewardAmount = getRewardAmount(for: adUnitId)
        
        // Update user's reward balance
        Task {
            try? await updateUserRewards(amount: rewardAmount)
        }
        
        // Show reward notification
        showRewardNotification(amount: rewardAmount)
    }
    
    private func getRewardAmount(for adUnitId: String) -> Double {
        // Return reward amount based on ad unit configuration
        return CenturiesMutualConfig.shared.appLovinRewardAmounts[adUnitId] ?? 0.01
    }
    
    private func updateUserRewards(amount: Double) async throws {
        // Update user's reward balance in the database
        try await SQLManager.shared.updateUserRewards(amount: amount)
    }
    
    private func showRewardNotification(amount: Double) {
        // Show local notification for reward
        let content = UNMutableNotificationContent()
        content.title = "Reward Earned!"
        content.body = "You earned $\(String(format: "%.2f", amount)) for watching an ad."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "reward_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - SQLManager Extension for Ad Revenue
extension SQLManager {
    func insertAdRevenue(_ data: AdRevenueData) async throws {
        let query = """
            INSERT INTO ad_revenue (ad_unit_id, revenue, currency, timestamp, ad_type, placement)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        
        try await executeQuery(query, parameters: [
            data.adUnitId,
            data.revenue,
            data.currency,
            data.timestamp,
            data.adType,
            data.placement ?? ""
        ])
    }
    
    func updateUserRewards(amount: Double) async throws {
        let query = """
            UPDATE users SET reward_balance = reward_balance + ? WHERE id = ?
        """
        
        // Get current user ID (you'll need to implement this)
        let userId = getCurrentUserId() // Implement this method
        
        try await executeQuery(query, parameters: [amount, userId])
    }
    
    private func getCurrentUserId() -> String {
        // Implement this to get the current user's ID
        return "current_user_id"
    }
}
