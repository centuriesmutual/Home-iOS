import Foundation

// MARK: - Linode Hosting Configuration
class LinodeHostingConfig: ObservableObject {
    static let shared = LinodeHostingConfig()
    
    @Published var serverStatus: ServerStatus = .unknown
    @Published var deploymentStatus: DeploymentStatus = .notDeployed
    
    private let baseURL: String
    private let apiKey: String
    
    private init() {
        self.baseURL = CenturiesMutualConfig.shared.linodeBaseURL
        self.apiKey = CenturiesMutualConfig.shared.backendAPIKey
    }
    
    // MARK: - Server Management
    func checkServerStatus() async throws -> ServerStatus {
        let url = URL(string: "\(baseURL)/api/health")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LinodeError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200:
            self.serverStatus = .online
            return .online
        case 503:
            self.serverStatus = .maintenance
            return .maintenance
        default:
            self.serverStatus = .offline
            return .offline
        }
    }
    
    func deployApplication() async throws -> DeploymentResult {
        let url = URL(string: "\(baseURL)/api/deploy")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let deploymentRequest = DeploymentRequest(
            environment: "production",
            version: getCurrentAppVersion(),
            forceDeploy: false
        )
        
        request.httpBody = try JSONEncoder().encode(deploymentRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LinodeError.deploymentFailed
        }
        
        let result = try JSONDecoder().decode(DeploymentResult.self, from: data)
        self.deploymentStatus = .deployed
        return result
    }
    
    func rollbackDeployment(version: String) async throws -> DeploymentResult {
        let url = URL(string: "\(baseURL)/api/rollback")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let rollbackRequest = RollbackRequest(version: version)
        request.httpBody = try JSONEncoder().encode(rollbackRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LinodeError.rollbackFailed
        }
        
        let result = try JSONDecoder().decode(DeploymentResult.self, from: data)
        return result
    }
    
    // MARK: - Database Management
    func backupDatabase() async throws -> BackupResult {
        let url = URL(string: "\(baseURL)/api/database/backup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LinodeError.backupFailed
        }
        
        return try JSONDecoder().decode(BackupResult.self, from: data)
    }
    
    func restoreDatabase(backupId: String) async throws -> RestoreResult {
        let url = URL(string: "\(baseURL)/api/database/restore")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let restoreRequest = RestoreRequest(backupId: backupId)
        request.httpBody = try JSONEncoder().encode(restoreRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LinodeError.restoreFailed
        }
        
        return try JSONDecoder().decode(RestoreResult.self, from: data)
    }
    
    // MARK: - SSL Certificate Management
    func updateSSLCertificate() async throws -> SSLCertificateResult {
        let url = URL(string: "\(baseURL)/api/ssl/update")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LinodeError.sslUpdateFailed
        }
        
        return try JSONDecoder().decode(SSLCertificateResult.self, from: data)
    }
    
    // MARK: - Monitoring
    func getServerMetrics() async throws -> ServerMetrics {
        let url = URL(string: "\(baseURL)/api/metrics")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LinodeError.metricsFailed
        }
        
        return try JSONDecoder().decode(ServerMetrics.self, from: data)
    }
    
    func getLogs(service: String? = nil, level: LogLevel? = nil, limit: Int = 100) async throws -> [LogEntry] {
        let url = URL(string: "\(baseURL)/api/logs")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        
        if let service = service {
            queryItems.append(URLQueryItem(name: "service", value: service))
        }
        
        if let level = level {
            queryItems.append(URLQueryItem(name: "level", value: level.rawValue))
        }
        
        components.queryItems = queryItems
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LinodeError.logsFailed
        }
        
        let logsResponse = try JSONDecoder().decode(LogsResponse.self, from: data)
        return logsResponse.logs
    }
    
    // MARK: - Environment Management
    func updateEnvironmentVariables(_ variables: [String: String]) async throws -> EnvironmentUpdateResult {
        let url = URL(string: "\(baseURL)/api/environment")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let envRequest = EnvironmentUpdateRequest(variables: variables)
        request.httpBody = try JSONEncoder().encode(envRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LinodeError.environmentUpdateFailed
        }
        
        return try JSONDecoder().decode(EnvironmentUpdateResult.self, from: data)
    }
    
    func getEnvironmentVariables() async throws -> [String: String] {
        let url = URL(string: "\(baseURL)/api/environment")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LinodeError.environmentFetchFailed
        }
        
        let envResponse = try JSONDecoder().decode(EnvironmentResponse.self, from: data)
        return envResponse.variables
    }
    
    // MARK: - Private Methods
    private func getCurrentAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

// MARK: - Supporting Types
enum ServerStatus {
    case online
    case offline
    case maintenance
    case unknown
}

enum DeploymentStatus {
    case notDeployed
    case deploying
    case deployed
    case failed
}

enum LogLevel: String, Codable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case fatal = "fatal"
}

struct DeploymentRequest: Codable {
    let environment: String
    let version: String
    let forceDeploy: Bool
    
    enum CodingKeys: String, CodingKey {
        case environment, version
        case forceDeploy = "force_deploy"
    }
}

struct DeploymentResult: Codable {
    let success: Bool
    let deploymentId: String
    let version: String
    let timestamp: String
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case deploymentId = "deployment_id"
        case version, timestamp, message
    }
}

struct RollbackRequest: Codable {
    let version: String
}

struct BackupResult: Codable {
    let success: Bool
    let backupId: String
    let timestamp: String
    let size: Int
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case backupId = "backup_id"
        case timestamp, size, message
    }
}

struct RestoreRequest: Codable {
    let backupId: String
    
    enum CodingKeys: String, CodingKey {
        case backupId = "backup_id"
    }
}

struct RestoreResult: Codable {
    let success: Bool
    let timestamp: String
    let message: String?
}

struct SSLCertificateResult: Codable {
    let success: Bool
    let certificateId: String
    let expiresAt: String
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case certificateId = "certificate_id"
        case expiresAt = "expires_at"
        case message
    }
}

struct ServerMetrics: Codable {
    let cpu: CPUMetrics
    let memory: MemoryMetrics
    let disk: DiskMetrics
    let network: NetworkMetrics
    let timestamp: String
}

struct CPUMetrics: Codable {
    let usage: Double
    let cores: Int
    let loadAverage: [Double]
    
    enum CodingKeys: String, CodingKey {
        case usage, cores
        case loadAverage = "load_average"
    }
}

struct MemoryMetrics: Codable {
    let total: Int
    let used: Int
    let free: Int
    let cached: Int
    let swapTotal: Int
    let swapUsed: Int
    
    enum CodingKeys: String, CodingKey {
        case total, used, free, cached
        case swapTotal = "swap_total"
        case swapUsed = "swap_used"
    }
}

struct DiskMetrics: Codable {
    let total: Int
    let used: Int
    let free: Int
    let usage: Double
}

struct NetworkMetrics: Codable {
    let bytesIn: Int
    let bytesOut: Int
    let packetsIn: Int
    let packetsOut: Int
    
    enum CodingKeys: String, CodingKey {
        case bytesIn = "bytes_in"
        case bytesOut = "bytes_out"
        case packetsIn = "packets_in"
        case packetsOut = "packets_out"
    }
}

struct LogEntry: Codable, Identifiable {
    let id: String
    let timestamp: String
    let level: LogLevel
    let service: String
    let message: String
    let metadata: [String: String]?
}

struct LogsResponse: Codable {
    let logs: [LogEntry]
    let total: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case logs, total
        case hasMore = "has_more"
    }
}

struct EnvironmentUpdateRequest: Codable {
    let variables: [String: String]
}

struct EnvironmentUpdateResult: Codable {
    let success: Bool
    let updatedVariables: [String]
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case updatedVariables = "updated_variables"
        case message
    }
}

struct EnvironmentResponse: Codable {
    let variables: [String: String]
}

enum LinodeError: Error, LocalizedError {
    case networkError
    case deploymentFailed
    case rollbackFailed
    case backupFailed
    case restoreFailed
    case sslUpdateFailed
    case metricsFailed
    case logsFailed
    case environmentUpdateFailed
    case environmentFetchFailed
    case invalidAPIKey
    case serverUnavailable
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error occurred while communicating with Linode server."
        case .deploymentFailed:
            return "Failed to deploy application to Linode server."
        case .rollbackFailed:
            return "Failed to rollback deployment."
        case .backupFailed:
            return "Failed to backup database."
        case .restoreFailed:
            return "Failed to restore database from backup."
        case .sslUpdateFailed:
            return "Failed to update SSL certificate."
        case .metricsFailed:
            return "Failed to fetch server metrics."
        case .logsFailed:
            return "Failed to fetch server logs."
        case .environmentUpdateFailed:
            return "Failed to update environment variables."
        case .environmentFetchFailed:
            return "Failed to fetch environment variables."
        case .invalidAPIKey:
            return "Invalid API key for Linode server access."
        case .serverUnavailable:
            return "Linode server is currently unavailable."
        }
    }
}
