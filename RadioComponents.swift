import Foundation
import CoreLocation
import AVFoundation
import MediaPlayer
import Combine

// MARK: - Radio Station Model
struct RadioStation: Codable, Identifiable {
    let id = UUID()
    let name: String
    let streamURL: String
    let latitude: Double
    let longitude: Double
    let region: String
    let frequency: String?
    let description: String?
    
    /// Calculate distance from a given coordinate using Haversine formula
    func distance(from latitude: Double, longitude: Double) -> Double {
        let earthRadius = 6371.0 // Earth's radius in kilometers
        
        let lat1Rad = self.latitude * .pi / 180
        let lat2Rad = latitude * .pi / 180
        let deltaLat = (latitude - self.latitude) * .pi / 180
        let deltaLon = (longitude - self.longitude) * .pi / 180
        
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadius * c
    }
}

// MARK: - Sample Station Data
extension RadioStation {
    static let sampleStations: [RadioStation] = [
        RadioStation(
            name: "KQED FM",
            streamURL: "https://streams.kqed.org/kqedradio",
            latitude: 37.7749,
            longitude: -122.4194,
            region: "San Francisco Bay Area",
            frequency: "88.5 FM",
            description: "Northern California Public Radio"
        ),
        RadioStation(
            name: "WNYC FM",
            streamURL: "https://fm939.wnyc.org/wnycfm",
            latitude: 40.7128,
            longitude: -74.0060,
            region: "New York City",
            frequency: "93.9 FM",
            description: "New York Public Radio"
        ),
        RadioStation(
            name: "KCRW",
            streamURL: "https://kcrw.streamguys1.com/kcrw_192k_mp3_e24",
            latitude: 34.0522,
            longitude: -118.2437,
            region: "Los Angeles",
            frequency: "89.9 FM",
            description: "Santa Monica Public Radio"
        ),
        RadioStation(
            name: "WBEZ Chicago",
            streamURL: "https://stream.wbez.org/wbez128.mp3",
            latitude: 41.8781,
            longitude: -87.6298,
            region: "Chicago",
            frequency: "91.5 FM",
            description: "Chicago Public Radio"
        ),
        RadioStation(
            name: "KUOW Seattle",
            streamURL: "https://live-aacplus-64.kexp.org/kexp64.aac",
            latitude: 47.6062,
            longitude: -122.3321,
            region: "Seattle",
            frequency: "94.9 FM",
            description: "University of Washington Public Radio"
        )
    ]
}

// MARK: - Location Manager
@MainActor
class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled: Bool = false
    @Published var locationError: String?
    
    private var significantLocationChangeEnabled = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 1000 // 1km minimum distance for updates
        authorizationStatus = locationManager.authorizationStatus
    }
    
    /// Request location permission from user
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationError = "Location access is required for radio station detection. Please enable it in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        @unknown default:
            locationError = "Unknown location authorization status"
        }
    }
    
    /// Start location updates
    private func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        isLocationEnabled = true
        locationError = nil
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
            
            // Enable significant location changes for background updates
            if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                locationManager.startMonitoringSignificantLocationChanges()
                significantLocationChangeEnabled = true
            }
        }
    }
    
    /// Stop location updates
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        if significantLocationChangeEnabled {
            locationManager.stopMonitoringSignificantLocationChanges()
            significantLocationChangeEnabled = false
        }
        isLocationEnabled = false
    }
    
    /// Open device settings for location permissions
    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        locationError = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = "Failed to get location: \(error.localizedDescription)"
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            stopLocationUpdates()
            locationError = "Location access denied. Please enable it in Settings to use radio features."
        case .notDetermined:
            break
        @unknown default:
            locationError = "Unknown location authorization status"
        }
    }
}

// MARK: - Station Finder
class StationFinder: ObservableObject {
    private let stations = RadioStation.sampleStations
    @Published var nearestStation: RadioStation?
    @Published var stationChangeThresholdKm: Double = 50.0
    
    /// Find the nearest station to given coordinates
    func findNearestStation(latitude: Double, longitude: Double) -> RadioStation? {
        return stations.min { station1, station2 in
            let distance1 = station1.distance(from: latitude, longitude: longitude)
            let distance2 = station2.distance(from: latitude, longitude: longitude)
            return distance1 < distance2
        }
    }
    
    /// Update nearest station and determine if station should change
    func updateNearestStation(for location: CLLocation) -> Bool {
        let newNearestStation = findNearestStation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        guard let newStation = newNearestStation else {
            return false
        }
        
        // Check if we should change stations based on distance threshold
        if let currentStation = nearestStation {
            let distanceToNew = newStation.distance(
                from: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            let distanceToCurrent = currentStation.distance(
                from: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            // Only change if new station is significantly closer
            if distanceToNew < distanceToCurrent - stationChangeThresholdKm {
                nearestStation = newStation
                return true
            }
            return false
        } else {
            nearestStation = newStation
            return true
        }
    }
    
    /// Get all available stations
    func getAllStations() -> [RadioStation] {
        return stations
    }
}

// MARK: - Radio Player
@MainActor
class RadioPlayer: NSObject, ObservableObject {
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    @Published var isPlaying: Bool = false
    @Published var currentStation: RadioStation?
    @Published var playbackError: String?
    @Published var connectionStatus: String = "Disconnected"
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    override init() {
        super.init()
        setupAudioSession()
        setupRemoteTransportControls()
    }
    
    deinit {
        stop()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }
    
    /// Setup audio session for background playback
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try audioSession.setActive(true)
        } catch {
            playbackError = "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
    
    /// Setup remote control center for lock screen controls
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.play()
            }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }
        
        commandCenter.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.stop()
            }
            return .success
        }
    }
    
    /// Play radio station
    func playStation(_ station: RadioStation) {
        currentStation = station
        
        guard let url = URL(string: station.streamURL) else {
            playbackError = "Invalid stream URL for \(station.name)"
            return
        }
        
        // Stop current player if exists
        stop()
        
        // Create new player
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Add observer for player status
        addPlayerObservers()
        
        // Play
        player?.play()
        isPlaying = true
        connectionStatus = "Connecting..."
        playbackError = nil
        
        // Update now playing info
        updateNowPlayingInfo()
    }
    
    /// Resume playback
    func play() {
        guard let player = player else {
            if let station = currentStation {
                playStation(station)
            }
            return
        }
        
        player.play()
        isPlaying = true
        connectionStatus = "Playing"
    }
    
    /// Pause playback
    func pause() {
        player?.pause()
        isPlaying = false
        connectionStatus = "Paused"
    }
    
    /// Stop playback and cleanup
    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        connectionStatus = "Stopped"
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        // Clear now playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    /// Add observers for player status changes
    private func addPlayerObservers() {
        guard let player = player else { return }
        
        // Observe player status
        player.currentItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        
        // Observe playback stall
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidStall),
            name: .AVPlayerItemPlaybackStalled,
            object: player.currentItem
        )
        
        // Observe errors
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerFailedToPlay),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: player.currentItem
        )
    }
    
    @objc private func playerDidStall() {
        connectionStatus = "Buffering..."
    }
    
    @objc private func playerFailedToPlay() {
        playbackError = "Playback failed. Please check your internet connection."
        isPlaying = false
        connectionStatus = "Error"
    }
    
    /// Update lock screen media info
    private func updateNowPlayingInfo() {
        guard let station = currentStation else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = station.name
        nowPlayingInfo[MPMediaItemPropertyArtist] = station.region
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Centuries Mutual Radio"
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let playerItem = object as? AVPlayerItem {
                switch playerItem.status {
                case .readyToPlay:
                    connectionStatus = isPlaying ? "Playing" : "Ready"
                    playbackError = nil
                case .failed:
                    playbackError = "Failed to load stream"
                    isPlaying = false
                    connectionStatus = "Error"
                case .unknown:
                    connectionStatus = "Loading..."
                @unknown default:
                    break
                }
            }
        }
    }
}

// MARK: - Radio Status Card Component
struct RadioStatusCard: View {
    let station: RadioStation?
    let isPlaying: Bool
    let connectionStatus: String
    let onPlayPause: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(station?.name ?? "No Station")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(station?.region ?? "Unknown Region")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(connectionStatus)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            .disabled(station == nil)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var statusColor: Color {
        switch connectionStatus.lowercased() {
        case "playing": return .green
        case "paused", "stopped": return .orange
        case "error": return .red
        default: return .gray
        }
    }
}
