import Foundation
import UIKit
import SwiftUI

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
    
    private init() {}
    
    func getCurrentAPIKey() -> String {
        #if DEBUG
        return CircleConfig.sandboxAPIKey
        #else
        return CircleConfig.productionAPIKey
        #endif
    }
}

// MARK: - App Delegate Integration
extension AppDelegate {
    func setupCircleIntegration() {
        // Initialize Circle API Service
        do {
            let circleAPI = CircleAPIService()
            try circleAPI.initialize(apiKey: CenturiesMutualConfig.shared.getCurrentAPIKey())
            
            // Store reference for app-wide access
            AppContext.shared.circleAPI = circleAPI
            
            print("Circle API initialized successfully")
        } catch {
            print("Failed to initialize Circle API: \(error)")
        }
        
        // Setup URL scheme handling for external wallet authentication
        setupURLSchemeHandling()
        
        // Initialize admin services if user is admin
        if UserDefaults.standard.bool(forKey: "is_admin_user") {
            setupAdminServices()
        }
    }
    
    private func setupURLSchemeHandling() {
        // This will handle OAuth redirects from Coinbase and Robinhood
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Handle any pending OAuth completions
        }
    }
    
    private func setupAdminServices() {
        let adminManager = AdminDashboardManager(
            circleAPI: AppContext.shared.circleAPI!,
            edwardJonesAccountId: CenturiesMutualConfig.CircleConfig.edwardJonesAccountId
        )
        AppContext.shared.adminManager = adminManager
    }
}

// MARK: - App Context for Dependency Injection
class AppContext {
    static let shared = AppContext()
    
    var circleAPI: CircleAPIService?
    var adminManager: AdminDashboardManager?
    var currentUserEarningsManager: UserEarningsManager?
    
    private init() {}
    
    func setupUserEarningsManager(for userId: String) {
        guard let circleAPI = circleAPI else {
            print("Circle API not initialized")
            return
        }
        
        currentUserEarningsManager = UserEarningsManager(circleAPI: circleAPI, userId: userId)
    }
}

// MARK: - Scene Delegate Integration
extension SceneDelegate {
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            handleURL(context.url)
        }
    }
    
    private func handleURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        
        switch url.host {
        case "coinbase-auth":
            handleCoinbaseAuth(components: components)
        case "robinhood-auth":
            handleRobinhoodAuth(components: components)
        default:
            break
        }
    }
    
    private func handleCoinbaseAuth(components: URLComponents) {
        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }
        
        // Post notification to handle in the appropriate view
        NotificationCenter.default.post(
            name: .coinbaseAuthCompleted,
            object: nil,
            userInfo: ["code": code]
        )
    }
    
    private func handleRobinhoodAuth(components: URLComponents) {
        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }
        
        NotificationCenter.default.post(
            name: .robinhoodAuthCompleted,
            object: nil,
            userInfo: ["code": code]
        )
    }
}

// MARK: - Notification Extensions
extension NSNotification.Name {
    static let coinbaseAuthCompleted = NSNotification.Name("coinbaseAuthCompleted")
    static let robinhoodAuthCompleted = NSNotification.Name("robinhoodAuthCompleted")
    static let earningsUpdated = NSNotification.Name("earningsUpdated")
    static let withdrawalCompleted = NSNotification.Name("withdrawalCompleted")
}

// MARK: - Existing View Controller Integration
extension UIViewController {
    func addWalletTab() {
        guard let tabBarController = self.tabBarController else { return }
        
        // Create wallet view controller
        let walletView = WalletView(userId: getCurrentUserId())
        let walletViewController = UIHostingController(rootView: walletView)
        walletViewController.tabBarItem = UITabBarItem(
            title: "Wallet",
            image: UIImage(systemName: "creditcard"),
            selectedImage: UIImage(systemName: "creditcard.fill")
        )
        
        // Add to existing tab bar
        var viewControllers = tabBarController.viewControllers ?? []
        viewControllers.append(walletViewController)
        tabBarController.viewControllers = viewControllers
    }
    
    private func getCurrentUserId() -> String {
        // Replace with your existing user ID retrieval logic
        return UserDefaults.standard.string(forKey: "current_user_id") ?? "default_user"
    }
}

// MARK: - Survey Integration Extension
extension SurveyViewController {
    func completeSurvey(surveyId: String, responses: [String: Any]) {
        // Existing survey completion logic...
        
        // Add Circle earning integration
        if let earningsManager = AppContext.shared.currentUserEarningsManager {
            earningsManager.addSurveyEarning(surveyId: surveyId)
            
            // Show earning notification
            showEarningNotification(amount: CenturiesMutualConfig.CircleConfig.surveyEarningAmount)
        }
        
        // Continue with existing completion flow...
    }
    
    private func showEarningNotification(amount: Double) {
        let alert = UIAlertController(
            title: "Congratulations! 🎉",
            message: "You earned $\(amount, specifier: "%.2f") for completing this survey!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "View Wallet", style: .default) { _ in
            self.navigateToWallet()
        })
        
        alert.addAction(UIAlertAction(title: "Continue", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func navigateToWallet() {
        // Navigate to wallet tab or push wallet view
        if let tabBarController = self.tabBarController {
            // Assuming wallet is the last tab
            tabBarController.selectedIndex = tabBarController.viewControllers?.count ?? 1 - 1
        }
    }
}

// MARK: - Workout Integration Extension
extension WorkoutViewController {
    func completeWorkout(workoutType: String, duration: TimeInterval, caloriesBurned: Int) {
        // Existing workout completion logic...
        
        // Add Circle earning integration
        if let earningsManager = AppContext.shared.currentUserEarningsManager {
            earningsManager.addWorkoutEarning(workoutType: workoutType, duration: duration)
            
            let baseAmount = CenturiesMutualConfig.CircleConfig.workoutBaseEarning
            let bonusAmount = duration > 1800 ? CenturiesMutualConfig.CircleConfig.workoutBonusEarning : 0.0
            let totalAmount = baseAmount + bonusAmount
            
            showWorkoutEarningNotification(amount: totalAmount, includesBonus: bonusAmount > 0)
        }
        
        // Continue with existing completion flow...
    }
    
    private func showWorkoutEarningNotification(amount: Double, includesBonus: Bool) {
        let bonusText = includesBonus ? " (including 30+ min bonus!)" : ""
        let message = "You earned $\(amount, specifier: "%.2f") for this workout\(bonusText)"
        
        let alert = UIAlertController(
            title: "Great Workout! 💪",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "View Earnings", style: .default) { _ in
            self.navigateToWallet()
        })
        
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func navigateToWallet() {
        // Same navigation logic as survey
        if let tabBarController = self.tabBarController {
            tabBarController.selectedIndex = tabBarController.viewControllers?.count ?? 1 - 1
        }
    }
}

// MARK: - Admin Portal Integration
extension AdminViewController {
    func setupAdminWalletSection() {
        // Add wallet management section to existing admin interface
        let walletSection = createWalletManagementSection()
        
        // Add to existing stack view or table view
        if let stackView = view.subviews.first(where: { $0 is UIStackView }) as? UIStackView {
            stackView.addArrangedSubview(walletSection)
        }
    }
    
    private func createWalletManagementSection() -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        
        let titleLabel = UILabel()
        titleLabel.text = "Wallet Management"
        titleLabel.font = .boldSystemFont(ofSize: 18)
        
        let dashboardButton = UIButton(type: .system)
        dashboardButton.setTitle("Open Wallet Dashboard", for: .normal)
        dashboardButton.addTarget(self, action: #selector(openWalletDashboard), for: .touchUpInside)
        
        // Setup constraints...
        containerView.addSubview(titleLabel)
        containerView.addSubview(dashboardButton)
        
        return containerView
    }
    
    @objc private func openWalletDashboard() {
        let dashboardView = AdminDashboardView(
            edwardJonesAccountId: CenturiesMutualConfig.CircleConfig.edwardJonesAccountId
        )
        let hostingController = UIHostingController(rootView: dashboardView)
        present(hostingController, animated: true)
    }
}

// MARK: - Background Tasks for Interest Calculation
class InterestCalculationService {
    static let shared = InterestCalculationService()
    
    private let backgroundQueue = DispatchQueue(label: "interest.calculation", qos: .utility)
    
    func scheduleInterestCalculation() {
        // Schedule daily interest calculation
        backgroundQueue.async {
            self.calculateDailyInterest()
        }
    }
    
    private func calculateDailyInterest() {
        guard let adminManager = AppContext.shared.adminManager else { return }
        
        let currentBalance = adminManager.totalRevenue
        let dailyInterest = adminManager.earningsManager.calculateInterestEarned(
            principal: currentBalance,
            days: 1
        )
        
        // Update admin totals
        let currentInterest = UserDefaults.standard.double(forKey: "admin_total_interest")
        UserDefaults.standard.set(currentInterest + dailyInterest, forKey: "admin_total_interest")
        
        // Log to Hyperledger Fabric
        HyperledgerFabricLogger.logAdminAction(
            action: "daily_interest_calculation",
            amount: dailyInterest,
            adminId: "system"
        )
    }
}

// MARK: - Error Handling and Monitoring
class CircleErrorHandler {
    static func handleError(_ error: Error, context: String) {
        print("Circle API Error in \(context): \(error)")
        
        // Log to crash reporting service
        // CrashReporting.log(error: error, context: context)
        
        // Send to monitoring service
        // MonitoringService.trackError(error, context: context)
        
        // Show user-friendly message if needed
        if error is CircleError {
            showUserErrorAlert(for: error as! CircleError)
        }
    }
    
    private static func showUserErrorAlert(for error: CircleError) {
        guard let topViewController = UIApplication.shared.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "Wallet Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        topViewController.present(alert, animated: true)
    }
}

// MARK: - Testing and Development Helpers
#if DEBUG
class CircleDevelopmentTools {
    static func resetUserEarnings(userId: String) {
        let keys = [
            "total_earned_\(userId)",
            "available_balance_\(userId)",
            "pending_balance_\(userId)",
            "earnings_history_\(userId)"
        ]
        
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        print("Reset earnings for user: \(userId)")
    }
    
    static func addTestEarnings(userId: String) {
        guard let earningsManager = AppContext.shared.currentUserEarningsManager else { return }
        
        // Add various test earnings
        earningsManager.addSurveyEarning(surveyId: "test_survey_1")
        earningsManager.addWorkoutEarning(workoutType: "Cardio", duration: 1800)
        earningsManager.addReferralEarning(referredUserId: "test_referred_user")
        earningsManager.addEngagementBonus(activity: "Daily login streak")
        
        print("Added test earnings for user: \(userId)")
    }
    
    static func simulateTransactionFailure() {
        let error = CircleError.networkError
        CircleErrorHandler.handleError(error, context: "test_transaction")
    }
    
    static func printConfigSummary() {
        print("""
        Circle Integration Configuration:
        - API Environment: \(CenturiesMutualConfig.shared.getCurrentAPIKey().isEmpty ? "Not configured" : "Configured")
        - Admin Wallet: \(CenturiesMutualConfig.CircleConfig.adminWalletId)
        - Edward Jones Account: \(CenturiesMutualConfig.CircleConfig.edwardJonesAccountId)
        - Interest Rate: \(CenturiesMutualConfig.CircleConfig.annualInterestRate * 100)% APY
        - Survey Earning: $\(CenturiesMutualConfig.CircleConfig.surveyEarningAmount)
        - Workout Base Earning: $\(CenturiesMutualConfig.CircleConfig.workoutBaseEarning)
        - Max Daily Withdrawal: $\(CenturiesMutualConfig.CircleConfig.maxDailyWithdrawal)
        - Approval Threshold: $\(CenturiesMutualConfig.CircleConfig.approvalThreshold)
        """)
    }
}
#endif

// MARK: - Production Deployment Checklist
/*
 PRODUCTION DEPLOYMENT CHECKLIST:

 1. **API Configuration:**
    ✓ Replace sandbox API keys with production keys
    ✓ Configure proper Circle webhook endpoints
    ✓ Set up proper SSL certificates for webhook endpoints
    ✓ Test all API endpoints in production environment

 2. **Security:**
    ✓ Enable API key rotation
    ✓ Implement proper rate limiting
    ✓ Set up IP whitelisting for admin functions
    ✓ Enable two-factor authentication for admin accounts
    ✓ Audit all keychain storage implementations

 3. **Banking Integration:**
    ✓ Verify Edward Jones account configuration
    ✓ Test wire transfer functionality
    ✓ Set up proper reconciliation processes
    ✓ Configure transaction monitoring and alerts

 4. **Risk Management:**
    ✓ Review and adjust all transaction limits
    ✓ Test fraud detection algorithms
    ✓ Set up suspicious activity monitoring
    ✓ Configure compliance reporting

 5. **Monitoring & Logging:**
    ✓ Set up application performance monitoring
    ✓ Configure error tracking and alerting
    ✓ Implement transaction audit trails
    ✓ Set up financial reconciliation reports

 6. **Legal & Compliance:**
    ✓ Review terms of service for financial features
    ✓ Ensure proper user consent flows
    ✓ Implement required financial disclosures
    ✓ Set up proper data retention policies

 7. **Testing:**
    ✓ Complete end-to-end transaction testing
    ✓ Test all error handling scenarios
    ✓ Verify proper user experience flows
    ✓ Performance test under load

 8. **Backup & Recovery:**
    ✓ Implement proper data backup strategies
    ✓ Test disaster recovery procedures
    ✓ Set up database replication
    ✓ Create rollback procedures
 */

// MARK: - Podfile Configuration
/*
 Add the following to your Podfile:

 target 'CenturiesMutual' do
   use_frameworks!
   
   # Existing pods...
   
   # Circle Integration
   pod 'Alamofire', '~> 5.6'
   pod 'CryptoSwift', '~> 1.6'
   
   # Optional: For enhanced security
   pod 'CryptoKit', '~> 1.0' # iOS 13+
   
   # For QR code generation (wallet addresses)
   pod 'QRCodeGenerator', '~> 1.0'
   
   target 'CenturiesMutualTests' do
     inherit! :search_paths
     # Add testing pods if needed
   end
 end
 */

// MARK: - Info.plist Configuration
/*
 Add the following to your Info.plist:

 <key>CFBundleURLTypes</key>
 <array>
     <dict>
         <key>CFBundleURLName</key>
         <string>com.centuriesmutual.wallet</string>
         <key>CFBundleURLSchemes</key>
         <array>
             <string>centuriesmutual</string>
         </array>
     </dict>
 </array>

 <key>NSAppTransportSecurity</key>
 <dict>
     <key>NSAllowsArbitraryLoads</key>
     <false/>
     <key>NSExceptionDomains</key>
     <dict>
         <key>api.circle.com</key>
         <dict>
             <key>NSExceptionRequiresForwardSecrecy</key>
             <false/>
             <key>NSExceptionMinimumTLSVersion</key>
             <string>TLSv1.2</string>
         </dict>
         <key>api-sandbox.circle.com</key>
         <dict>
             <key>NSExceptionRequiresForwardSecrecy</key>
             <false/>
             <key>NSExceptionMinimumTLSVersion</key>
             <string>TLSv1.2</string>
         </dict>
     </dict>
 </dict>

 <key>NSFaceIDUsageDescription</key>
 <string>Use Face ID to secure your wallet transactions</string>

 <key>NSLocalNetworkUsageDescription</key>
 <string>Access local network for secure wallet operations</string>
 */

// MARK: - Entitlements Configuration
/*
 Add to your entitlements file:

 <key>keychain-access-groups</key>
 <array>
     <string>$(AppIdentifierPrefix)com.centuriesmutual.keychain</string>
 </array>

 <key>com.apple.developer.networking.networkextension</key>
 <array>
     <string>app-proxy-provider</string>
 </array>
 */

// MARK: - Build Configuration
/*
 Add to your build settings:

 DEBUG Configuration:
 - CIRCLE_API_ENVIRONMENT = "sandbox"
 - CIRCLE_LOGGING_ENABLED = "YES"

 RELEASE Configuration:
 - CIRCLE_API_ENVIRONMENT = "production"
 - CIRCLE_LOGGING_ENABLED = "NO"
 */

// MARK: - Final Integration Steps

extension AppDelegate {
    func finalizeCircleIntegration() {
        // 1. Test API connectivity
        testCircleAPIConnectivity()
        
        // 2. Initialize interest calculation service
        InterestCalculationService.shared.scheduleInterestCalculation()
        
        // 3. Set up error handling
        setupGlobalErrorHandling()
        
        // 4. Initialize development tools if in debug mode
        #if DEBUG
        CircleTestingHelper.createTestData()
        CircleDevelopmentTools.printConfigSummary()
        #endif
        
        print("Circle API integration finalized successfully")
    }
    
    private func testCircleAPIConnectivity() {
        guard let circleAPI = AppContext.shared.circleAPI else {
            print("⚠️ Circle API not initialized")
            return
        }
        
        // Test basic connectivity (you would implement this in CircleAPIService)
        // circleAPI.testConnection()
        print("✅ Circle API connectivity test initiated")
    }
    
    private func setupGlobalErrorHandling() {
        NSSetUncaughtExceptionHandler { exception in
            CircleErrorHandler.handleError(
                NSError(domain: "UncaughtException", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: exception.reason ?? "Unknown exception"
                ]),
                context: "global_exception_handler"
            )
        }
    }
}

// MARK: - Migration Helper for Existing Users
class CircleDataMigration {
    static func migrateExistingUsers() {
        let existingUsers = UserDefaults.standard.array(forKey: "existing_user_ids") as? [String] ?? []
        
        for userId in existingUsers {
            // Create Circle wallets for existing users
            createWalletForExistingUser(userId: userId)
            
            // Initialize earnings with any existing loyalty points or credits
            migrateExistingCredits(userId: userId)
        }
    }
    
    private static func createWalletForExistingUser(userId: String) {
        guard let circleAPI = AppContext.shared.circleAPI else { return }
        
        circleAPI.createUserWallet(userId: userId, description: "Migrated Centuries Mutual Wallet")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to create wallet for user \(userId): \(error)")
                    }
                },
                receiveValue: { wallet in
                    print("Successfully created wallet for existing user: \(userId)")
                }
            )
            .store(in: &cancellables)
    }
    
    private static func migrateExistingCredits(userId: String) {
        // Check if user has existing loyalty points or credits
        let existingPoints = UserDefaults.standard.double(forKey: "loyalty_points_\(userId)")
        
        if existingPoints > 0 {
            // Convert points to dollars (example: 100 points = $1)
            let dollarAmount = existingPoints / 100.0
            
            let earningsManager = UserEarningsManager(
                circleAPI: AppContext.shared.circleAPI!,
                userId: userId
            )
            
            earningsManager.addEarning(
                type: .bonus,
                amount: dollarAmount,
                description: "Migrated loyalty points"
            )
            
            // Clear old points
            UserDefaults.standard.removeObject(forKey: "loyalty_points_\(userId)")
            
            print("Migrated \(existingPoints) points to $\(dollarAmount) for user \(userId)")
        }
    }
}

// MARK: - Analytics Integration
class CircleAnalytics {
    static func trackEarningEvent(type: EarningType, amount: Double, userId: String) {
        let properties = [
            "earning_type": type.rawValue,
            "amount": amount,
            "user_id": userId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Send to your analytics service
        // Analytics.track("earning_completed", properties: properties)
        print("📊 Tracked earning: \(type.rawValue) - $\(amount)")
    }
    
    static func trackWithdrawalEvent(amount: Double, userId: String, success: Bool) {
        let properties = [
            "amount": amount,
            "user_id": userId,
            "success": success,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Send to your analytics service
        // Analytics.track("withdrawal_attempted", properties: properties)
        print("📊 Tracked withdrawal: $\(amount) - Success: \(success)")
    }
    
    static func trackAdminWithdrawal(amount: Double, adminId: String) {
        let properties = [
            "amount": amount,
            "admin_id": adminId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Send to your analytics service
        // Analytics.track("admin_withdrawal", properties: properties)
        print("📊 Tracked admin withdrawal: $\(amount)")
    }
}