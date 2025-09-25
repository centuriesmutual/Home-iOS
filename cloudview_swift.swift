import SwiftUI
import WebKit

// MARK: - Data Models
struct Video: Identifiable, Codable {
    let id: String // YouTube videoId
    let title: String
    let description: String
    let thumbnailURL: String?
    let duration: String?
    let viewCount: String?
    let publishedAt: String?
    
    init(id: String, title: String, description: String, thumbnailURL: String? = nil, duration: String? = nil, viewCount: String? = nil, publishedAt: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.viewCount = viewCount
        self.publishedAt = publishedAt
    }
}

struct FeedResponse: Codable {
    let trending: [Video]
    let recommended: [Video]
    let personalized: [Video]?
}

// MARK: - YouTube API Service
class YouTubeAPIService: ObservableObject {
    private let apiKey = "YOUR_YOUTUBE_API_KEY" // Replace with your actual API key
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    
    func fetchRecommendations(for userId: String, completion: @escaping (FeedResponse?) -> Void) {
        // Mock implementation - replace with actual YouTube Data API calls
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let mockResponse = FeedResponse(
                trending: [
                    Video(id: "dQw4w9WgXcQ", title: "10 Daily Habits for Better Health", description: "Transform your wellness with these simple daily practices", thumbnailURL: "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg", duration: "8:45", viewCount: "2.3M"),
                    Video(id: "abc123xyz", title: "Understanding Your Health Insurance", description: "Complete guide to navigating health coverage options", thumbnailURL: "https://img.youtube.com/vi/abc123xyz/maxresdefault.jpg", duration: "12:30", viewCount: "856K")
                ],
                recommended: [
                    Video(id: "xyz789abc", title: "Mindfulness for Mental Health", description: "Guided meditation and breathing exercises for daily wellness", thumbnailURL: "https://img.youtube.com/vi/xyz789abc/maxresdefault.jpg", duration: "15:20", viewCount: "1.7M"),
                    Video(id: "def456ghi", title: "Nutrition Basics: Eating for Energy", description: "Science-based nutrition tips for sustained energy", thumbnailURL: "https://img.youtube.com/vi/def456ghi/maxresdefault.jpg", duration: "9:15", viewCount: "945K")
                ],
                personalized: [
                    Video(id: "jkl789mno", title: "Stress Management Techniques", description: "Proven methods to reduce stress and improve well-being", thumbnailURL: "https://img.youtube.com/vi/jkl789mno/maxresdefault.jpg", duration: "11:05", viewCount: "623K")
                ]
            )
            completion(mockResponse)
        }
    }
}

// MARK: - Main CloudView
struct CloudView: View {
    @StateObject private var youtubeService = YouTubeAPIService()
    @State private var selectedTab: String = "Library"
    @State private var favorites: Set<String> = []
    @State private var selectedVideo: Video?
    @State private var feed: FeedResponse?
    @State private var isLoading: Bool = true
    @State private var showingFullScreenPlayer: Bool = false
    
    // Color scheme
    private let primaryColor = Color(red: 0.83, green: 0.69, blue: 0.22)
    private let accentColor = Color(red: 0.11, green: 0.30, blue: 0.24)
    private let backgroundColor = Color(UIColor.systemBackground)
    private let cardColor = Color(UIColor.secondarySystemBackground)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Coverage Status Card
                coverageStatusCard
                
                // Video Player Section
                if let video = selectedVideo {
                    videoPlayerSection(video: video)
                } else {
                    emptyPlayerSection
                }
                
                // Tab Selector
                tabSelector
                
                // Video Content
                videoContent
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Health Videos")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadFavorites()
                fetchContent()
            }
        }
    }
    
    // MARK: - UI Components
    
    private var coverageStatusCard: some View {
        HStack {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.green)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Health Insurance Status")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Active Coverage")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            Button(action: {}) {
                Text("Details")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(primaryColor.opacity(0.1))
                    .foregroundColor(primaryColor)
                    .cornerRadius(15)
            }
        }
        .padding()
        .background(cardColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private func videoPlayerSection(video: Video) -> some View {
        VStack(spacing: 16) {
            // YouTube Player
            YouTubePlayerView(videoID: video.id)
                .frame(height: 220)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            
            // Video Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text(video.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    
                    Spacer()
                    
                    // Favorite Button
                    favoriteButton(for: video)
                }
                
                // Video metadata
                if let duration = video.duration, let viewCount = video.viewCount {
                    HStack(spacing: 16) {
                        Label(duration, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(viewCount + " views", systemImage: "eye")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var emptyPlayerSection: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 220)
                .overlay(
                    VStack {
                        Image(systemName: "play.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Select a video to play")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                )
            
            Text("Choose from our curated health and wellness content below")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var tabSelector: some View {
        Picker("Tab", selection: $selectedTab) {
            Text("Library").tag("Library")
            Text("Favorites").tag("Favorites")
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private var videoContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading {
                    loadingView
                } else if selectedTab == "Library" {
                    libraryContent
                } else {
                    favoritesContent
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading health videos...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 50)
    }
    
    @ViewBuilder
    private var libraryContent: some View {
        if let feed = feed {
            // Trending Section
            sectionHeader(title: "Trending Now", icon: "flame.fill", color: .orange)
            ForEach(feed.trending) { video in
                VideoRow(video: video, isFavorite: favorites.contains(video.id)) {
                    selectedVideo = video
                } favoriteAction: {
                    toggleFavorite(video.id)
                }
            }
            
            // Recommended Section
            sectionHeader(title: "Recommended for You", icon: "heart.fill", color: accentColor)
            ForEach(feed.recommended) { video in
                VideoRow(video: video, isFavorite: favorites.contains(video.id)) {
                    selectedVideo = video
                } favoriteAction: {
                    toggleFavorite(video.id)
                }
            }
            
            // Personalized Section
            if let personalized = feed.personalized, !personalized.isEmpty {
                sectionHeader(title: "Based on Your Interests", icon: "person.fill", color: primaryColor)
                ForEach(personalized) { video in
                    VideoRow(video: video, isFavorite: favorites.contains(video.id)) {
                        selectedVideo = video
                    } favoriteAction: {
                        toggleFavorite(video.id)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var favoritesContent: some View {
        if let feed = feed {
            let allVideos = feed.trending + feed.recommended + (feed.personalized ?? [])
            let favoriteVideos = allVideos.filter { favorites.contains($0.id) }
            
            if favoriteVideos.isEmpty {
                emptyFavoritesView
            } else {
                sectionHeader(title: "Your Favorites", icon: "heart.fill", color: accentColor)
                ForEach(favoriteVideos) { video in
                    VideoRow(video: video, isFavorite: true) {
                        selectedVideo = video
                    } favoriteAction: {
                        toggleFavorite(video.id)
                    }
                }
            }
        }
    }
    
    private var emptyFavoritesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Favorites Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Tap the heart icon on videos you love to add them to your favorites")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 50)
    }
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.top)
    }
    
    private func favoriteButton(for video: Video) -> some View {
        Button(action: { toggleFavorite(video.id) }) {
            Image(systemName: favorites.contains(video.id) ? "heart.fill" : "heart")
                .font(.title2)
                .foregroundColor(favorites.contains(video.id) ? accentColor : .gray)
                .scaleEffect(favorites.contains(video.id) ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: favorites.contains(video.id))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private func toggleFavorite(_ videoId: String) {
        if favorites.contains(videoId) {
            favorites.remove(videoId)
        } else {
            favorites.insert(videoId)
        }
        saveFavorites()
    }
    
    private func loadFavorites() {
        if let savedFavorites = UserDefaults.standard.array(forKey: "health_video_favorites") as? [String] {
            favorites = Set(savedFavorites)
        }
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(Array(favorites), forKey: "health_video_favorites")
    }
    
    private func fetchContent() {
        isLoading = true
        youtubeService.fetchRecommendations(for: "user123") { fetchedFeed in
            DispatchQueue.main.async {
                self.feed = fetchedFeed
                self.isLoading = false
                
                // Auto-select first video if none selected
                if self.selectedVideo == nil, let firstVideo = fetchedFeed?.trending.first {
                    self.selectedVideo = firstVideo
                }
            }
        }
    }
}

// MARK: - Video Row Component
struct VideoRow: View {
    let video: Video
    let isFavorite: Bool
    let playAction: () -> Void
    let favoriteAction: () -> Void
    
    private let accentColor = Color(red: 0.11, green: 0.30, blue: 0.24)
    private let cardColor = Color(UIColor.secondarySystemBackground)
    
    var body: some View {
        Button(action: playAction) {
            HStack(spacing: 12) {
                // Thumbnail
                AsyncImage(url: URL(string: video.thumbnailURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "play.rectangle.fill")
                                .font(.title)
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 120, height: 68)
                .cornerRadius(8)
                .clipped()
                
                // Video Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(video.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let duration = video.duration, let viewCount = video.viewCount {
                        HStack(spacing: 8) {
                            Text(duration)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            
                            Text(viewCount + " views")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Favorite Button
                Button(action: favoriteAction) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundColor(isFavorite ? primaryColor : .gray)
                        .scaleEffect(isFavorite ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFavorite)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(cardColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - YouTube Player Component
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = UIColor.clear
        webView.isOpaque = false
        
        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { margin: 0; padding: 0; background: #000; }
                .video-container { position: relative; width: 100%; height: 100vh; }
                iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
            </style>
        </head>
        <body>
            <div class="video-container">
                <iframe src="https://www.youtube.com/embed/\(videoID)?playsinline=1&rel=0&modestbranding=1&controls=1" 
                        frameborder="0" 
                        allowfullscreen>
                </iframe>
            </div>
        </body>
        </html>
        """
        
        webView.loadHTMLString(embedHTML, baseURL: nil)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Update only if video ID changes
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        CloudView()
    }
}