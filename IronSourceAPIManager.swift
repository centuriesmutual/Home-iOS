import Foundation
import UIKit

// MARK: - IronSource API Manager
class IronSourceAPIManager: ObservableObject {
    static let shared = IronSourceAPIManager()
    
    @Published var isInitialized = false
    @Published var adRevenue: Double = 0.0
    @Published var adLoadStatus: [String: AdLoadStatus] = [:]
    
    private var appKey: String
    private var userId: String?
    
    private init() {
        self.appKey = CenturiesMutualConfig.shared.ironSourceAppKey
    }
    
    // MARK: - SDK Initialization
    func initialize() async throws {
        guard !isInitialized else { return }
        
        // Initialize IronSource SDK
        ISIntegrationHelper.validateIntegration()
        IronSource.setUserId(userId ?? UUID().uuidString)
        IronSource.initWithAppKey(appKey)
        
        // Set up delegates
        setupDelegates()
        
        self.isInitialized = true
    }
    
    // MARK: - Banner Ads (Inbox)
    func loadBannerAd(adUnitId: String, size: ISBannerSize = .banner) async throws -> ISBannerView {
        let bannerView = ISBannerView(adUnitId: adUnitId, size: size)
        bannerView.delegate = self
        
        // Add to view hierarchy for inbox
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addSubview(bannerView)
            setupBannerConstraints(bannerView: bannerView, in: window)
        }
        
        bannerView.loadAd()
        adLoadStatus[adUnitId] = .loading
        
        return bannerView
    }
    
    // MARK: - Interstitial Ads (Inbox)
    func loadInterstitialAd(adUnitId: String) async throws {
        IronSource.loadInterstitial(with: adUnitId)
        adLoadStatus[adUnitId] = .loading
    }
    
    func showInterstitialAd(adUnitId: String) async throws {
        guard IronSource.hasInterstitial(with: adUnitId) else {
            throw IronSourceError.adNotReady
        }
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            IronSource.showInterstitial(with: rootViewController, placement: adUnitId)
        } else {
            throw IronSourceError.noRootViewController
        }
    }
    
    // MARK: - Rewarded Ads (Inbox)
    func loadRewardedAd(adUnitId: String) async throws {
        IronSource.loadRewardedVideo(with: adUnitId)
        adLoadStatus[adUnitId] = .loading
    }
    
    func showRewardedAd(adUnitId: String) async throws -> Bool {
        guard IronSource.hasRewardedVideo(with: adUnitId) else {
            throw IronSourceError.adNotReady
        }
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            IronSource.showRewardedVideo(with: rootViewController, placement: adUnitId)
            return true
        } else {
            throw IronSourceError.noRootViewController
        }
    }
    
    // MARK: - Native Ads (Inbox)
    func loadNativeAd(adUnitId: String) async throws -> ISNativeAd {
        let nativeAd = ISNativeAd(adUnitId: adUnitId)
        nativeAd.delegate = self
        nativeAd.loadAd()
        adLoadStatus[adUnitId] = .loading
        return nativeAd
    }
    
    // MARK: - Revenue Tracking
    func trackRevenue(adUnitId: String, revenue: Double, currency: String = "USD") {
        adRevenue += revenue
        
        let revenueData = AdRevenueData(
            adUnitId: adUnitId,
            revenue: revenue,
            currency: currency,
            timestamp: Date(),
            adType: "IronSource",
            placement: "inbox"
        )
        
        storeRevenueData(revenueData)
        
        Task {
            try? await sendRevenueToBackend(revenueData)
        }
    }
    
    // MARK: - User Targeting
    func setUserId(_ userId: String) {
        self.userId = userId
        IronSource.setUserId(userId)
    }
    
    func setUserConsent(hasConsent: Bool) {
        IronSource.setConsent(hasConsent)
    }
    
    func setAgeRestrictedUser(isAgeRestricted: Bool) {
        IronSource.setMetaData("is_deviceid_optout", value: isAgeRestricted ? "true" : "false")
    }
    
    // MARK: - Private Methods
    private func setupDelegates() {
        IronSource.setInterstitialDelegate(self)
        IronSource.setRewardedVideoDelegate(self)
        IronSource.setBannerDelegate(self)
    }
    
    private func setupBannerConstraints(bannerView: ISBannerView, in view: UIView) {
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
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
            throw IronSourceError.revenueTrackingFailed
        }
    }
}

// MARK: - ISInterstitialDelegate
extension IronSourceAPIManager: ISInterstitialDelegate {
    func interstitialDidLoad(_ placementInfo: ISPlacementInfo!) {
        DispatchQueue.main.async {
            self.adLoadStatus[placementInfo.placementName] = .loaded
        }
    }
    
    func interstitialDidFailToLoadWithError(_ error: Error!) {
        DispatchQueue.main.async {
            // Handle error and update status
            self.adLoadStatus["interstitial"] = .failed
        }
    }
    
    func interstitialDidOpen() {
        print("IronSource interstitial opened")
    }
    
    func interstitialDidClose() {
        print("IronSource interstitial closed")
    }
    
    func interstitialDidClick() {
        print("IronSource interstitial clicked")
    }
    
    func interstitialDidShow() {
        print("IronSource interstitial shown")
    }
}

// MARK: - ISRewardedVideoDelegate
extension IronSourceAPIManager: ISRewardedVideoDelegate {
    func rewardedVideoHasChangedAvailability(_ available: Bool) {
        DispatchQueue.main.async {
            self.adLoadStatus["rewarded"] = available ? .loaded : .notLoaded
        }
    }
    
    func rewardedVideoDidOpen() {
        print("IronSource rewarded video opened")
    }
    
    func rewardedVideoDidClose() {
        print("IronSource rewarded video closed")
    }
    
    func rewardedVideoDidClick() {
        print("IronSource rewarded video clicked")
    }
    
    func rewardedVideoDidStart() {
        print("IronSource rewarded video started")
    }
    
    func rewardedVideoDidEnd() {
        print("IronSource rewarded video ended")
    }
    
    func rewardedVideoDidReward(_ placementInfo: ISPlacementInfo!) {
        print("IronSource rewarded video rewarded: \(placementInfo.placementName)")
        
        // Grant reward
        DispatchQueue.main.async {
            self.grantReward(for: placementInfo.placementName)
        }
    }
    
    func rewardedVideoDidFailToShowWithError(_ error: Error!) {
        print("IronSource rewarded video failed to show: \(error.localizedDescription)")
    }
}

// MARK: - ISBannerDelegate
extension IronSourceAPIManager: ISBannerDelegate {
    func bannerDidLoad(_ bannerView: ISBannerView!) {
        DispatchQueue.main.async {
            self.adLoadStatus[bannerView.adUnitId] = .loaded
        }
    }
    
    func bannerDidFailToLoadWithError(_ error: Error!) {
        DispatchQueue.main.async {
            self.adLoadStatus["banner"] = .failed
        }
    }
    
    func bannerDidClick() {
        print("IronSource banner clicked")
    }
    
    func bannerWillPresentScreen() {
        print("IronSource banner will present screen")
    }
    
    func bannerDidDismissScreen() {
        print("IronSource banner did dismiss screen")
    }
    
    func bannerWillLeaveApplication() {
        print("IronSource banner will leave application")
    }
}

// MARK: - ISNativeAdDelegate
extension IronSourceAPIManager: ISNativeAdDelegate {
    func nativeAdDidLoad(_ nativeAd: ISNativeAd!) {
        DispatchQueue.main.async {
            self.adLoadStatus[nativeAd.adUnitId] = .loaded
        }
    }
    
    func nativeAdDidFailToLoadWithError(_ error: Error!) {
        DispatchQueue.main.async {
            self.adLoadStatus["native"] = .failed
        }
    }
    
    func nativeAdDidClick() {
        print("IronSource native ad clicked")
    }
}

// MARK: - Reward System
extension IronSourceAPIManager {
    private func grantReward(for adUnitId: String) {
        let rewardAmount = getRewardAmount(for: adUnitId)
        
        Task {
            try? await updateUserRewards(amount: rewardAmount)
        }
        
        showRewardNotification(amount: rewardAmount)
    }
    
    private func getRewardAmount(for adUnitId: String) -> Double {
        return CenturiesMutualConfig.shared.ironSourceRewardAmounts[adUnitId] ?? 0.01
    }
    
    private func updateUserRewards(amount: Double) async throws {
        try await SQLManager.shared.updateUserRewards(amount: amount)
    }
    
    private func showRewardNotification(amount: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Reward Earned!"
        content.body = "You earned $\(String(format: "%.2f", amount)) for watching an IronSource ad."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "ironsource_reward_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

enum IronSourceError: Error, LocalizedError {
    case sdkNotInitialized
    case adNotReady
    case noRootViewController
    case revenueTrackingFailed
    case invalidAppKey
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .sdkNotInitialized:
            return "IronSource SDK is not initialized."
        case .adNotReady:
            return "Ad is not ready for display."
        case .noRootViewController:
            return "No root view controller found."
        case .revenueTrackingFailed:
            return "Failed to track ad revenue."
        case .invalidAppKey:
            return "Invalid IronSource app key."
        case .networkError:
            return "Network error occurred while loading ads."
        }
    }
}
