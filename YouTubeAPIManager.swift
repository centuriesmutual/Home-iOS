import Foundation
import AVFoundation

// MARK: - YouTube API Manager
class YouTubeAPIManager: ObservableObject {
    static let shared = YouTubeAPIManager()
    
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let dataAPIURL = "https://www.googleapis.com/youtube/data/v3"
    
    @Published var searchResults: [YouTubeVideo] = []
    @Published var playlists: [YouTubePlaylist] = []
    @Published var channels: [YouTubeChannel] = []
    @Published var currentVideo: YouTubeVideo?
    @Published var isPlaying = false
    @Published var isLoading = false
    
    private var apiKey: String
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    
    private init() {
        self.apiKey = CenturiesMutualConfig.shared.youtubeAPIKey
    }
    
    // MARK: - Video Search
    func searchVideos(
        query: String,
        maxResults: Int = 25,
        order: YouTubeSearchOrder = .relevance,
        duration: YouTubeDuration? = nil,
        definition: YouTubeDefinition? = nil
    ) async throws -> [YouTubeVideo] {
        isLoading = true
        defer { isLoading = false }
        
        let url = URL(string: "\(baseURL)/search")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "order", value: order.rawValue)
        ]
        
        if let duration = duration {
            queryItems.append(URLQueryItem(name: "videoDuration", value: duration.rawValue))
        }
        
        if let definition = definition {
            queryItems.append(URLQueryItem(name: "videoDefinition", value: definition.rawValue))
        }
        
        components.queryItems = queryItems
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YouTubeError.searchFailed
        }
        
        let searchResponse = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
        self.searchResults = searchResponse.items.compactMap { $0.video }
        return self.searchResults
    }
    
    // MARK: - Video Details
    func getVideoDetails(videoId: String) async throws -> YouTubeVideoDetails {
        let url = URL(string: "\(baseURL)/videos")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails,statistics,status"),
            URLQueryItem(name: "id", value: videoId)
        ]
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YouTubeError.videoDetailsFailed
        }
        
        let videoResponse = try JSONDecoder().decode(YouTubeVideoDetailsResponse.self, from: data)
        guard let video = videoResponse.items.first else {
            throw YouTubeError.videoNotFound
        }
        
        return video
    }
    
    // MARK: - Playlist Management
    func getPlaylists(channelId: String? = nil, maxResults: Int = 25) async throws -> [YouTubePlaylist] {
        let url = URL(string: "\(baseURL)/playlists")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]
        
        if let channelId = channelId {
            queryItems.append(URLQueryItem(name: "channelId", value: channelId))
        }
        
        components.queryItems = queryItems
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YouTubeError.playlistsFailed
        }
        
        let playlistsResponse = try JSONDecoder().decode(YouTubePlaylistsResponse.self, from: data)
        self.playlists = playlistsResponse.items
        return playlistsResponse.items
    }
    
    func getPlaylistItems(playlistId: String, maxResults: Int = 25) async throws -> [YouTubePlaylistItem] {
        let url = URL(string: "\(baseURL)/playlistItems")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "playlistId", value: playlistId),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YouTubeError.playlistItemsFailed
        }
        
        let itemsResponse = try JSONDecoder().decode(YouTubePlaylistItemsResponse.self, from: data)
        return itemsResponse.items
    }
    
    // MARK: - Channel Management
    func getChannels(channelId: String? = nil, username: String? = nil) async throws -> [YouTubeChannel] {
        let url = URL(string: "\(baseURL)/channels")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails,statistics")
        ]
        
        if let channelId = channelId {
            queryItems.append(URLQueryItem(name: "id", value: channelId))
        } else if let username = username {
            queryItems.append(URLQueryItem(name: "forUsername", value: username))
        }
        
        components.queryItems = queryItems
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YouTubeError.channelsFailed
        }
        
        let channelsResponse = try JSONDecoder().decode(YouTubeChannelsResponse.self, from: data)
        self.channels = channelsResponse.items
        return channelsResponse.items
    }
    
    // MARK: - Video Playback
    func playVideo(videoId: String) async throws {
        let videoDetails = try await getVideoDetails(videoId: videoId)
        
        // For audio-only playback, we'll use the audio stream URL
        let audioURL = try await getAudioStreamURL(videoId: videoId)
        
        let playerItem = AVPlayerItem(url: audioURL)
        self.playerItem = playerItem
        self.player = AVPlayer(playerItem: playerItem)
        
        // Configure audio session for background playback
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        
        self.currentVideo = YouTubeVideo(
            id: videoDetails.id,
            title: videoDetails.snippet.title,
            description: videoDetails.snippet.description,
            thumbnailURL: videoDetails.snippet.thumbnails.medium?.url ?? "",
            channelTitle: videoDetails.snippet.channelTitle,
            publishedAt: videoDetails.snippet.publishedAt,
            duration: videoDetails.contentDetails.duration
        )
        
        player?.play()
        isPlaying = true
    }
    
    func pauseVideo() {
        player?.pause()
        isPlaying = false
    }
    
    func resumeVideo() {
        player?.play()
        isPlaying = true
    }
    
    func stopVideo() {
        player?.pause()
        player = nil
        playerItem = nil
        currentVideo = nil
        isPlaying = false
    }
    
    func seekTo(time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        player?.seek(to: cmTime)
    }
    
    // MARK: - Content Management (Admin Functions)
    func uploadVideo(
        title: String,
        description: String,
        tags: [String],
        categoryId: String,
        privacyStatus: YouTubePrivacyStatus,
        videoData: Data
    ) async throws -> YouTubeUploadResponse {
        // This would require OAuth2 authentication and multipart upload
        // For now, we'll return a mock response
        throw YouTubeError.uploadNotImplemented
    }
    
    func updateVideoMetadata(
        videoId: String,
        title: String? = nil,
        description: String? = nil,
        tags: [String]? = nil,
        categoryId: String? = nil,
        privacyStatus: YouTubePrivacyStatus? = nil
    ) async throws {
        let url = URL(string: "\(baseURL)/videos")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var snippet = YouTubeVideoSnippet(
            title: title ?? "",
            description: description ?? "",
            tags: tags ?? [],
            categoryId: categoryId ?? ""
        )
        
        let updateRequest = YouTubeVideoUpdateRequest(
            id: videoId,
            snippet: snippet,
            status: privacyStatus.map { YouTubeVideoStatus(privacyStatus: $0.rawValue) }
        )
        
        request.httpBody = try JSONEncoder().encode(updateRequest)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YouTubeError.updateFailed
        }
    }
    
    func deleteVideo(videoId: String) async throws {
        let url = URL(string: "\(baseURL)/videos")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: videoId)]
        request.url = components.url
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 else {
            throw YouTubeError.deleteFailed
        }
    }
    
    // MARK: - Analytics
    func getVideoAnalytics(videoId: String, startDate: String, endDate: String) async throws -> YouTubeAnalytics {
        let url = URL(string: "\(dataAPIURL)/reports")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "ids", value: "channel==MINE"),
            URLQueryItem(name: "startDate", value: startDate),
            URLQueryItem(name: "endDate", value: endDate),
            URLQueryItem(name: "metrics", value: "views,estimatedMinutesWatched,averageViewDuration"),
            URLQueryItem(name: "filters", value: "video==\(videoId)")
        ]
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YouTubeError.analyticsFailed
        }
        
        return try JSONDecoder().decode(YouTubeAnalytics.self, from: data)
    }
    
    // MARK: - Private Methods
    private func getAudioStreamURL(videoId: String) async throws -> URL {
        // In a real implementation, you would use youtube-dl or similar to extract audio URLs
        // For now, we'll return a mock URL
        return URL(string: "https://example.com/audio/\(videoId).m4a")!
    }
}

// MARK: - Supporting Types
enum YouTubeSearchOrder: String, Codable {
    case date = "date"
    case rating = "rating"
    case relevance = "relevance"
    case title = "title"
    case videoCount = "videoCount"
    case viewCount = "viewCount"
}

enum YouTubeDuration: String, Codable {
    case any = "any"
    case short = "short" // < 4 minutes
    case medium = "medium" // 4-20 minutes
    case long = "long" // > 20 minutes
}

enum YouTubeDefinition: String, Codable {
    case any = "any"
    case high = "high"
    case standard = "standard"
}

enum YouTubePrivacyStatus: String, Codable {
    case `private` = "private"
    case unlisted = "unlisted"
    case `public` = "public"
}

struct YouTubeSearchResponse: Codable {
    let items: [YouTubeSearchItem]
    let nextPageToken: String?
    let pageInfo: YouTubePageInfo
    
    enum CodingKeys: String, CodingKey {
        case items
        case nextPageToken = "nextPageToken"
        case pageInfo = "pageInfo"
    }
}

struct YouTubeSearchItem: Codable {
    let id: YouTubeSearchItemId
    let snippet: YouTubeVideoSnippet
    
    var video: YouTubeVideo? {
        guard let videoId = id.videoId else { return nil }
        return YouTubeVideo(
            id: videoId,
            title: snippet.title,
            description: snippet.description,
            thumbnailURL: snippet.thumbnails.medium?.url ?? "",
            channelTitle: snippet.channelTitle,
            publishedAt: snippet.publishedAt,
            duration: nil
        )
    }
}

struct YouTubeSearchItemId: Codable {
    let videoId: String?
    let channelId: String?
    let playlistId: String?
    
    enum CodingKeys: String, CodingKey {
        case videoId = "videoId"
        case channelId = "channelId"
        case playlistId = "playlistId"
    }
}

struct YouTubeVideo: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: String
    let channelTitle: String
    let publishedAt: String
    let duration: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description
        case thumbnailURL = "thumbnail_url"
        case channelTitle = "channel_title"
        case publishedAt = "published_at"
        case duration
    }
}

struct YouTubeVideoDetails: Codable {
    let id: String
    let snippet: YouTubeVideoSnippet
    let contentDetails: YouTubeContentDetails
    let statistics: YouTubeVideoStatistics
    let status: YouTubeVideoStatus
}

struct YouTubeVideoSnippet: Codable {
    let title: String
    let description: String
    let tags: [String]
    let categoryId: String
    let channelTitle: String
    let channelId: String
    let publishedAt: String
    let thumbnails: YouTubeThumbnails
    
    enum CodingKeys: String, CodingKey {
        case title, description, tags
        case categoryId = "categoryId"
        case channelTitle = "channelTitle"
        case channelId = "channelId"
        case publishedAt = "publishedAt"
        case thumbnails
    }
}

struct YouTubeContentDetails: Codable {
    let duration: String
    let dimension: String
    let definition: String
    let caption: String
    let licensedContent: Bool
    
    enum CodingKeys: String, CodingKey {
        case duration, dimension, definition, caption
        case licensedContent = "licensedContent"
    }
}

struct YouTubeVideoStatistics: Codable {
    let viewCount: String
    let likeCount: String
    let dislikeCount: String?
    let favoriteCount: String
    let commentCount: String
    
    enum CodingKeys: String, CodingKey {
        case viewCount = "viewCount"
        case likeCount = "likeCount"
        case dislikeCount = "dislikeCount"
        case favoriteCount = "favoriteCount"
        case commentCount = "commentCount"
    }
}

struct YouTubeVideoStatus: Codable {
    let privacyStatus: String
    let uploadStatus: String?
    let license: String?
    
    enum CodingKeys: String, CodingKey {
        case privacyStatus = "privacyStatus"
        case uploadStatus = "uploadStatus"
        case license
    }
}

struct YouTubeThumbnails: Codable {
    let `default`: YouTubeThumbnail?
    let medium: YouTubeThumbnail?
    let high: YouTubeThumbnail?
    let standard: YouTubeThumbnail?
    let maxres: YouTubeThumbnail?
}

struct YouTubeThumbnail: Codable {
    let url: String
    let width: Int
    let height: Int
}

struct YouTubePageInfo: Codable {
    let totalResults: Int
    let resultsPerPage: Int
    
    enum CodingKeys: String, CodingKey {
        case totalResults = "totalResults"
        case resultsPerPage = "resultsPerPage"
    }
}

struct YouTubeVideoDetailsResponse: Codable {
    let items: [YouTubeVideoDetails]
}

struct YouTubePlaylist: Codable, Identifiable {
    let id: String
    let snippet: YouTubePlaylistSnippet
    let contentDetails: YouTubePlaylistContentDetails
}

struct YouTubePlaylistSnippet: Codable {
    let title: String
    let description: String
    let channelTitle: String
    let channelId: String
    let publishedAt: String
    let thumbnails: YouTubeThumbnails
    
    enum CodingKeys: String, CodingKey {
        case title, description
        case channelTitle = "channelTitle"
        case channelId = "channelId"
        case publishedAt = "publishedAt"
        case thumbnails
    }
}

struct YouTubePlaylistContentDetails: Codable {
    let itemCount: Int
    
    enum CodingKeys: String, CodingKey {
        case itemCount = "itemCount"
    }
}

struct YouTubePlaylistsResponse: Codable {
    let items: [YouTubePlaylist]
    let nextPageToken: String?
    let pageInfo: YouTubePageInfo
    
    enum CodingKeys: String, CodingKey {
        case items
        case nextPageToken = "nextPageToken"
        case pageInfo = "pageInfo"
    }
}

struct YouTubePlaylistItem: Codable, Identifiable {
    let id: String
    let snippet: YouTubePlaylistItemSnippet
    let contentDetails: YouTubePlaylistItemContentDetails
}

struct YouTubePlaylistItemSnippet: Codable {
    let title: String
    let description: String
    let channelTitle: String
    let channelId: String
    let publishedAt: String
    let thumbnails: YouTubeThumbnails
    let resourceId: YouTubeResourceId
    
    enum CodingKeys: String, CodingKey {
        case title, description
        case channelTitle = "channelTitle"
        case channelId = "channelId"
        case publishedAt = "publishedAt"
        case thumbnails
        case resourceId = "resourceId"
    }
}

struct YouTubePlaylistItemContentDetails: Codable {
    let videoId: String
    let startAt: String?
    let endAt: String?
    let note: String?
    
    enum CodingKeys: String, CodingKey {
        case videoId = "videoId"
        case startAt = "startAt"
        case endAt = "endAt"
        case note
    }
}

struct YouTubeResourceId: Codable {
    let videoId: String?
    let channelId: String?
    let playlistId: String?
    
    enum CodingKeys: String, CodingKey {
        case videoId = "videoId"
        case channelId = "channelId"
        case playlistId = "playlistId"
    }
}

struct YouTubePlaylistItemsResponse: Codable {
    let items: [YouTubePlaylistItem]
    let nextPageToken: String?
    let pageInfo: YouTubePageInfo
    
    enum CodingKeys: String, CodingKey {
        case items
        case nextPageToken = "nextPageToken"
        case pageInfo = "pageInfo"
    }
}

struct YouTubeChannel: Codable, Identifiable {
    let id: String
    let snippet: YouTubeChannelSnippet
    let contentDetails: YouTubeChannelContentDetails
    let statistics: YouTubeChannelStatistics
}

struct YouTubeChannelSnippet: Codable {
    let title: String
    let description: String
    let publishedAt: String
    let thumbnails: YouTubeThumbnails
    let country: String?
    let defaultLanguage: String?
    
    enum CodingKeys: String, CodingKey {
        case title, description
        case publishedAt = "publishedAt"
        case thumbnails, country
        case defaultLanguage = "defaultLanguage"
    }
}

struct YouTubeChannelContentDetails: Codable {
    let relatedPlaylists: YouTubeRelatedPlaylists
    
    enum CodingKeys: String, CodingKey {
        case relatedPlaylists = "relatedPlaylists"
    }
}

struct YouTubeRelatedPlaylists: Codable {
    let uploads: String
    let watchHistory: String?
    let watchLater: String?
    
    enum CodingKeys: String, CodingKey {
        case uploads
        case watchHistory = "watchHistory"
        case watchLater = "watchLater"
    }
}

struct YouTubeChannelStatistics: Codable {
    let viewCount: String
    let subscriberCount: String
    let videoCount: String
    
    enum CodingKeys: String, CodingKey {
        case viewCount = "viewCount"
        case subscriberCount = "subscriberCount"
        case videoCount = "videoCount"
    }
}

struct YouTubeChannelsResponse: Codable {
    let items: [YouTubeChannel]
    let pageInfo: YouTubePageInfo
    
    enum CodingKeys: String, CodingKey {
        case items
        case pageInfo = "pageInfo"
    }
}

struct YouTubeUploadResponse: Codable {
    let id: String
    let status: String
    let uploadUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case uploadUrl = "upload_url"
    }
}

struct YouTubeVideoUpdateRequest: Codable {
    let id: String
    let snippet: YouTubeVideoSnippet?
    let status: YouTubeVideoStatus?
}

struct YouTubeAnalytics: Codable {
    let rows: [[String]]
    let columnHeaders: [YouTubeColumnHeader]
    
    enum CodingKeys: String, CodingKey {
        case rows
        case columnHeaders = "columnHeaders"
    }
}

struct YouTubeColumnHeader: Codable {
    let name: String
    let columnType: String
    let dataType: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case columnType = "columnType"
        case dataType = "dataType"
    }
}

enum YouTubeError: Error, LocalizedError {
    case searchFailed
    case videoDetailsFailed
    case videoNotFound
    case playlistsFailed
    case playlistItemsFailed
    case channelsFailed
    case updateFailed
    case deleteFailed
    case uploadNotImplemented
    case analyticsFailed
    case invalidAPIKey
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .searchFailed:
            return "Failed to search YouTube videos."
        case .videoDetailsFailed:
            return "Failed to fetch video details."
        case .videoNotFound:
            return "Video not found."
        case .playlistsFailed:
            return "Failed to fetch playlists."
        case .playlistItemsFailed:
            return "Failed to fetch playlist items."
        case .channelsFailed:
            return "Failed to fetch channel information."
        case .updateFailed:
            return "Failed to update video metadata."
        case .deleteFailed:
            return "Failed to delete video."
        case .uploadNotImplemented:
            return "Video upload not implemented in this version."
        case .analyticsFailed:
            return "Failed to fetch analytics data."
        case .invalidAPIKey:
            return "Invalid YouTube API key."
        case .networkError:
            return "Network error occurred while accessing YouTube data."
        }
    }
}
