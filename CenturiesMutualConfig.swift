import Foundation

// MARK: - App Configuration Manager
class CenturiesMutualConfig {
    static let shared = CenturiesMutualConfig()
    
    // Circle API Configuration
    struct CircleConfig {
        static let sandboxAPIKey = "YOUR_CIRCLE_SANDBOX_API_KEY"
        static let productionAPIKey = "YOUR_CIRCLE_PRODUCTION_API_KEY"
        static let adminWalletId = "YOUR_ADMIN_WALLET_ID"
        static let edwardJonesAccountId = "YOUR_EDWARD_JONES_ACCOUNT_ID"
        
        // Interest and earning rates
        static let annualInterestRate = 0.045 // 4.5% APY
        static let surveyEarningAmount = 5.0
        static let workoutBaseEarning = 2.0
        static let workoutBonusEarning = 1.0
        static let referralEarning = 10.0
        static let engagementEarning = 1.0
        
        // Risk management limits
        static let maxDailyWithdrawal = 5000.0
        static let maxMonthlyWithdrawal = 50000.0
        static let maxSingleTransaction = 1000.0
        static let minWithdrawalAmount = 10.0
        static let approvalThreshold = 500.0
    }
    
    // Coinbase Integration
    struct CoinbaseConfig {
        static let clientId = "YOUR_COINBASE_CLIENT_ID"
        static let clientSecret = "YOUR_COINBASE_CLIENT_SECRET"
        static let redirectURI = "centuriesmutual://coinbase-auth"
        static let scopes = ["wallet:user:read", "wallet:accounts:read", "wallet:transactions:send"]
    }
    
    // Robinhood Integration
    struct RobinhoodConfig {
        static let clientId = "YOUR_ROBINHOOD_CLIENT_ID"
        static let clientSecret = "YOUR_ROBINHOOD_CLIENT_SECRET"
        static let redirectURI = "centuriesmutual://robinhood-auth"
    }
    
    // Dropbox Advanced Configuration
    struct DropboxConfig {
        static let accessToken = "YOUR_DROPBOX_ACCESS_TOKEN"
        static let baseURL = "https://api.dropboxapi.com/2"
        static let clientID = "YOUR_DROPBOX_CLIENT_ID"
        static let clientSecret = "YOUR_DROPBOX_CLIENT_SECRET"
    }
    
    // Keycloak Configuration (Linode hosted)
    struct KeycloakConfig {
        static let baseURL = "https://your-linode-server.com:8080"
        static let realm = "centuries-mutual"
        static let clientID = "centuries-mutual-ios"
        static let clientSecret = "YOUR_KEYCLOAK_CLIENT_SECRET"
    }
    
    // Marketplace Finder API Configuration
    struct MarketplaceConfig {
        static let apiKey = "YOUR_MARKETPLACE_API_KEY"
        static let baseURL = "https://api.healthcare.gov"
    }
    
    // CMS Medicare API Configuration
    struct CMSConfig {
        static let apiKey = "YOUR_CMS_API_KEY"
        static let baseURL = "https://data.cms.gov/api/v1"
    }
    
    // YouTube API Configuration
    struct YouTubeConfig {
        static let apiKey = "YOUR_YOUTUBE_API_KEY"
        static let baseURL = "https://www.googleapis.com/youtube/v3"
    }
    
    // AppLovin Configuration
    struct AppLovinConfig {
        static let sdkKey = "YOUR_APPLOVIN_SDK_KEY"
        static let adUnitIds: [AdUnit] = [
            AdUnit(id: "YOUR_BANNER_AD_UNIT_ID", type: .banner, name: "Banner Ad"),
            AdUnit(id: "YOUR_INTERSTITIAL_AD_UNIT_ID", type: .interstitial, name: "Interstitial Ad"),
            AdUnit(id: "YOUR_REWARDED_AD_UNIT_ID", type: .rewarded, name: "Rewarded Ad"),
            AdUnit(id: "YOUR_NATIVE_AD_UNIT_ID", type: .native, name: "Native Ad")
        ]
        static let rewardAmounts: [String: Double] = [
            "YOUR_REWARDED_AD_UNIT_ID": 0.01,
            "YOUR_INTERSTITIAL_AD_UNIT_ID": 0.005
        ]
    }
    
    // IronSource Configuration
    struct IronSourceConfig {
        static let appKey = "YOUR_IRONSOURCE_APP_KEY"
        static let rewardAmounts: [String: Double] = [
            "ironsource_inbox_interstitial": 0.01,
            "ironsource_inbox_rewarded": 0.02
        ]
    }
    
    // Magnite Configuration
    struct MagniteConfig {
        static let apiKey = "YOUR_MAGNITE_API_KEY"
        static let rewardAmounts: [String: Double] = [
            "magnite_inbox_interstitial": 0.01,
            "magnite_inbox_banner": 0.005
        ]
    }
    
    // Outbrain Configuration
    struct OutbrainConfig {
        static let apiKey = "YOUR_OUTBRAIN_API_KEY"
        static let rewardAmounts: [String: Double] = [
            "outbrain_inbox_interstitial": 0.01,
            "outbrain_inbox_native": 0.005
        ]
    }
    
    // Qualtrics Configuration
    struct QualtricsConfig {
        static let apiKey = "YOUR_QUALTRICS_API_KEY"
        static let rewardAmounts: [String: Double] = [
            "qualtrics_inbox_survey": 0.05
        ]
    }
    
    // Survey Monkey Configuration
    struct SurveyMonkeyConfig {
        static let apiKey = "YOUR_SURVEYMONKEY_API_KEY"
        static let rewardAmounts: [String: Double] = [
            "surveymonkey_inbox_survey": 0.05
        ]
    }
    
    // Taboola Configuration
    struct TaboolaConfig {
        static let apiKey = "YOUR_TABOOLA_API_KEY"
        static let rewardAmounts: [String: Double] = [
            "taboola_inbox_interstitial": 0.01,
            "taboola_inbox_native": 0.005
        ]
    }
    
    // Typeform Configuration
    struct TypeformConfig {
        static let apiKey = "YOUR_TYPEFORM_API_KEY"
        static let rewardAmounts: [String: Double] = [
            "typeform_inbox_form": 0.05
        ]
    }
    
    // AdSense Configuration
    struct AdSenseConfig {
        static let apiKey = "YOUR_ADSENSE_API_KEY"
        static let rewardAmounts: [String: Double] = [
            "adsense_radio_banner": 0.01,
            "adsense_radio_interstitial": 0.02,
            "adsense_radio_rewarded": 0.03
        ]
    }
    
    // Linode Hosting Configuration
    struct LinodeConfig {
        static let baseURL = "https://your-linode-server.com"
        static let backendAPIKey = "YOUR_BACKEND_API_KEY"
    }
    
    private init() {}
    
    func getCurrentAPIKey() -> String {
        #if DEBUG
        return CircleConfig.sandboxAPIKey
        #else
        return CircleConfig.productionAPIKey
        #endif
    }
}

// MARK: - Supporting Types
enum AdType {
    case banner
    case interstitial
    case rewarded
    case native
}

struct AdUnit {
    let id: String
    let type: AdType
    let name: String
}

// MARK: - Configuration Extensions for Easy Access
extension CenturiesMutualConfig {
    // Dropbox
    static var dropboxClientID: String { DropboxConfig.clientID }
    static var dropboxClientSecret: String { DropboxConfig.clientSecret }
    
    // Keycloak
    static var keycloakBaseURL: String { KeycloakConfig.baseURL }
    static var keycloakRealm: String { KeycloakConfig.realm }
    static var keycloakClientID: String { KeycloakConfig.clientID }
    static var keycloakClientSecret: String { KeycloakConfig.clientSecret }
    
    // Marketplace
    static var marketplaceAPIKey: String { MarketplaceConfig.apiKey }
    
    // CMS
    static var cmsAPIKey: String { CMSConfig.apiKey }
    
    // YouTube
    static var youtubeAPIKey: String { YouTubeConfig.apiKey }
    
    // AppLovin
    static var appLovinSDKKey: String { AppLovinConfig.sdkKey }
    static var appLovinAdUnitIds: [AdUnit] { AppLovinConfig.adUnitIds }
    static var appLovinRewardAmounts: [String: Double] { AppLovinConfig.rewardAmounts }
    
    // IronSource
    static var ironSourceAppKey: String { IronSourceConfig.appKey }
    static var ironSourceRewardAmounts: [String: Double] { IronSourceConfig.rewardAmounts }
    
    // Magnite
    static var magniteAPIKey: String { MagniteConfig.apiKey }
    static var magniteRewardAmounts: [String: Double] { MagniteConfig.rewardAmounts }
    
    // Outbrain
    static var outbrainAPIKey: String { OutbrainConfig.apiKey }
    static var outbrainRewardAmounts: [String: Double] { OutbrainConfig.rewardAmounts }
    
    // Qualtrics
    static var qualtricsAPIKey: String { QualtricsConfig.apiKey }
    static var qualtricsRewardAmounts: [String: Double] { QualtricsConfig.rewardAmounts }
    
    // Survey Monkey
    static var surveyMonkeyAPIKey: String { SurveyMonkeyConfig.apiKey }
    static var surveyMonkeyRewardAmounts: [String: Double] { SurveyMonkeyConfig.rewardAmounts }
    
    // Taboola
    static var taboolaAPIKey: String { TaboolaConfig.apiKey }
    static var taboolaRewardAmounts: [String: Double] { TaboolaConfig.rewardAmounts }
    
    // Typeform
    static var typeformAPIKey: String { TypeformConfig.apiKey }
    static var typeformRewardAmounts: [String: Double] { TypeformConfig.rewardAmounts }
    
    // AdSense
    static var adSenseAPIKey: String { AdSenseConfig.apiKey }
    static var adSenseRewardAmounts: [String: Double] { AdSenseConfig.rewardAmounts }
    
    // Linode
    static var linodeBaseURL: String { LinodeConfig.baseURL }
    static var backendAPIKey: String { LinodeConfig.backendAPIKey }
}
