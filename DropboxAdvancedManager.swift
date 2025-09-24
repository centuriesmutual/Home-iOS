import Foundation
import CryptoKit
import Security

// MARK: - Dropbox Advanced API Manager
class DropboxAdvancedManager: ObservableObject {
    static let shared = DropboxAdvancedManager()
    
    private let baseURL = "https://api.dropboxapi.com/2"
    private let uploadURL = "https://content.dropboxapi.com/2"
    private let downloadURL = "https://content.dropboxapi.com/2"
    
    @Published var isAuthenticated = false
    @Published var userInfo: DropboxUserInfo?
    
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?
    
    private init() {
        loadStoredCredentials()
    }
    
    // MARK: - Authentication
    func authenticate() async throws {
        let authURL = "https://www.dropbox.com/oauth2/authorize"
        let clientID = CenturiesMutualConfig.shared.dropboxClientID
        let redirectURI = "centuriesmutual://dropbox-auth"
        
        // In a real app, you'd open this URL in Safari and handle the callback
        // For now, we'll simulate the authentication flow
        try await performOAuthFlow(clientID: clientID, redirectURI: redirectURI)
    }
    
    private func performOAuthFlow(clientID: String, redirectURI: String) async throws {
        // This would typically involve opening Safari and handling the callback
        // For demonstration, we'll use a mock token
        let mockToken = "mock_access_token_\(UUID().uuidString)"
        try await exchangeCodeForToken(code: mockToken)
    }
    
    private func exchangeCodeForToken(code: String) async throws {
        let url = URL(string: "https://api.dropboxapi.com/oauth2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "code=\(code)&grant_type=authorization_code&client_id=\(CenturiesMutualConfig.shared.dropboxClientID)&client_secret=\(CenturiesMutualConfig.shared.dropboxClientSecret)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DropboxError.authenticationFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(DropboxTokenResponse.self, from: data)
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        self.tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        
        try storeCredentials()
        self.isAuthenticated = true
        
        try await fetchUserInfo()
    }
    
    // MARK: - Advanced File Operations
    func uploadFileAdvanced(data: Data, path: String, mode: UploadMode = .add) async throws -> DropboxFileMetadata {
        guard let token = accessToken else { throw DropboxError.notAuthenticated }
        
        let url = URL(string: "\(uploadURL)/files/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        let uploadArgs = DropboxUploadArgs(path: path, mode: mode.rawValue, autorename: true)
        let argsData = try JSONEncoder().encode(uploadArgs)
        let argsString = String(data: argsData, encoding: .utf8)!
        
        request.setValue(argsString, forHTTPHeaderField: "Dropbox-API-Arg")
        request.httpBody = data
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DropboxError.uploadFailed
        }
        
        return try JSONDecoder().decode(DropboxFileMetadata.self, from: responseData)
    }
    
    func downloadFileAdvanced(path: String) async throws -> Data {
        guard let token = accessToken else { throw DropboxError.notAuthenticated }
        
        let url = URL(string: "\(downloadURL)/files/download")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let downloadArgs = DropboxDownloadArgs(path: path)
        let argsData = try JSONEncoder().encode(downloadArgs)
        let argsString = String(data: argsData, encoding: .utf8)!
        
        request.setValue(argsString, forHTTPHeaderField: "Dropbox-API-Arg")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DropboxError.downloadFailed
        }
        
        return data
    }
    
    // MARK: - Advanced Search and Metadata
    func searchFiles(query: String, path: String = "", maxResults: Int = 100) async throws -> [DropboxFileMetadata] {
        guard let token = accessToken else { throw DropboxError.notAuthenticated }
        
        let url = URL(string: "\(baseURL)/files/search_v2")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let searchRequest = DropboxSearchRequest(
            query: query,
            options: DropboxSearchOptions(
                path: path,
                maxResults: maxResults,
                fileStatus: .active
            )
        )
        
        request.httpBody = try JSONEncoder().encode(searchRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DropboxError.searchFailed
        }
        
        let searchResponse = try JSONDecoder().decode(DropboxSearchResponse.self, from: data)
        return searchResponse.matches.compactMap { $0.metadata.metadata }
    }
    
    func getFileMetadata(path: String) async throws -> DropboxFileMetadata {
        guard let token = accessToken else { throw DropboxError.notAuthenticated }
        
        let url = URL(string: "\(baseURL)/files/get_metadata")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let metadataRequest = DropboxMetadataRequest(path: path)
        request.httpBody = try JSONEncoder().encode(metadataRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DropboxError.metadataFailed
        }
        
        return try JSONDecoder().decode(DropboxFileMetadata.self, from: data)
    }
    
    // MARK: - Sharing and Collaboration
    func createSharedLink(path: String, settings: DropboxSharedLinkSettings? = nil) async throws -> DropboxSharedLink {
        guard let token = accessToken else { throw DropboxError.notAuthenticated }
        
        let url = URL(string: "\(baseURL)/sharing/create_shared_link_with_settings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let shareRequest = DropboxShareRequest(path: path, settings: settings)
        request.httpBody = try JSONEncoder().encode(shareRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DropboxError.sharingFailed
        }
        
        return try JSONDecoder().decode(DropboxSharedLink.self, from: data)
    }
    
    // MARK: - Team Management (Advanced)
    func getTeamMembers() async throws -> [DropboxTeamMember] {
        guard let token = accessToken else { throw DropboxError.notAuthenticated }
        
        let url = URL(string: "\(baseURL)/team/members/list")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DropboxError.teamAccessFailed
        }
        
        let teamResponse = try JSONDecoder().decode(DropboxTeamResponse.self, from: data)
        return teamResponse.members
    }
    
    // MARK: - Private Methods
    private func fetchUserInfo() async throws {
        guard let token = accessToken else { throw DropboxError.notAuthenticated }
        
        let url = URL(string: "\(baseURL)/users/get_current_account")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DropboxError.userInfoFailed
        }
        
        self.userInfo = try JSONDecoder().decode(DropboxUserInfo.self, from: data)
    }
    
    private func storeCredentials() throws {
        let keychain = Keychain(service: "com.centuriesmutual.dropbox")
        
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
    }
    
    private func loadStoredCredentials() {
        let keychain = Keychain(service: "com.centuriesmutual.dropbox")
        
        do {
            accessToken = try keychain.get("access_token")
            refreshToken = try keychain.get("refresh_token")
            
            if let expiryData = try keychain.getData("token_expiry") {
                tokenExpiry = try JSONDecoder().decode(Date.self, from: expiryData)
            }
            
            if let token = accessToken, let expiry = tokenExpiry, expiry > Date() {
                isAuthenticated = true
            }
        } catch {
            // Credentials not found or expired
            isAuthenticated = false
        }
    }
}

// MARK: - Supporting Types
enum UploadMode: String, Codable {
    case add = "add"
    case overwrite = "overwrite"
    case update = "update"
}

struct DropboxTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

struct DropboxUserInfo: Codable {
    let accountId: String
    let name: DropboxUserName
    let email: String
    let emailVerified: Bool
    let disabled: Bool
    let country: String?
    let locale: String?
    let referralLink: String?
    let isPaired: Bool
    let accountType: DropboxAccountType
    
    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case name, email
        case emailVerified = "email_verified"
        case disabled, country, locale
        case referralLink = "referral_link"
        case isPaired = "is_paired"
        case accountType = "account_type"
    }
}

struct DropboxUserName: Codable {
    let givenName: String
    let surname: String
    let familiarName: String
    let displayName: String
    let abbreviatedName: String
    
    enum CodingKeys: String, CodingKey {
        case givenName = "given_name"
        case surname
        case familiarName = "familiar_name"
        case displayName = "display_name"
        case abbreviatedName = "abbreviated_name"
    }
}

struct DropboxAccountType: Codable {
    let tag: String
}

struct DropboxUploadArgs: Codable {
    let path: String
    let mode: String
    let autorename: Bool
}

struct DropboxDownloadArgs: Codable {
    let path: String
}

struct DropboxSearchRequest: Codable {
    let query: String
    let options: DropboxSearchOptions
}

struct DropboxSearchOptions: Codable {
    let path: String
    let maxResults: Int
    let fileStatus: DropboxFileStatus
    
    enum CodingKeys: String, CodingKey {
        case path
        case maxResults = "max_results"
        case fileStatus = "file_status"
    }
}

enum DropboxFileStatus: String, Codable {
    case active = "active"
    case deleted = "deleted"
}

struct DropboxSearchResponse: Codable {
    let matches: [DropboxSearchMatch]
}

struct DropboxSearchMatch: Codable {
    let matchType: DropboxMatchType
    let metadata: DropboxSearchMetadata
    
    enum CodingKeys: String, CodingKey {
        case matchType = "match_type"
        case metadata
    }
}

enum DropboxMatchType: String, Codable {
    case filename = "filename"
    case content = "content"
    case both = "both"
}

struct DropboxSearchMetadata: Codable {
    let metadata: DropboxFileMetadata?
}

struct DropboxMetadataRequest: Codable {
    let path: String
}

struct DropboxShareRequest: Codable {
    let path: String
    let settings: DropboxSharedLinkSettings?
}

struct DropboxSharedLinkSettings: Codable {
    let requestedVisibility: DropboxVisibility?
    let linkPassword: String?
    let expires: String?
    
    enum CodingKeys: String, CodingKey {
        case requestedVisibility = "requested_visibility"
        case linkPassword = "link_password"
        case expires
    }
}

enum DropboxVisibility: String, Codable {
    case public_ = "public"
    case teamOnly = "team_only"
    case password = "password"
}

struct DropboxSharedLink: Codable {
    let url: String
    let name: String
    let linkPermissions: DropboxLinkPermissions
    let id: String?
    let expires: String?
    let pathLower: String?
    let teamMemberInfo: DropboxTeamMemberInfo?
    
    enum CodingKeys: String, CodingKey {
        case url, name, id, expires
        case linkPermissions = "link_permissions"
        case pathLower = "path_lower"
        case teamMemberInfo = "team_member_info"
    }
}

struct DropboxLinkPermissions: Codable {
    let canRevoke: Bool
    let visibility: DropboxVisibility
    let allowDownload: Bool
    
    enum CodingKeys: String, CodingKey {
        case canRevoke = "can_revoke"
        case visibility
        case allowDownload = "allow_download"
    }
}

struct DropboxTeamMemberInfo: Codable {
    let teamMemberId: String
    let displayName: String
    
    enum CodingKeys: String, CodingKey {
        case teamMemberId = "team_member_id"
        case displayName = "display_name"
    }
}

struct DropboxTeamResponse: Codable {
    let members: [DropboxTeamMember]
    let cursor: String
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case members, cursor
        case hasMore = "has_more"
    }
}

struct DropboxTeamMember: Codable {
    let profile: DropboxTeamMemberProfile
    let role: DropboxTeamRole
}

struct DropboxTeamMemberProfile: Codable {
    let teamMemberId: String
    let externalId: String?
    let accountId: String?
    let email: String
    let emailVerified: Bool
    let status: DropboxTeamMemberStatus
    let name: DropboxUserName
    let membershipType: DropboxMembershipType
    let joinedOn: String?
    let invitedOn: String?
    
    enum CodingKeys: String, CodingKey {
        case teamMemberId = "team_member_id"
        case externalId = "external_id"
        case accountId = "account_id"
        case email
        case emailVerified = "email_verified"
        case status, name
        case membershipType = "membership_type"
        case joinedOn = "joined_on"
        case invitedOn = "invited_on"
    }
}

enum DropboxTeamRole: String, Codable {
    case owner = "owner"
    case admin = "admin"
    case member = "member"
}

enum DropboxTeamMemberStatus: String, Codable {
    case active = "active"
    case invited = "invited"
    case suspended = "suspended"
}

enum DropboxMembershipType: String, Codable {
    case full = "full"
    case limited = "limited"
}

// MARK: - Keychain Helper
struct Keychain {
    private let service: String
    
    init(service: String) {
        self.service = service
    }
    
    func set(_ value: String, key: String) throws {
        let data = value.data(using: .utf8)!
        try set(data, key: key)
    }
    
    func set(_ data: Data, key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw DropboxError.keychainError
        }
    }
    
    func get(_ key: String) throws -> String? {
        guard let data = try getData(key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func getData(_ key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw DropboxError.keychainError
        }
        
        return result as? Data
    }
}
