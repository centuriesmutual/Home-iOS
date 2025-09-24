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
    
    func addSurveyEarning(surveyId: String) {
        addEarning(
            type: .survey,
            amount: CenturiesMutualConfig.CircleConfig.surveyEarningAmount,
            description: "Survey completion: \(surveyId)"
        )
    }
    
    func addWorkoutEarning(workoutType: String, duration: TimeInterval) {
        let baseAmount = CenturiesMutualConfig.CircleConfig.workoutBaseEarning
        let bonusAmount = duration > 1800 ? CenturiesMutualConfig.CircleConfig.workoutBonusEarning : 0.0
        let totalAmount = baseAmount + bonusAmount
        
        addEarning(
            type: .workout,
            amount: totalAmount,
            description: "Workout: \(workoutType) (\(Int(duration/60)) min)"
        )
    }
    
    func addReferralEarning(referredUserId: String) {
        addEarning(
            type: .referral,
            amount: CenturiesMutualConfig.CircleConfig.referralEarning,
            description: "Referral bonus for user: \(referredUserId)"
        )
    }
    
    func addEngagementBonus(activity: String) {
        addEarning(
            type: .engagement,
            amount: CenturiesMutualConfig.CircleConfig.engagementEarning,
            description: "Engagement bonus: \(activity)"
        )
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
