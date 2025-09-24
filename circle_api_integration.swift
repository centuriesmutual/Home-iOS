import Foundation
import UIKit
import Security
import CryptoKit
import Combine

// MARK: - Circle API Models
struct CircleWallet: Codable {
    let walletId: String
    let entityId: String
    let type: String
    let description: String?
    let balances: [WalletBalance]
    let createDate: String
    let updateDate: String
}

struct WalletBalance: Codable {
    let amount: String
    let currency: String
}

struct CircleTransfer: Codable {
    let id: String
    let source: TransferSource
    let destination: TransferDestination
    let amount: TransferAmount
    let transactionHash: String?
    let status: String
    let createDate: String
}

struct TransferSource: Codable {
    let type: String
    let id: String
}

struct TransferDestination: Codable {
    let type: String
    let id: String
    let address: String?
}

struct TransferAmount: Codable {
    let amount: String
    let currency: String
}

struct CirclePayment: Codable {
    let id: String
    let type: String
    let amount: TransferAmount
    let fees: TransferAmount
    let status: String
    let createDate: String
    let updateDate: String
}

// MARK: - User Earnings & Rewards Models
struct UserEarnings: Codable {
    let userId: String
    let totalEarned: Double
    let availableBalance: Double
    let pendingBalance: Double
    let lastUpdated: Date
    let earningsHistory: [EarningTransaction]
}

struct EarningTransaction: Codable {
    let id: String
    let type: EarningType
    let amount: Double
    let description: String
    let timestamp: Date
    let status: TransactionStatus
}

enum EarningType: String, Codable, CaseIterable {
    case survey = "survey"
    case workout = "workout"
    case referral = "referral"
    case engagement = "engagement"
    case bonus = "bonus"
}

enum TransactionStatus: String, Codable {
    case pending = "pending"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

// MARK: - Security Manager
class CircleSecurityManager {
    private let keychain = KeychainManager()
    
    func storeAPIKey(_ key: String) throws {
        try keychain.store(key: "circle_api_key", value: key)
    }
    
    func retrieveAPIKey() throws -> String {
        return try keychain.retrieve(key: "circle_api_key")
    }
    
    func storeUserWalletCredentials(userId: String, walletId: String, encryptedKey: String) throws {
        let credentials = [
            "walletId": walletId,
            "encryptedKey": encryptedKey
        ]
        let data = try JSONEncoder().encode(credentials)
        try keychain.store(key: "user_wallet_\(userId)", value: String(data: data, encoding: .utf8) ?? "")
    }
    
    func retrieveUserWalletCredentials(userId: String) throws -> (walletId: String, encryptedKey: String) {
        let credentialsString = try keychain.retrieve(key: "user_wallet_\(userId)")
        let data = credentialsString.data(using: .utf8) ?? Data()
        let credentials = try JSONDecoder().decode([String: String].self, from: data)
        
        guard let walletId = credentials["walletId"],
              let encryptedKey = credentials["encryptedKey"] else {
            throw CircleError.invalidCredentials
        }
        
        return (walletId, encryptedKey)
    }
}

// MARK: - Keychain Manager
class KeychainManager {
    func store(key: String, value: String) throws {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw CircleError.keychainError
        }
    }
    
    func retrieve(key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw CircleError.keychainError
        }
        
        return value
    }
}

// MARK: - Circle API Service
class CircleAPIService: ObservableObject {
    private let baseURL = "https://api.circle.com"
    private let sandboxURL = "https://api-sandbox.circle.com"
    private let securityManager = CircleSecurityManager()
    private var cancellables = Set<AnyCancellable>()
    
    private var isSandbox: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    private var apiBaseURL: String {
        return isSandbox ? sandboxURL : baseURL
    }
    
    // MARK: - Authentication & Setup
    func initialize(apiKey: String) throws {
        try securityManager.storeAPIKey(apiKey)
    }
    
    private func createAuthenticatedRequest(endpoint: String, method: String = "GET") throws -> URLRequest {
        let apiKey = try securityManager.retrieveAPIKey()
        guard let url = URL(string: "\(apiBaseURL)\(endpoint)") else {
            throw CircleError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return request
    }
    
    // MARK: - Wallet Management
    func createUserWallet(userId: String, description: String = "Centuries Mutual Wallet") -> AnyPublisher<CircleWallet, Error> {
        do {
            var request = try createAuthenticatedRequest(endpoint: "/v1/wallets", method: "POST")
            
            let body = [
                "idempotencyKey": UUID().uuidString,
                "description": description
            ]
            
            request.httpBody = try JSONEncoder().encode(body)
            
            return URLSession.shared.dataTaskPublisher(for: request)
                .map(\.data)
                .decode(type: CircleAPIResponse<CircleWallet>.self, decoder: JSONDecoder())
                .map(\.data)
                .handleEvents(receiveOutput: { wallet in
                    // Store wallet credentials securely
                    try? self.securityManager.storeUserWalletCredentials(
                        userId: userId,
                        walletId: wallet.walletId,
                        encryptedKey: "encrypted_key_placeholder"
                    )
                })
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func getWalletBalance(walletId: String) -> AnyPublisher<[WalletBalance], Error> {
        do {
            let request = try createAuthenticatedRequest(endpoint: "/v1/wallets/\(walletId)")
            
            return URLSession.shared.dataTaskPublisher(for: request)
                .map(\.data)
                .decode(type: CircleAPIResponse<CircleWallet>.self, decoder: JSONDecoder())
                .map { $0.data.balances }
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    // MARK: - Transfers & Payments
    func transferToUser(fromWalletId: String, toWalletId: String, amount: Double, currency: String = "USD") -> AnyPublisher<CircleTransfer, Error> {
        do {
            var request = try createAuthenticatedRequest(endpoint: "/v1/transfers", method: "POST")
            
            let body = [
                "idempotencyKey": UUID().uuidString,
                "source": ["type": "wallet", "id": fromWalletId],
                "destination": ["type": "wallet", "id": toWalletId],
                "amount": ["amount": String(amount), "currency": currency]
            ] as [String: Any]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            return URLSession.shared.dataTaskPublisher(for: request)
                .map(\.data)
                .decode(type: CircleAPIResponse<CircleTransfer>.self, decoder: JSONDecoder())
                .map(\.data)
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func withdrawToBank(walletId: String, bankAccountId: String, amount: Double) -> AnyPublisher<CircleTransfer, Error> {
        do {
            var request = try createAuthenticatedRequest(endpoint: "/v1/transfers", method: "POST")
            
            let body = [
                "idempotencyKey": UUID().uuidString,
                "source": ["type": "wallet", "id": walletId],
                "destination": ["type": "wire", "id": bankAccountId],
                "amount": ["amount": String(amount), "currency": "USD"]
            ] as [String: Any]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            return URLSession.shared.dataTaskPublisher(for: request)
                .map(\.data)
                .decode(type: CircleAPIResponse<CircleTransfer>.self, decoder: JSONDecoder())
                .map(\.data)
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
}

// MARK: - User Earnings Manager
class UserEarningsManager: ObservableObject {
    @Published var userEarnings: UserEarnings?
    @Published var isLoading = false
    
    private let circleAPI: CircleAPIService
    private let userId: String
    private var cancellables = Set<AnyCancellable>()
    
    // Interest rate for idle funds (annual percentage)
    private let annualInterestRate: Double = 0.045 // 4.5% APY
    
    init(circleAPI: CircleAPIService, userId: String) {
        self.circleAPI = circleAPI
        self.userId = userId
        loadUserEarnings()
    }
    
    func loadUserEarnings() {
        isLoading = true
        
        // In a real implementation, this would fetch from your backend
        // For now, we'll simulate with local storage
        let earnings = UserEarnings(
            userId: userId,
            totalEarned: UserDefaults.standard.double(forKey: "total_earned_\(userId)"),
            availableBalance: UserDefaults.standard.double(forKey: "available_balance_\(userId)"),
            pendingBalance: UserDefaults.standard.double(forKey: "pending_balance_\(userId)"),
            lastUpdated: Date(),
            earningsHistory: loadEarningsHistory()
        )
        
        self.userEarnings = earnings
        isLoading = false
    }
    
    func addEarning(type: EarningType, amount: Double, description: String) {
        let transaction = EarningTransaction(
            id: UUID().uuidString,
            type: type,
            amount: amount,
            description: description,
            timestamp: Date(),
            status: .pending
        )
        
        var current = userEarnings ?? UserEarnings(
            userId: userId,
            totalEarned: 0,
            availableBalance: 0,
            pendingBalance: 0,
            lastUpdated: Date(),
            earningsHistory: []
        )
        
        current.pendingBalance += amount
        current.earningsHistory.append(transaction)
        current.lastUpdated = Date()
        
        userEarnings = current
        saveUserEarnings(current)
        
        // Process the earning after a delay (simulate processing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.processEarning(transactionId: transaction.id)
        }
    }
    
    private func processEarning(transactionId: String) {
        guard var current = userEarnings else { return }
        
        if let index = current.earningsHistory.firstIndex(where: { $0.id == transactionId }) {
            let transaction = current.earningsHistory[index]
            current.earningsHistory[index] = EarningTransaction(
                id: transaction.id,
                type: transaction.type,
                amount: transaction.amount,
                description: transaction.description,
                timestamp: transaction.timestamp,
                status: .completed
            )
            
            current.pendingBalance -= transaction.amount
            current.availableBalance += transaction.amount
            current.totalEarned += transaction.amount
            current.lastUpdated = Date()
            
            userEarnings = current
            saveUserEarnings(current)
        }
    }
    
    func calculateInterestEarned(principal: Double, days: Int) -> Double {
        let dailyRate = annualInterestRate / 365.0
        return principal * dailyRate * Double(days)
    }
    
    func withdrawEarnings(amount: Double, toWalletId: String) -> AnyPublisher<Bool, Error> {
        guard var current = userEarnings,
              current.availableBalance >= amount else {
            return Fail(error: CircleError.insufficientFunds).eraseToAnyPublisher()
        }
        
        // Create admin wallet if needed (this should be done once during setup)
        let adminWalletId = "admin_wallet_id" // This should be stored securely
        
        return circleAPI.transferToUser(
            fromWalletId: adminWalletId,
            toWalletId: toWalletId,
            amount: amount
        )
        .map { transfer in
            current.availableBalance -= amount
            current.lastUpdated = Date()
            self.userEarnings = current
            self.saveUserEarnings(current)
            return true
        }
        .eraseToAnyPublisher()
    }
    
    private func loadEarningsHistory() -> [EarningTransaction] {
        guard let data = UserDefaults.standard.data(forKey: "earnings_history_\(userId)"),
              let history = try? JSONDecoder().decode([EarningTransaction].self, from: data) else {
            return []
        }
        return history
    }
    
    private func saveUserEarnings(_ earnings: UserEarnings) {
        UserDefaults.standard.set(earnings.totalEarned, forKey: "total_earned_\(userId)")
        UserDefaults.standard.set(earnings.availableBalance, forKey: "available_balance_\(userId)")
        UserDefaults.standard.set(earnings.pendingBalance, forKey: "pending_balance_\(userId)")
        
        if let data = try? JSONEncoder().encode(earnings.earningsHistory) {
            UserDefaults.standard.set(data, forKey: "earnings_history_\(userId)")
        }
    }
}

// MARK: - External Wallet Integration Manager
class ExternalWalletManager: ObservableObject {
    @Published var connectedWallets: [ConnectedWallet] = []
    @Published var isConnecting = false
    
    private let circleAPI: CircleAPIService
    
    init(circleAPI: CircleAPIService) {
        self.circleAPI = circleAPI
        loadConnectedWallets()
    }
    
    func connectCoinbaseWallet(authCode: String) -> AnyPublisher<ConnectedWallet, Error> {
        isConnecting = true
        
        // In a real implementation, you would:
        // 1. Exchange auth code for access token
        // 2. Fetch wallet information from Coinbase API
        // 3. Store connection securely
        
        return Future<ConnectedWallet, Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                let wallet = ConnectedWallet(
                    id: UUID().uuidString,
                    type: .coinbase,
                    name: "Coinbase Wallet",
                    address: "0x123...abc",
                    balance: "1250.00",
                    currency: "USDC",
                    isActive: true,
                    connectedDate: Date()
                )
                
                DispatchQueue.main.async {
                    self.connectedWallets.append(wallet)
                    self.saveConnectedWallets()
                    self.isConnecting = false
                    promise(.success(wallet))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func connectRobinhoodWallet(authCode: String) -> AnyPublisher<ConnectedWallet, Error> {
        isConnecting = true
        
        return Future<ConnectedWallet, Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                let wallet = ConnectedWallet(
                    id: UUID().uuidString,
                    type: .robinhood,
                    name: "Robinhood Crypto",
                    address: "0x456...def",
                    balance: "890.50",
                    currency: "USDC",
                    isActive: true,
                    connectedDate: Date()
                )
                
                DispatchQueue.main.async {
                    self.connectedWallets.append(wallet)
                    self.saveConnectedWallets()
                    self.isConnecting = false
                    promise(.success(wallet))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func disconnectWallet(walletId: String) {
        connectedWallets.removeAll { $0.id == walletId }
        saveConnectedWallets()
    }
    
    private func loadConnectedWallets() {
        guard let data = UserDefaults.standard.data(forKey: "connected_wallets"),
              let wallets = try? JSONDecoder().decode([ConnectedWallet].self, from: data) else {
            return
        }
        connectedWallets = wallets
    }
    
    private func saveConnectedWallets() {
        if let data = try? JSONEncoder().encode(connectedWallets) {
            UserDefaults.standard.set(data, forKey: "connected_wallets")
        }
    }
}

struct ConnectedWallet: Codable, Identifiable {
    let id: String
    let type: WalletType
    let name: String
    let address: String
    let balance: String
    let currency: String
    let isActive: Bool
    let connectedDate: Date
}

enum WalletType: String, Codable {
    case coinbase = "coinbase"
    case robinhood = "robinhood"
    case circle = "circle"
}

// MARK: - Risk Management & Safeguards
class RiskManagementService: ObservableObject {
    @Published var riskLimits = RiskLimits()
    @Published var dailyTransactionVolume: Double = 0
    @Published var monthlyTransactionVolume: Double = 0
    
    private let maxDailyWithdrawal: Double = 5000.0
    private let maxMonthlyWithdrawal: Double = 50000.0
    private let maxSingleTransaction: Double = 1000.0
    
    func validateTransaction(amount: Double, type: TransactionType) -> TransactionValidationResult {
        var issues: [ValidationIssue] = []
        
        // Check single transaction limit
        if amount > maxSingleTransaction {
            issues.append(.exceedsMaxSingleTransaction(max: maxSingleTransaction))
        }
        
        // Check daily limit
        if dailyTransactionVolume + amount > maxDailyWithdrawal {
            issues.append(.exceedsDailyLimit(current: dailyTransactionVolume, max: maxDailyWithdrawal))
        }
        
        // Check monthly limit
        if monthlyTransactionVolume + amount > maxMonthlyWithdrawal {
            issues.append(.exceedsMonthlyLimit(current: monthlyTransactionVolume, max: maxMonthlyWithdrawal))
        }
        
        // Additional checks based on transaction type
        switch type {
        case .withdrawal:
            if amount < 10.0 {
                issues.append(.belowMinimumAmount(min: 10.0))
            }
        case .earnings:
            if amount > 100.0 {
                issues.append(.suspiciousEarningsAmount)
            }
        }
        
        return TransactionValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            requiresApproval: amount > 500.0 || !issues.isEmpty
        )
    }
    
    func recordTransaction(amount: Double, type: TransactionType) {
        dailyTransactionVolume += amount
        monthlyTransactionVolume += amount
        
        // In a real implementation, these would be persisted and reset appropriately
        UserDefaults.standard.set(dailyTransactionVolume, forKey: "daily_transaction_volume")
        UserDefaults.standard.set(monthlyTransactionVolume, forKey: "monthly_transaction_volume")
    }
}

struct RiskLimits: Codable {
    var maxDailyWithdrawal: Double = 5000.0
    var maxMonthlyWithdrawal: Double = 50000.0
    var maxSingleTransaction: Double = 1000.0
    var minWithdrawalAmount: Double = 10.0
    var requiresApprovalThreshold: Double = 500.0
}

struct TransactionValidationResult {
    let isValid: Bool
    let issues: [ValidationIssue]
    let requiresApproval: Bool
}

enum ValidationIssue {
    case exceedsMaxSingleTransaction(max: Double)
    case exceedsDailyLimit(current: Double, max: Double)
    case exceedsMonthlyLimit(current: Double, max: Double)
    case belowMinimumAmount(min: Double)
    case suspiciousEarningsAmount
    case insufficientFunds
    case invalidWallet
}

enum TransactionType {
    case withdrawal
    case earnings
    case transfer
}

// MARK: - Admin Dashboard Manager
class AdminDashboardManager: ObservableObject {
    @Published var totalRevenue: Double = 0
    @Published var totalInterestEarned: Double = 0
    @Published var activeUsers: Int = 0
    @Published var pendingWithdrawals: [PendingWithdrawal] = []
    @Published var recentTransactions: [AdminTransaction] = []
    
    private let circleAPI: CircleAPIService
    private let edwardJonesAccountId: String
    
    init(circleAPI: CircleAPIService, edwardJonesAccountId: String) {
        self.circleAPI = circleAPI
        self.edwardJonesAccountId = edwardJonesAccountId
        loadDashboardData()
    }
    
    func loadDashboardData() {
        // In a real implementation, this would fetch from your backend/database
        totalRevenue = UserDefaults.standard.double(forKey: "admin_total_revenue")
        totalInterestEarned = UserDefaults.standard.double(forKey: "admin_total_interest")
        activeUsers = UserDefaults.standard.integer(forKey: "admin_active_users")
        
        loadPendingWithdrawals()
        loadRecentTransactions()
    }
    
    func withdrawToEdwardJones(amount: Double) -> AnyPublisher<Bool, Error> {
        let adminWalletId = "admin_wallet_id" // This should be stored securely
        
        return circleAPI.withdrawToBank(
            walletId: adminWalletId,
            bankAccountId: edwardJonesAccountId,
            amount: amount
        )
        .map { transfer in
            // Update admin totals
            let currentRevenue = UserDefaults.standard.double(forKey: "admin_total_revenue")
            UserDefaults.standard.set(currentRevenue - amount, forKey: "admin_total_revenue")
            
            self.totalRevenue -= amount
            return true
        }
        .eraseToAnyPublisher()
    }
    
    func approveWithdrawal(withdrawalId: String) {
        if let index = pendingWithdrawals.firstIndex(where: { $0.id == withdrawalId }) {
            pendingWithdrawals[index].status = .approved
            // In a real implementation, this would trigger the actual withdrawal
        }
    }
    
    func rejectWithdrawal(withdrawalId: String, reason: String) {
        if let index = pendingWithdrawals.firstIndex(where: { $0.id == withdrawalId }) {
            pendingWithdrawals[index].status = .rejected
            pendingWithdrawals[index].rejectionReason = reason
        }
    }
    
    private func loadPendingWithdrawals() {
        guard let data = UserDefaults.standard.data(forKey: "pending_withdrawals"),
              let withdrawals = try? JSONDecoder().decode([PendingWithdrawal].self, from: data) else {
            return
        }
        pendingWithdrawals = withdrawals
    }
    
    private func loadRecentTransactions() {
        guard let data = UserDefaults.standard.data(forKey: "admin_recent_transactions"),
              let transactions = try? JSONDecoder().decode([AdminTransaction].self, from: data) else {
            return
        }
        recentTransactions = transactions
    }
}

struct PendingWithdrawal: Codable, Identifiable {
    let id: String
    let userId: String
    let userName: String
    let amount: Double
    let requestDate: Date
    var status: WithdrawalStatus
    var rejectionReason: String?
}

struct AdminTransaction: Codable, Identifiable {
    let id: String
    let type: String
    let amount: Double
    let userId: String?
    let timestamp: Date
    let status: String
}

enum WithdrawalStatus: String, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case completed = "completed"
}

// MARK: - Error Types
enum CircleError: LocalizedError {
    case invalidURL
    case invalidCredentials
    case keychainError
    case insufficientFunds
    case networkError
    case unauthorized
    case rateLimited
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidCredentials:
            return "Invalid credentials"
        case .keychainError:
            return "Keychain access error"
        case .insufficientFunds:
            return "Insufficient funds"
        case .networkError:
            return "Network error"
        case .unauthorized:
            return "Unauthorized access"
        case .rateLimited:
            return "Rate limit exceeded"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

// MARK: - API Response Models
struct CircleAPIResponse<T: Codable>: Codable {
    let data: T
    let message: String?
}

// MARK: - Integration with Hyperledger Fabric (Placeholder)
class HyperledgerFabricLogger {
    static func logTransaction(_ transaction: EarningTransaction, userId: String) {
        // Placeholder for Hyperledger Fabric integration
        // This would log the transaction to the blockchain for compliance
        print("Logging transaction to Hyperledger: \(transaction.id) for user \(userId)")
        
        // In a real implementation:
        // 1. Format transaction data according to your chaincode
        // 2. Submit transaction to Fabric network
        // 3. Handle response and errors
        // 4. Store transaction hash for reference
    }
    
    static func logWithdrawal(_ withdrawal: PendingWithdrawal) {
        print("Logging withdrawal to Hyperledger: \(withdrawal.id)")
    }
    
    static func logAdminAction(action: String, amount: Double, adminId: String) {
        print("Logging admin action to Hyperledger: \(action) - \(amount) by \(adminId)")
    }
}