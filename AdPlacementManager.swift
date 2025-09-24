import Foundation
import UIKit

// MARK: - Unified Ad Placement Manager
class AdPlacementManager: ObservableObject {
    static let shared = AdPlacementManager()
    
    @Published var totalAdRevenue: Double = 0.0
    @Published var adPlacementStatus: [String: AdPlacementStatus] = [:]
    @Published var currentPlacement: AdPlacement = .inbox
    
    private var adNetworks: [AdNetworkType: AdNetworkProtocol] = [:]
    
    private init() {
        setupAdNetworks()
    }
    
    // MARK: - Initialization
    func initializeAllNetworks() async throws {
        // Initialize all ad networks
        try await AppLovinManager.shared.initialize()
        try await IronSourceAPIManager.shared.initialize()
        try await MagniteAPIManager.shared.initialize()
        try await OutbrainAPIManager.shared.initialize()
        try await QualtricsAPIManager.shared.initialize()
        try await SurveyMonkeyAPIManager.shared.initialize()
        try await TaboolaAPIManager.shared.initialize()
        try await TypeformAPIManager.shared.initialize()
        try await AdSenseAPIManager.shared.initialize()
    }
    
    // MARK: - Ad Placement for Inbox
    func loadInboxAds() async throws {
        currentPlacement = .inbox
        
        // Load ads from all inbox networks
        let inboxNetworks: [AdNetworkType] = [.ironSource, .magnite, .outbrain, .qualtrics, .surveyMonkey, .taboola, .typeform]
        
        for networkType in inboxNetworks {
            guard let network = adNetworks[networkType] else { continue }
            
            do {
                try await network.loadInboxAds()
                adPlacementStatus[networkType.rawValue] = .loaded
            } catch {
                adPlacementStatus[networkType.rawValue] = .failed
                print("Failed to load ads for \(networkType.rawValue): \(error)")
            }
        }
    }
    
    // MARK: - Ad Placement for Radio View
    func loadRadioAds() async throws {
        currentPlacement = .radio
        
        // Load ads from radio networks (AppLovin and AdSense)
        let radioNetworks: [AdNetworkType] = [.appLovin, .adSense]
        
        for networkType in radioNetworks {
            guard let network = adNetworks[networkType] else { continue }
            
            do {
                try await network.loadRadioAds()
                adPlacementStatus[networkType.rawValue] = .loaded
            } catch {
                adPlacementStatus[networkType.rawValue] = .failed
                print("Failed to load radio ads for \(networkType.rawValue): \(error)")
            }
        }
    }
    
    // MARK: - Show Ads
    func showInboxAd(networkType: AdNetworkType, adType: AdType) async throws {
        guard let network = adNetworks[networkType] else {
            throw AdPlacementError.networkNotAvailable
        }
        
        try await network.showInboxAd(adType: adType)
    }
    
    func showRadioAd(networkType: AdNetworkType, adType: AdType) async throws {
        guard let network = adNetworks[networkType] else {
            throw AdPlacementError.networkNotAvailable
        }
        
        try await network.showRadioAd(adType: adType)
    }
    
    // MARK: - Revenue Tracking
    func trackRevenue(networkType: AdNetworkType, adUnitId: String, revenue: Double, currency: String = "USD") {
        totalAdRevenue += revenue
        
        // Track revenue in the specific network
        guard let network = adNetworks[networkType] else { return }
        network.trackRevenue(adUnitId: adUnitId, revenue: revenue, currency: currency)
        
        // Store in database
        let revenueData = AdRevenueData(
            adUnitId: adUnitId,
            revenue: revenue,
            currency: currency,
            timestamp: Date(),
            adType: networkType.rawValue,
            placement: currentPlacement.rawValue
        )
        
        Task {
            try? await SQLManager.shared.insertAdRevenue(revenueData)
        }
    }
    
    // MARK: - Analytics
    func getAdAnalytics() async throws -> AdAnalytics {
        var analytics = AdAnalytics()
        
        for (networkType, network) in adNetworks {
            let networkAnalytics = try await network.getAnalytics()
            analytics.networkAnalytics[networkType] = networkAnalytics
        }
        
        return analytics
    }
    
    // MARK: - User Targeting
    func setUserConsent(hasConsent: Bool) {
        for network in adNetworks.values {
            network.setUserConsent(hasConsent: hasConsent)
        }
    }
    
    func setUserId(_ userId: String) {
        for network in adNetworks.values {
            network.setUserId(userId)
        }
    }
    
    // MARK: - Private Methods
    private func setupAdNetworks() {
        adNetworks[.appLovin] = AppLovinNetworkAdapter()
        adNetworks[.ironSource] = IronSourceNetworkAdapter()
        adNetworks[.magnite] = MagniteNetworkAdapter()
        adNetworks[.outbrain] = OutbrainNetworkAdapter()
        adNetworks[.qualtrics] = QualtricsNetworkAdapter()
        adNetworks[.surveyMonkey] = SurveyMonkeyNetworkAdapter()
        adNetworks[.taboola] = TaboolaNetworkAdapter()
        adNetworks[.typeform] = TypeformNetworkAdapter()
        adNetworks[.adSense] = AdSenseNetworkAdapter()
    }
}

// MARK: - Supporting Types
enum AdPlacement: String, CaseIterable {
    case inbox = "inbox"
    case radio = "radio"
}

enum AdNetworkType: String, CaseIterable {
    case appLovin = "AppLovin"
    case ironSource = "IronSource"
    case magnite = "Magnite"
    case outbrain = "Outbrain"
    case qualtrics = "Qualtrics"
    case surveyMonkey = "SurveyMonkey"
    case taboola = "Taboola"
    case typeform = "Typeform"
    case adSense = "AdSense"
}

enum AdPlacementStatus {
    case loading
    case loaded
    case failed
    case notLoaded
}

struct AdAnalytics {
    var networkAnalytics: [AdNetworkType: NetworkAnalytics] = [:]
    var totalRevenue: Double = 0.0
    var totalImpressions: Int = 0
    var totalClicks: Int = 0
    var averageCTR: Double = 0.0
}

struct NetworkAnalytics {
    let networkType: AdNetworkType
    let revenue: Double
    let impressions: Int
    let clicks: Int
    let ctr: Double
    let rpm: Double
    let timestamp: Date
}

// MARK: - Ad Network Protocol
protocol AdNetworkProtocol {
    func loadInboxAds() async throws
    func loadRadioAds() async throws
    func showInboxAd(adType: AdType) async throws
    func showRadioAd(adType: AdType) async throws
    func trackRevenue(adUnitId: String, revenue: Double, currency: String)
    func getAnalytics() async throws -> NetworkAnalytics
    func setUserConsent(hasConsent: Bool)
    func setUserId(_ userId: String)
}

// MARK: - Network Adapters
class AppLovinNetworkAdapter: AdNetworkProtocol {
    func loadInboxAds() async throws {
        // AppLovin can be used in both inbox and radio
        try await AppLovinManager.shared.loadInterstitialAd(adUnitId: CenturiesMutualConfig.shared.appLovinAdUnitIds.first { $0.type == .interstitial }?.id ?? "")
    }
    
    func loadRadioAds() async throws {
        try await AppLovinManager.shared.loadBannerAd(adUnitId: CenturiesMutualConfig.shared.appLovinAdUnitIds.first { $0.type == .banner }?.id ?? "")
    }
    
    func showInboxAd(adType: AdType) async throws {
        switch adType {
        case .interstitial:
            try await AppLovinManager.shared.showInterstitialAd()
        case .rewarded:
            _ = try await AppLovinManager.shared.showRewardedAd()
        default:
            break
        }
    }
    
    func showRadioAd(adType: AdType) async throws {
        switch adType {
        case .banner:
            _ = try await AppLovinManager.shared.loadBannerAd(adUnitId: CenturiesMutualConfig.shared.appLovinAdUnitIds.first { $0.type == .banner }?.id ?? "")
        case .interstitial:
            try await AppLovinManager.shared.showInterstitialAd()
        default:
            break
        }
    }
    
    func trackRevenue(adUnitId: String, revenue: Double, currency: String) {
        AppLovinManager.shared.trackRevenue(adUnitId: adUnitId, revenue: revenue, currency: currency)
    }
    
    func getAnalytics() async throws -> NetworkAnalytics {
        return NetworkAnalytics(
            networkType: .appLovin,
            revenue: AppLovinManager.shared.adRevenue,
            impressions: 0, // Implement based on AppLovin analytics
            clicks: 0,
            ctr: 0.0,
            rpm: 0.0,
            timestamp: Date()
        )
    }
    
    func setUserConsent(hasConsent: Bool) {
        AppLovinManager.shared.setUserConsent(hasConsent: hasConsent)
    }
    
    func setUserId(_ userId: String) {
        AppLovinManager.shared.setUserId(userId)
    }
}

class IronSourceNetworkAdapter: AdNetworkProtocol {
    func loadInboxAds() async throws {
        try await IronSourceAPIManager.shared.loadInterstitialAd(adUnitId: "ironsource_inbox_interstitial")
    }
    
    func loadRadioAds() async throws {
        // IronSource is primarily for inbox
        return
    }
    
    func showInboxAd(adType: AdType) async throws {
        switch adType {
        case .interstitial:
            try await IronSourceAPIManager.shared.showInterstitialAd(adUnitId: "ironsource_inbox_interstitial")
        case .rewarded:
            _ = try await IronSourceAPIManager.shared.showRewardedAd(adUnitId: "ironsource_inbox_rewarded")
        default:
            break
        }
    }
    
    func showRadioAd(adType: AdType) async throws {
        throw AdPlacementError.networkNotSupportedForPlacement
    }
    
    func trackRevenue(adUnitId: String, revenue: Double, currency: String) {
        IronSourceAPIManager.shared.trackRevenue(adUnitId: adUnitId, revenue: revenue, currency: currency)
    }
    
    func getAnalytics() async throws -> NetworkAnalytics {
        return NetworkAnalytics(
            networkType: .ironSource,
            revenue: IronSourceAPIManager.shared.adRevenue,
            impressions: 0,
            clicks: 0,
            ctr: 0.0,
            rpm: 0.0,
            timestamp: Date()
        )
    }
    
    func setUserConsent(hasConsent: Bool) {
        IronSourceAPIManager.shared.setUserConsent(hasConsent: hasConsent)
    }
    
    func setUserId(_ userId: String) {
        IronSourceAPIManager.shared.setUserId(userId)
    }
}

// Similar adapters for other networks...
class MagniteNetworkAdapter: AdNetworkProtocol {
    func loadInboxAds() async throws {
        try await MagniteAPIManager.shared.loadInterstitialAd(adUnitId: "magnite_inbox_interstitial")
    }
    
    func loadRadioAds() async throws {
        return
    }
    
    func showInboxAd(adType: AdType) async throws {
        switch adType {
        case .interstitial:
            try await MagniteAPIManager.shared.showInterstitialAd(adUnitId: "magnite_inbox_interstitial")
        default:
            break
        }
    }
    
    func showRadioAd(adType: AdType) async throws {
        throw AdPlacementError.networkNotSupportedForPlacement
    }
    
    func trackRevenue(adUnitId: String, revenue: Double, currency: String) {
        MagniteAPIManager.shared.trackRevenue(adUnitId: adUnitId, revenue: revenue, currency: currency)
    }
    
    func getAnalytics() async throws -> NetworkAnalytics {
        return NetworkAnalytics(
            networkType: .magnite,
            revenue: MagniteAPIManager.shared.adRevenue,
            impressions: 0,
            clicks: 0,
            ctr: 0.0,
            rpm: 0.0,
            timestamp: Date()
        )
    }
    
    func setUserConsent(hasConsent: Bool) {
        MagniteAPIManager.shared.setUserConsent(hasConsent: hasConsent)
    }
    
    func setUserId(_ userId: String) {
        // Magnite doesn't have setUserId method
    }
}

class OutbrainNetworkAdapter: AdNetworkProtocol {
    func loadInboxAds() async throws {
        try await OutbrainAPIManager.shared.loadInterstitialAd(adUnitId: "outbrain_inbox_interstitial")
    }
    
    func loadRadioAds() async throws {
        return
    }
    
    func showInboxAd(adType: AdType) async throws {
        switch adType {
        case .interstitial:
            try await OutbrainAPIManager.shared.showInterstitialAd(adUnitId: "outbrain_inbox_interstitial")
        default:
            break
        }
    }
    
    func showRadioAd(adType: AdType) async throws {
        throw AdPlacementError.networkNotSupportedForPlacement
    }
    
    func trackRevenue(adUnitId: String, revenue: Double, currency: String) {
        OutbrainAPIManager.shared.trackRevenue(adUnitId: adUnitId, revenue: revenue, currency: currency)
    }
    
    func getAnalytics() async throws -> NetworkAnalytics {
        return NetworkAnalytics(
            networkType: .outbrain,
            revenue: OutbrainAPIManager.shared.adRevenue,
            impressions: 0,
            clicks: 0,
            ctr: 0.0,
            rpm: 0.0,
            timestamp: Date()
        )
    }
    
    func setUserConsent(hasConsent: Bool) {
        OutbrainAPIManager.shared.setUserConsent(hasConsent: hasConsent)
    }
    
    func setUserId(_ userId: String) {
        OutbrainAPIManager.shared.setUserId(userId)
    }
}

class QualtricsNetworkAdapter: AdNetworkProtocol {
    func loadInboxAds() async throws {
        _ = try await QualtricsAPIManager.shared.loadSurveyAd(adUnitId: "qualtrics_inbox_survey")
    }
    
    func loadRadioAds() async throws {
        return
    }
    
    func showInboxAd(adType: AdType) async throws {
        // Qualtrics shows surveys, not traditional ads
        return
    }
    
    func showRadioAd(adType: AdType) async throws {
        throw AdPlacementError.networkNotSupportedForPlacement
    }
    
    func trackRevenue(adUnitId: String, revenue: Double, currency: String) {
        QualtricsAPIManager.shared.trackRevenue(adUnitId: adUnitId, revenue: revenue, currency: currency)
    }
    
    func getAnalytics() async throws -> NetworkAnalytics {
        return NetworkAnalytics(
            networkType: .qualtrics,
            revenue: QualtricsAPIManager.shared.adRevenue,
            impressions: 0,
            clicks: 0,
            ctr: 0.0,
            rpm: 0.0,
            timestamp: Date()
        )
    }
    
    func setUserConsent(hasConsent: Bool) {
        // Qualtrics doesn't have setUserConsent method
    }
    
    func setUserId(_ userId: String) {
        // Qualtrics doesn't have setUserId method
    }
}

class SurveyMonkeyNetworkAdapter: AdNetworkProtocol {
    func loadInboxAds() async throws {
        _ = try await SurveyMonkeyAPIManager.shared.loadSurveyAd(adUnitId: "surveymonkey_inbox_survey")
    }
    
    func loadRadioAds() async throws {
        return
    }
    
    func showInboxAd(adType: AdType) async throws {
        // SurveyMonkey shows surveys, not traditional ads
        return
    }
    
    func showRadioAd(adType: AdType) async throws {
        throw AdPlacementError.networkNotSupportedForPlacement
    }
    
    func trackRevenue(adUnitId: String, revenue: Double, currency: String) {
        SurveyMonkeyAPIManager.shared.trackRevenue(adUnitId: adUnitId, revenue: revenue, currency: currency)
    }
    
    func getAnalytics() async throws -> NetworkAnalytics {
        return NetworkAnalytics(
            networkType: .surveyMonkey,
            revenue: SurveyMonkeyAPIManager.shared.adRevenue,
            impressions: 0,
            clicks: 0,
            ctr: 0.0,
            rpm: 0.0,
            timestamp: Date()
        )
    }
    
    func setUserConsent(hasConsent: Bool) {
        // SurveyMonkey doesn't have setUserConsent method
    }
    
    func setUserId(_ userId: String) {
        // SurveyMonkey doesn't have setUserId method
    }
}

class TaboolaNetworkAdapter: AdNetworkProtocol {
    func loadInboxAds() async throws {
        try await TaboolaAPIManager.shared.loadInterstitialAd(adUnitId: "taboola_inbox_interstitial")
    }
    
    func loadRadioAds() async throws {
        return
    }
    
    func showInboxAd(adType: AdType) async throws {
        switch adType {
        case .interstitial:
            try await TaboolaAPIManager.shared.showInterstitialAd(adUnitId: "taboola_inbox_interstitial")
        default:
            break
        }
    }
    
    func showRadioAd(adType: AdType) async throws {
        throw AdPlacementError.networkNotSupportedForPlacement
    }
    
    func trackRevenue(adUnitId: String, revenue: Double, currency: String) {
        TaboolaAPIManager.shared.trackRevenue(adUnitId: adUnitId, revenue: revenue, currency: currency)
    }
    
    func getAnalytics() async throws -> NetworkAnalytics {
        return NetworkAnalytics(
            networkType: .taboola,
            revenue: TaboolaAPIManager.shared.adRevenue,
            impressions: 0,
            clicks: 0,
            ctr: 0.0,
            rpm: 0.0,
            timestamp: Date()
        )
    }
    
    func setUserConsent(hasConsent: Bool) {
        // Taboola doesn't have setUserConsent method
    }
    
    func setUserId(_ userId: String) {
        // Taboola doesn't have setUserId method
    }
}

class TypeformNetworkAdapter: AdNetworkProtocol {
    func loadInboxAds() async throws {
        _ = try await TypeformAPIManager.shared.loadFormAd(adUnitId: "typeform_inbox_form")
    }
    
    func loadRadioAds() async throws {
        return
    }
    
    func showInboxAd(adType: AdType) async throws {
        // Typeform shows forms, not traditional ads
        return
    }
    
    func showRadioAd(adType: AdType) async throws {
        throw AdPlacementError.networkNotSupportedForPlacement
    }
    
    func trackRevenue(adUnitId: String, revenue: Double, currency: String) {
        TypeformAPIManager.shared.trackRevenue(adUnitId: adUnitId, revenue: revenue, currency: currency)
    }
    
    func getAnalytics() async throws -> NetworkAnalytics {
        return NetworkAnalytics(
            networkType: .typeform,
            revenue: TypeformAPIManager.shared.adRevenue,
            impressions: 0,
            clicks: 0,
            ctr: 0.0,
            rpm: 0.0,
            timestamp: Date()
        )
    }
    
    func setUserConsent(hasConsent: Bool) {
        // Typeform doesn't have setUserConsent method
    }
    
    func setUserId(_ userId: String) {
        // Typeform doesn't have setUserId method
    }
}

class AdSenseNetworkAdapter: AdNetworkProtocol {
    func loadInboxAds() async throws {
        // AdSense is primarily for radio view
        return
    }
    
    func loadRadioAds() async throws {
        try await AdSenseAPIManager.shared.loadBannerAd(adUnitId: "adsense_radio_banner")
    }
    
    func showInboxAd(adType: AdType) async throws {
        throw AdPlacementError.networkNotSupportedForPlacement
    }
    
    func showRadioAd(adType: AdType) async throws {
        switch adType {
        case .banner:
            _ = try await AdSenseAPIManager.shared.loadBannerAd(adUnitId: "adsense_radio_banner")
        case .interstitial:
            try await AdSenseAPIManager.shared.showInterstitialAd(adUnitId: "adsense_radio_interstitial")
        case .rewarded:
            _ = try await AdSenseAPIManager.shared.showRewardedAd(adUnitId: "adsense_radio_rewarded")
        default:
            break
        }
    }
    
    func trackRevenue(adUnitId: String, revenue: Double, currency: String) {
        AdSenseAPIManager.shared.trackRevenue(adUnitId: adUnitId, revenue: revenue, currency: currency)
    }
    
    func getAnalytics() async throws -> NetworkAnalytics {
        return NetworkAnalytics(
            networkType: .adSense,
            revenue: AdSenseAPIManager.shared.adRevenue,
            impressions: 0,
            clicks: 0,
            ctr: 0.0,
            rpm: 0.0,
            timestamp: Date()
        )
    }
    
    func setUserConsent(hasConsent: Bool) {
        // AdSense doesn't have setUserConsent method
    }
    
    func setUserId(_ userId: String) {
        // AdSense doesn't have setUserId method
    }
}

enum AdPlacementError: Error, LocalizedError {
    case networkNotAvailable
    case networkNotSupportedForPlacement
    case adNotReady
    case initializationFailed
    
    var errorDescription: String? {
        switch self {
        case .networkNotAvailable:
            return "Ad network is not available."
        case .networkNotSupportedForPlacement:
            return "This ad network is not supported for the specified placement."
        case .adNotReady:
            return "Ad is not ready for display."
        case .initializationFailed:
            return "Failed to initialize ad networks."
        }
    }
}
