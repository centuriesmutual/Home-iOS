import Foundation
import UIKit

// MARK: - Taboola API Manager
class TaboolaAPIManager: ObservableObject {
    static let shared = TaboolaAPIManager()
    
    @Published var isInitialized = false
    @Published var adRevenue: Double = 0.0
    @Published var adLoadStatus: [String: AdLoadStatus] = [:]
    
    private var apiKey: String
    private var baseURL = "https://api.taboola.com/v1"
    
    private init() {
        self.apiKey = CenturiesMutualConfig.shared.taboolaAPIKey
    }
    
    // MARK: - SDK Initialization
    func initialize() async throws {
        guard !isInitialized else { return }
        try await validateAPIKey()
        self.isInitialized = true
    }
    
    // MARK: - Banner Ads (Inbox)
    func loadBannerAd(adUnitId: String, size: TaboolaAdSize = .banner) async throws -> TaboolaBannerView {
        let bannerView = TaboolaBannerView(adUnitId: adUnitId, size: size)
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
        
        let adRequest = TaboolaAdRequest(
            adUnitId: adUnitId,
            adType: "interstitial",
            placement: "inbox"
        )
        
        request.httpBody = try JSONEncoder().encode(adRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TaboolaError.adLoadFailed
        }
        
        let adResponse = try JSONDecoder().decode(TaboolaAdResponse.self, from: data)
        adLoadStatus[adUnitId] = .loaded
        
        storeAdData(adUnitId: adUnitId, adData: adResponse)
    }
    
    func showInterstitialAd(adUnitId: String) async throws {
        guard let adData = getStoredAdData(adUnitId: adUnitId) else {
            throw TaboolaError.adNotReady
        }
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            let interstitialView = TaboolaInterstitialView(adData: adData)
            interstitialView.delegate = self
            interstitialView.show(in: rootViewController)
        } else {
            throw TaboolaError.noRootViewController
        }
    }
    
    // MARK: - Native Ads (Inbox)
    func loadNativeAd(adUnitId: String) async throws -> TaboolaNativeAd {
        let url = URL(string: "\(baseURL)/ads/native")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let adRequest = TaboolaAdRequest(
            adUnitId: adUnitId,
            adType: "native",
            placement: "inbox"
        )
        
        request.httpBody = try JSONEncoder().encode(adRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TaboolaError.adLoadFailed
        }
        
        let adResponse = try JSONDecoder().decode(TaboolaAdResponse.self, from: data)
        adLoadStatus[adUnitId] = .loaded
        
        return TaboolaNativeAd(adData: adResponse, delegate: self)
    }
    
    // MARK: - Revenue Tracking
    func trackRevenue(adUnitId: String, revenue: Double, currency: String = "USD") {
        adRevenue += revenue
        
        let revenueData = AdRevenueData(
            adUnitId: adUnitId,
            revenue: revenue,
            currency: currency,
            timestamp: Date(),
            adType: "Taboola",
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
            throw TaboolaError.invalidAPIKey
        }
    }
    
    private func setupBannerConstraints(bannerView: TaboolaBannerView, in view: UIView) {
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func storeAdData(adUnitId: String, adData: TaboolaAdResponse) {
        UserDefaults.standard.set(try? JSONEncoder().encode(adData), forKey: "taboola_ad_\(adUnitId)")
    }
    
    private func getStoredAdData(adUnitId: String) -> TaboolaAdResponse? {
        guard let data = UserDefaults.standard.data(forKey: "taboola_ad_\(adUnitId)") else { return nil }
        return try? JSONDecoder().decode(TaboolaAdResponse.self, from: data)
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
            throw TaboolaError.revenueTrackingFailed
        }
    }
}

// MARK: - TaboolaBannerDelegate
extension TaboolaAPIManager: TaboolaBannerDelegate {
    func bannerDidLoad(_ bannerView: TaboolaBannerView) {
        DispatchQueue.main.async {
            self.adLoadStatus[bannerView.adUnitId] = .loaded
        }
    }
    
    func bannerDidFailToLoad(_ bannerView: TaboolaBannerView, error: Error) {
        DispatchQueue.main.async {
            self.adLoadStatus[bannerView.adUnitId] = .failed
        }
    }
    
    func bannerDidClick(_ bannerView: TaboolaBannerView) {
        print("Taboola banner clicked")
    }
}

// MARK: - TaboolaInterstitialDelegate
extension TaboolaAPIManager: TaboolaInterstitialDelegate {
    func interstitialDidShow(_ interstitialView: TaboolaInterstitialView) {
        print("Taboola interstitial shown")
    }
    
    func interstitialDidClose(_ interstitialView: TaboolaInterstitialView) {
        print("Taboola interstitial closed")
    }
    
    func interstitialDidClick(_ interstitialView: TaboolaInterstitialView) {
        print("Taboola interstitial clicked")
    }
}

// MARK: - TaboolaNativeDelegate
extension TaboolaAPIManager: TaboolaNativeDelegate {
    func nativeAdDidLoad(_ nativeAd: TaboolaNativeAd) {
        DispatchQueue.main.async {
            self.adLoadStatus[nativeAd.adUnitId] = .loaded
        }
    }
    
    func nativeAdDidFailToLoad(_ nativeAd: TaboolaNativeAd, error: Error) {
        DispatchQueue.main.async {
            self.adLoadStatus[nativeAd.adUnitId] = .failed
        }
    }
    
    func nativeAdDidClick(_ nativeAd: TaboolaNativeAd) {
        print("Taboola native ad clicked")
    }
}

// MARK: - Supporting Types
enum TaboolaAdSize {
    case banner
    case largeBanner
    case mediumRectangle
    case fullBanner
    case leaderboard
    case smartBanner
}

struct TaboolaAdRequest: Codable {
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

struct TaboolaAdResponse: Codable {
    let adId: String
    let adUnitId: String
    let adType: String
    let content: TaboolaAdContent
    let tracking: TaboolaTrackingData
    
    enum CodingKeys: String, CodingKey {
        case adId = "ad_id"
        case adUnitId = "ad_unit_id"
        case adType = "ad_type"
        case content, tracking
    }
}

struct TaboolaAdContent: Codable {
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

struct TaboolaTrackingData: Codable {
    let impressionUrl: String?
    let clickUrl: String?
    let completionUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case impressionUrl = "impression_url"
        case clickUrl = "click_url"
        case completionUrl = "completion_url"
    }
}

// MARK: - Custom Views
class TaboolaBannerView: UIView {
    let adUnitId: String
    let size: TaboolaAdSize
    weak var delegate: TaboolaBannerDelegate?
    
    init(adUnitId: String, size: TaboolaAdSize) {
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

class TaboolaInterstitialView: UIView {
    let adData: TaboolaAdResponse
    weak var delegate: TaboolaInterstitialDelegate?
    
    init(adData: TaboolaAdResponse) {
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

class TaboolaNativeAd: NSObject {
    let adData: TaboolaAdResponse
    weak var delegate: TaboolaNativeDelegate?
    
    var adUnitId: String { adData.adUnitId }
    
    init(adData: TaboolaAdResponse, delegate: TaboolaNativeDelegate) {
        self.adData = adData
        self.delegate = delegate
        super.init()
        delegate.nativeAdDidLoad(self)
    }
}

// MARK: - Delegates
protocol TaboolaBannerDelegate: AnyObject {
    func bannerDidLoad(_ bannerView: TaboolaBannerView)
    func bannerDidFailToLoad(_ bannerView: TaboolaBannerView, error: Error)
    func bannerDidClick(_ bannerView: TaboolaBannerView)
}

protocol TaboolaInterstitialDelegate: AnyObject {
    func interstitialDidShow(_ interstitialView: TaboolaInterstitialView)
    func interstitialDidClose(_ interstitialView: TaboolaInterstitialView)
    func interstitialDidClick(_ interstitialView: TaboolaInterstitialView)
}

protocol TaboolaNativeDelegate: AnyObject {
    func nativeAdDidLoad(_ nativeAd: TaboolaNativeAd)
    func nativeAdDidFailToLoad(_ nativeAd: TaboolaNativeAd, error: Error)
    func nativeAdDidClick(_ nativeAd: TaboolaNativeAd)
}

enum TaboolaError: Error, LocalizedError {
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
            return "Taboola SDK is not initialized."
        case .adNotReady:
            return "Ad is not ready for display."
        case .noRootViewController:
            return "No root view controller found."
        case .adLoadFailed:
            return "Failed to load ad."
        case .revenueTrackingFailed:
            return "Failed to track ad revenue."
        case .invalidAPIKey:
            return "Invalid Taboola API key."
        case .networkError:
            return "Network error occurred while loading ads."
        }
    }
}
