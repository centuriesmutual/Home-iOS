import Foundation
import CryptoKit
import Security

// MARK: - Keycloak Authentication Manager
class KeycloakAuthManager: ObservableObject {
    static let shared = KeycloakAuthManager()
    
    private let baseURL: String
    private let realm: String
    private let clientID: String
    private let clientSecret: String?
    
    @Published var isAuthenticated = false
    @Published var currentUser: KeycloakUser?
    @Published var accessToken: String?
    @Published var refreshToken: String?
    
    private var tokenExpiry: Date?
    private var refreshTokenExpiry: Date?
    
    private init() {
        // Linode hosted Keycloak configuration
        self.baseURL = CenturiesMutualConfig.shared.keycloakBaseURL
        self.realm = CenturiesMutualConfig.shared.keycloakRealm
        self.clientID = CenturiesMutualConfig.shared.keycloakClientID
        self.clientSecret = CenturiesMutualConfig.shared.keycloakClientSecret
        
        loadStoredTokens()
    }
    
    // MARK: - Authentication Flow
    func authenticate() async throws {
        let authURL = buildAuthURL()
        // In a real app, you'd open this URL in Safari and handle the callback
        // For now, we'll simulate the authentication flow
        try await performOAuthFlow(authURL: authURL)
    }
    
    func authenticateWithCredentials(username: String, password: String) async throws {
        let tokenURL = "\(baseURL)/realms/\(realm)/protocol/openid-connect/token"
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "password"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        
        if let clientSecret = clientSecret {
            bodyComponents.queryItems?.append(URLQueryItem(name: "client_secret", value: clientSecret))
        }
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw KeycloakError.authenticationFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(KeycloakTokenResponse.self, from: data)
        try await handleTokenResponse(tokenResponse)
    }
    
    func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw KeycloakError.noRefreshToken
        }
        
        let tokenURL = "\(baseURL)/realms/\(realm)/protocol/openid-connect/token"
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]
        
        if let clientSecret = clientSecret {
            bodyComponents.queryItems?.append(URLQueryItem(name: "client_secret", value: clientSecret))
        }
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw KeycloakError.tokenRefreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(KeycloakTokenResponse.self, from: data)
        try await handleTokenResponse(tokenResponse)
    }
    
    func logout() async throws {
        guard let refreshToken = refreshToken else { return }
        
        let logoutURL = "\(baseURL)/realms/\(realm)/protocol/openid-connect/logout"
        
        var request = URLRequest(url: URL(string: logoutURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]
        
        if let clientSecret = clientSecret {
            bodyComponents.queryItems?.append(URLQueryItem(name: "client_secret", value: clientSecret))
        }
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 else {
            throw KeycloakError.logoutFailed
        }
        
        clearTokens()
    }
    
    // MARK: - User Management
    func getCurrentUser() async throws -> KeycloakUser {
        guard let token = accessToken else {
            throw KeycloakError.notAuthenticated
        }
        
        let userInfoURL = "\(baseURL)/realms/\(realm)/protocol/openid-connect/userinfo"
        
        var request = URLRequest(url: URL(string: userInfoURL)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw KeycloakError.userInfoFailed
        }
        
        let user = try JSONDecoder().decode(KeycloakUser.self, from: data)
        self.currentUser = user
        return user
    }
    
    func updateUserProfile(_ profile: KeycloakUserProfile) async throws {
        guard let token = accessToken, let userId = currentUser?.sub else {
            throw KeycloakError.notAuthenticated
        }
        
        let updateURL = "\(baseURL)/admin/realms/\(realm)/users/\(userId)"
        
        var request = URLRequest(url: URL(string: updateURL)!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONEncoder().encode(profile)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 else {
            throw KeycloakError.profileUpdateFailed
        }
    }
    
    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let token = accessToken, let userId = currentUser?.sub else {
            throw KeycloakError.notAuthenticated
        }
        
        let passwordURL = "\(baseURL)/admin/realms/\(realm)/users/\(userId)/reset-password"
        
        var request = URLRequest(url: URL(string: passwordURL)!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let passwordRequest = KeycloakPasswordRequest(
            type: "password",
            value: newPassword,
            temporary: false
        )
        
        request.httpBody = try JSONEncoder().encode(passwordRequest)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 else {
            throw KeycloakError.passwordChangeFailed
        }
    }
    
    // MARK: - Role Management
    func getUserRoles() async throws -> [KeycloakRole] {
        guard let token = accessToken, let userId = currentUser?.sub else {
            throw KeycloakError.notAuthenticated
        }
        
        let rolesURL = "\(baseURL)/admin/realms/\(realm)/users/\(userId)/role-mappings/realm"
        
        var request = URLRequest(url: URL(string: rolesURL)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw KeycloakError.rolesFetchFailed
        }
        
        return try JSONDecoder().decode([KeycloakRole].self, from: data)
    }
    
    func hasRole(_ roleName: String) async throws -> Bool {
        let roles = try await getUserRoles()
        return roles.contains { $0.name == roleName }
    }
    
    // MARK: - Token Validation
    func isTokenValid() -> Bool {
        guard let expiry = tokenExpiry else { return false }
        return expiry > Date()
    }
    
    func getValidAccessToken() async throws -> String {
        if !isTokenValid() {
            try await refreshAccessToken()
        }
        
        guard let token = accessToken else {
            throw KeycloakError.notAuthenticated
        }
        
        return token
    }
    
    // MARK: - Private Methods
    private func buildAuthURL() -> String {
        let redirectURI = "centuriesmutual://keycloak-auth"
        let state = UUID().uuidString
        let nonce = UUID().uuidString
        
        var components = URLComponents(string: "\(baseURL)/realms/\(realm)/protocol/openid-connect/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid profile email"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce)
        ]
        
        return components.url!.absoluteString
    }
    
    private func performOAuthFlow(authURL: String) async throws {
        // This would typically involve opening Safari and handling the callback
        // For demonstration, we'll use a mock authorization code
        let mockCode = "mock_auth_code_\(UUID().uuidString)"
        try await exchangeCodeForToken(code: mockCode)
    }
    
    private func exchangeCodeForToken(code: String) async throws {
        let tokenURL = "\(baseURL)/realms/\(realm)/protocol/openid-connect/token"
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: "centuriesmutual://keycloak-auth")
        ]
        
        if let clientSecret = clientSecret {
            bodyComponents.queryItems?.append(URLQueryItem(name: "client_secret", value: clientSecret))
        }
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw KeycloakError.authenticationFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(KeycloakTokenResponse.self, from: data)
        try await handleTokenResponse(tokenResponse)
    }
    
    private func handleTokenResponse(_ response: KeycloakTokenResponse) async throws {
        self.accessToken = response.accessToken
        self.refreshToken = response.refreshToken
        self.tokenExpiry = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        
        if let refreshExpiresIn = response.refreshExpiresIn {
            self.refreshTokenExpiry = Date().addingTimeInterval(TimeInterval(refreshExpiresIn))
        }
        
        try storeTokens()
        self.isAuthenticated = true
        
        // Fetch user info
        _ = try await getCurrentUser()
    }
    
    private func storeTokens() throws {
        let keychain = Keychain(service: "com.centuriesmutual.keycloak")
        
        if let token = accessToken {
            try keychain.set(token, key: "access_token")
        }
        
        if let refresh = refreshToken {
            try keychain.set(refresh, key: "refresh_token")
        }
        
        if let expiry = tokenExpiry {
            let expiryData = try JSONEncoder().encode(expiry)
            try keychain.set(expiryData, key: "token_expiry")
        }
        
        if let refreshExpiry = refreshTokenExpiry {
            let expiryData = try JSONEncoder().encode(refreshExpiry)
            try keychain.set(expiryData, key: "refresh_token_expiry")
        }
    }
    
    private func loadStoredTokens() {
        let keychain = Keychain(service: "com.centuriesmutual.keycloak")
        
        do {
            accessToken = try keychain.get("access_token")
            refreshToken = try keychain.get("refresh_token")
            
            if let expiryData = try keychain.getData("token_expiry") {
                tokenExpiry = try JSONDecoder().decode(Date.self, from: expiryData)
            }
            
            if let refreshExpiryData = try keychain.getData("refresh_token_expiry") {
                refreshTokenExpiry = try JSONDecoder().decode(Date.self, from: refreshExpiryData)
            }
            
            if let token = accessToken, let expiry = tokenExpiry, expiry > Date() {
                isAuthenticated = true
            }
        } catch {
            // Tokens not found or expired
            isAuthenticated = false
        }
    }
    
    private func clearTokens() {
        let keychain = Keychain(service: "com.centuriesmutual.keycloak")
        
        try? keychain.delete("access_token")
        try? keychain.delete("refresh_token")
        try? keychain.delete("token_expiry")
        try? keychain.delete("refresh_token_expiry")
        
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        refreshTokenExpiry = nil
        currentUser = nil
        isAuthenticated = false
    }
}

// MARK: - Supporting Types
struct KeycloakTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let refreshExpiresIn: Int?
    let refreshToken: String
    let tokenType: String
    let idToken: String?
    let notBeforePolicy: Int?
    let sessionState: String?
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshExpiresIn = "refresh_expires_in"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case idToken = "id_token"
        case notBeforePolicy = "not-before-policy"
        case sessionState = "session_state"
        case scope
    }
}

struct KeycloakUser: Codable {
    let sub: String
    let emailVerified: Bool
    let name: String?
    let preferredUsername: String?
    let givenName: String?
    let familyName: String?
    let email: String?
    let roles: [String]?
    
    enum CodingKeys: String, CodingKey {
        case sub
        case emailVerified = "email_verified"
        case name
        case preferredUsername = "preferred_username"
        case givenName = "given_name"
        case familyName = "family_name"
        case email
        case roles = "realm_access"
    }
}

struct KeycloakUserProfile: Codable {
    let firstName: String?
    let lastName: String?
    let email: String?
    let username: String?
    let enabled: Bool?
    let emailVerified: Bool?
    
    enum CodingKeys: String, CodingKey {
        case firstName = "firstName"
        case lastName = "lastName"
        case email, username, enabled
        case emailVerified = "emailVerified"
    }
}

struct KeycloakPasswordRequest: Codable {
    let type: String
    let value: String
    let temporary: Bool
}

struct KeycloakRole: Codable {
    let id: String
    let name: String
    let description: String?
    let composite: Bool
    let clientRole: Bool
    let containerId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, composite
        case clientRole = "clientRole"
        case containerId = "containerId"
    }
}

enum KeycloakError: Error, LocalizedError {
    case authenticationFailed
    case tokenRefreshFailed
    case logoutFailed
    case notAuthenticated
    case noRefreshToken
    case userInfoFailed
    case profileUpdateFailed
    case passwordChangeFailed
    case rolesFetchFailed
    case keychainError
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials."
        case .tokenRefreshFailed:
            return "Failed to refresh access token."
        case .logoutFailed:
            return "Logout failed. Please try again."
        case .notAuthenticated:
            return "User is not authenticated."
        case .noRefreshToken:
            return "No refresh token available."
        case .userInfoFailed:
            return "Failed to fetch user information."
        case .profileUpdateFailed:
            return "Failed to update user profile."
        case .passwordChangeFailed:
            return "Failed to change password."
        case .rolesFetchFailed:
            return "Failed to fetch user roles."
        case .keychainError:
            return "Keychain operation failed."
        }
    }
}

// MARK: - Keychain Extension
extension Keychain {
    func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeycloakError.keychainError
        }
    }
}
