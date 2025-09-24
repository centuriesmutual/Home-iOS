import Foundation
import SwiftyDropbox
import Combine
import CryptoKit
import SQLite3

// MARK: - Dropbox Integration Manager
class DropboxManager: NSObject, ObservableObject {
    static let shared = DropboxManager()
    
    @Published var isAuthenticated = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var uploadProgress: [String: Double] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    private let encryptionKey = SymmetricKey(size: .bits256)
    
    // MARK: - Configuration
    struct Config {
        static let appKey = "YOUR_DROPBOX_APP_KEY"
        static let teamFolderId = "YOUR_TEAM_FOLDER_ID"
        
        // Folder structure for Centuries Mutual
        struct Folders {
            static let enrollments = "/CenturiesMutual/Enrollments"
            static let messages = "/CenturiesMutual/Messages" 
            static let plans = "/CenturiesMutual/Plans"
            static let documents = "/CenturiesMutual/Documents"
            static let audit = "/CenturiesMutual/Audit"
            static let templates = "/CenturiesMutual/Templates"
        }
        
        // Metadata tags for organization
        struct Metadata {
            static let enrollmentId = "cm_enrollment_id"
            static let userId = "cm_user_id"
            static let planType = "cm_plan_type"
            static let documentType = "cm_document_type"
            static let messageThread = "cm_message_thread"
            static let status = "cm_status"
            static let lastSync = "cm_last_sync"
        }
    }
    
    enum SyncStatus {
        case idle
        case syncing
        case error(String)
        case completed
    }
    
    private override init() {
        super.init()
        setupDropbox()
    }
    
    // MARK: - Setup & Authentication
    private func setupDropbox() {
        DropboxClientsManager.setupWithAppKey(Config.appKey)
        checkAuthenticationStatus()
    }
    
    func authenticateIfNeeded() -> AnyPublisher<Bool, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(DropboxError.authenticationFailed))
                return
            }
            
            if DropboxClientsManager.authorizedClient != nil {
                self.isAuthenticated = true
                promise(.success(true))
            } else {
                self.startOAuthAuthentication { success in
                    self.isAuthenticated = success
                    if success {
                        promise(.success(true))
                    } else {
                        promise(.failure(DropboxError.authenticationFailed))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func startOAuthAuthentication(completion: @escaping (Bool) -> Void) {
        guard let viewController = UIApplication.shared.windows.first?.rootViewController else {
            completion(false)
            return
        }
        
        DropboxClientsManager.authorizeFromController(
            UIApplication.shared,
            controller: viewController,
            openURL: { (url: URL) -> Void in
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        )
        
        // Handle OAuth callback in AppDelegate/SceneDelegate
        completion(true)
    }
    
    private func checkAuthenticationStatus() {
        isAuthenticated = DropboxClientsManager.authorizedClient != nil
    }
    
    // MARK: - File Management
    func uploadFile(
        data: Data,
        fileName: String,
        folderPath: String,
        metadata: [String: String] = [:],
        enrollmentId: String? = nil
    ) -> AnyPublisher<DropboxFileInfo, Error> {
        return Future { [weak self] promise in
            guard let client = DropboxClientsManager.authorizedClient?.files else {
                promise(.failure(DropboxError.notAuthenticated))
                return
            }
            
            let fullPath = "\(folderPath)/\(fileName)"
            var fileMetadata = metadata
            
            // Add enrollment tracking metadata
            if let enrollmentId = enrollmentId {
                fileMetadata[Config.Metadata.enrollmentId] = enrollmentId
            }
            fileMetadata[Config.Metadata.lastSync] = ISO8601DateFormatter().string(from: Date())
            
            // Upload with metadata
            client.upload(
                path: fullPath,
                input: data,
                propertyGroups: self?.createPropertyGroups(from: fileMetadata)
            ).response { response, error in
                if let error = error {
                    promise(.failure(DropboxError.uploadFailed(error.description)))
                } else if let fileMetadata = response {
                    let fileInfo = DropboxFileInfo(
                        id: fileMetadata.id,
                        name: fileMetadata.name,
                        path: fileMetadata.pathLower ?? fullPath,
                        size: fileMetadata.size,
                        lastModified: fileMetadata.clientModified,
                        contentHash: fileMetadata.contentHash,
                        metadata: fileMetadata,
                        isFolder: false
                    )
                    promise(.success(fileInfo))
                }
            }.progress { [weak self] progressData in
                self?.uploadProgress[fileName] = Double(progressData.completedUnitCount) / Double(progressData.totalUnitCount)
            }
        }
        .eraseToAnyPublisher()
    }
    
    func downloadFile(path: String) -> AnyPublisher<Data, Error> {
        return Future { promise in
            guard let client = DropboxClientsManager.authorizedClient?.files else {
                promise(.failure(DropboxError.notAuthenticated))
                return
            }
            
            client.download(path: path).response { response, error in
                if let error = error {
                    promise(.failure(DropboxError.downloadFailed(error.description)))
                } else if let (_, data) = response {
                    promise(.success(data))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func createFolder(path: String) -> AnyPublisher<String, Error> {
        return Future { promise in
            guard let client = DropboxClientsManager.authorizedClient?.files else {
                promise(.failure(DropboxError.notAuthenticated))
                return
            }
            
            client.createFolderV2(path: path).response { response, error in
                if let error = error {
                    promise(.failure(DropboxError.folderCreationFailed(error.description)))
                } else if let metadata = response {
                    promise(.success(metadata.metadata.pathLower ?? path))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Versioning Support
    func getFileVersions(path: String) -> AnyPublisher<[DropboxFileVersion], Error> {
        return Future { promise in
            guard let client = DropboxClientsManager.authorizedClient?.files else {
                promise(.failure(DropboxError.notAuthenticated))
                return
            }
            
            client.listRevisions(path: path).response { response, error in
                if let error = error {
                    promise(.failure(DropboxError.versioningFailed(error.description)))
                } else if let revisions = response?.entries {
                    let versions = revisions.map { revision in
                        DropboxFileVersion(
                            id: revision.id,
                            serverModified: revision.serverModified,
                            size: revision.size,
                            contentHash: revision.contentHash
                        )
                    }
                    promise(.success(versions))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func restoreFileVersion(path: String, versionId: String) -> AnyPublisher<Bool, Error> {
        return Future { promise in
            guard let client = DropboxClientsManager.authorizedClient?.files else {
                promise(.failure(DropboxError.notAuthenticated))
                return
            }
            
            client.restore(path: path, rev: versionId).response { response, error in
                if let error = error {
                    promise(.failure(DropboxError.restoreFailed(error.description)))
                } else {
                    promise(.success(true))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Sharing & Collaboration
    func createSharedLink(
        path: String,
        password: String? = nil,
        expirationDate: Date? = nil
    ) -> AnyPublisher<String, Error> {
        return Future { promise in
            guard let client = DropboxClientsManager.authorizedClient?.sharing else {
                promise(.failure(DropboxError.notAuthenticated))
                return
            }
            
            var settings = Files.SharedLinkSettings()
            
            if let password = password {
                settings = settings.withLinkPassword(password)
            }
            
            if let expiration = expirationDate {
                settings = settings.withExpires(expiration)
            }
            
            client.createSharedLinkWithSettings(path: path, settings: settings).response { response, error in
                if let error = error {
                    promise(.failure(DropboxError.sharingFailed(error.description)))
                } else if let sharedLink = response?.url {
                    promise(.success(sharedLink))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func shareFolder(
        path: String,
        emails: [String],
        accessLevel: AccessLevel = .viewer
    ) -> AnyPublisher<String, Error> {
        return Future { promise in
            guard let client = DropboxClientsManager.authorizedClient?.sharing else {
                promise(.failure(DropboxError.notAuthenticated))
                return
            }
            
            let membershipInfo = emails.map { email in
                Sharing.AddMember.memberEmail(email).withAccessLevel(accessLevel.toDropboxAccessLevel())
            }
            
            client.shareFolder(path: path).response { response, error in
                if let error = error {
                    promise(.failure(DropboxError.sharingFailed(error.description)))
                } else if let sharedFolder = response {
                    // Add members to the shared folder
                    client.addFolderMember(sharedFolderId: sharedFolder.sharedFolderId, members: membershipInfo).response { _, memberError in
                        if let memberError = memberError {
                            promise(.failure(DropboxError.sharingFailed(memberError.description)))
                        } else {
                            promise(.success(sharedFolder.sharedFolderId))
                        }
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Metadata Management
    func addMetadata(path: String, metadata: [String: String]) -> AnyPublisher<Bool, Error> {
        return Future { promise in
            guard let client = DropboxClientsManager.authorizedClient?.files else {
                promise(.failure(DropboxError.notAuthenticated))
                return
            }
            
            let propertyGroups = createPropertyGroups(from: metadata)
            
            client.propertiesAdd(path: path, propertyGroups: propertyGroups).response { response, error in
                if let error = error {
                    promise(.failure(DropboxError.metadataFailed(error.description)))
                } else {
                    promise(.success(true))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func searchFiles(query: String, folder: String = "") -> AnyPublisher<[DropboxFileInfo], Error> {
        return Future { promise in
            guard let client = DropboxClientsManager.authorizedClient?.files else {
                promise(.failure(DropboxError.notAuthenticated))
                return
            }
            
            let searchPath = folder.isEmpty ? Config.Folders.enrollments : folder
            
            client.searchV2(query: query, options: Files.SearchOptions().withPath(searchPath)).response { response, error in
                if let error = error {
                    promise(.failure(DropboxError.searchFailed(error.description)))
                } else if let matches = response?.matches {
                    let files = matches.compactMap { match -> DropboxFileInfo? in
                        guard let metadata = match.metadata.asMetadata else { return nil }
                        return DropboxFileInfo(
                            id: metadata.id,
                            name: metadata.name,
                            path: metadata.pathLower ?? "",
                            size: metadata.size,
                            lastModified: metadata.clientModified,
                            contentHash: metadata.contentHash,
                            metadata: metadata,
                            isFolder: metadata.isKind(of: Files.FolderMetadata.self)
                        )
                    }
                    promise(.success(files))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Webhook Integration
    func setupWebhook(url: String) -> AnyPublisher<String, Error> {
        return Future { promise in
            // Implementation for webhook setup
            // This would typically be done server-side
            promise(.success("webhook_id"))
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    private func createPropertyGroups(from metadata: [String: String]) -> [FileProperties.PropertyGroup] {
        let fields = metadata.map { key, value in
            FileProperties.PropertyField(name: key, value: value)
        }
        
        let propertyGroup = FileProperties.PropertyGroup(
            templateId: "centuries_mutual_template",
            fields: fields
        )
        
        return [propertyGroup]
    }
}

// MARK: - Supporting Models
struct DropboxFileInfo: Codable {
    let id: String
    let name: String
    let path: String
    let size: UInt64
    let lastModified: Date
    let contentHash: String?
    let metadata: Files.FileMetadata
    let isFolder: Bool
    
    init(id: String, name: String, path: String, size: UInt64, lastModified: Date, contentHash: String?, metadata: Files.FileMetadata, isFolder: Bool) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.lastModified = lastModified
        self.contentHash = contentHash
        self.metadata = metadata
        self.isFolder = isFolder
    }
}

struct DropboxFileVersion {
    let id: String
    let serverModified: Date
    let size: UInt64
    let contentHash: String?
}

enum AccessLevel {
    case viewer
    case editor
    case owner
    
    func toDropboxAccessLevel() -> Sharing.AccessLevel {
        switch self {
        case .viewer:
            return .viewer
        case .editor:
            return .editor  
        case .owner:
            return .owner
        }
    }
}

enum DropboxError: LocalizedError {
    case notAuthenticated
    case authenticationFailed
    case uploadFailed(String)
    case downloadFailed(String)
    case folderCreationFailed(String)
    case versioningFailed(String)
    case restoreFailed(String)
    case sharingFailed(String)
    case metadataFailed(String)
    case searchFailed(String)
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Dropbox"
        case .authenticationFailed:
            return "Dropbox authentication failed"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .folderCreationFailed(let message):
            return "Folder creation failed: \(message)"
        case .versioningFailed(let message):
            return "Versioning operation failed: \(message)"
        case .restoreFailed(let message):
            return "File restore failed: \(message)"
        case .sharingFailed(let message):
            return "Sharing operation failed: \(message)"
        case .metadataFailed(let message):
            return "Metadata operation failed: \(message)"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}

// MARK: - Integration with Existing App Context
extension AppContext {
    var dropboxManager: DropboxManager {
        return DropboxManager.shared
    }
    
    func setupDropboxIntegration() {
        dropboxManager.authenticateIfNeeded()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Dropbox authentication failed: \(error)")
                    }
                },
                receiveValue: { success in
                    print("Dropbox authentication: \(success ? "Success" : "Failed")")
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - AppDelegate Integration
extension AppDelegate {
    func setupDropboxIntegration() {
        // Initialize Dropbox in app launch
        AppContext.shared.setupDropboxIntegration()
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle Dropbox OAuth callback
        if let authResult = DropboxClientsManager.handleRedirectURL(url) {
            switch authResult {
            case .success:
                DropboxManager.shared.isAuthenticated = true
                print("Dropbox authentication successful")
            case .cancel:
                print("Dropbox authentication cancelled")
            case .error(_, let description):
                print("Dropbox authentication error: \(description)")
            }
            return true
        }
        
        // Continue with existing URL handling
        return false
    }
}