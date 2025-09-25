import SwiftUI

struct RadioView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var stationFinder = StationFinder()
    @StateObject private var radioPlayer = RadioPlayer()
    
    @State private var showLocationAlert = false
    @State private var isRadioEnabled = false
    @State private var showStationList = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient inspired by golden branch on forest green
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.11, green: 0.30, blue: 0.24), // Deep forest green
                        Color(red: 0.08, green: 0.22, blue: 0.18)  // Darker forest green
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 16) {
                            Text("Centuries Mutual Radio")
                                .font(.custom("Playfair Display", size: 32))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Location-based public radio streaming")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Radio Status Card
                        if isRadioEnabled {
                            RadioStatusCard(
                                station: radioPlayer.currentStation,
                                isPlaying: radioPlayer.isPlaying,
                                connectionStatus: radioPlayer.connectionStatus,
                                onPlayPause: {
                                    if radioPlayer.isPlaying {
                                        radioPlayer.pause()
                                    } else {
                                        if let station = stationFinder.nearestStation {
                                            radioPlayer.playStation(station)
                                        } else {
                                            radioPlayer.play()
                                        }
                                    }
                                }
                            )
                            .padding(.horizontal)
                        }
                        
                        // Radio Controls
                        VStack(spacing: 20) {
                            // Enable/Disable Radio
                            Button(action: toggleRadio) {
                                HStack {
                                    Image(systemName: isRadioEnabled ? "radio.fill" : "radio")
                                        .font(.title2)
                                    Text(isRadioEnabled ? "Radio Enabled" : "Enable Radio")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isRadioEnabled ? Color(red: 0.83, green: 0.69, blue: 0.22) : Color(red: 0.83, green: 0.69, blue: 0.22).opacity(0.3))
                                .foregroundColor(isRadioEnabled ? Color(red: 0.11, green: 0.30, blue: 0.24) : Color(red: 0.96, green: 0.89, blue: 0.74))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(red: 0.96, green: 0.89, blue: 0.74).opacity(0.4), lineWidth: 1)
                                )
                            }
                            
                            // Station List Button
                            if isRadioEnabled {
                                Button(action: { showStationList = true }) {
                                    HStack {
                                        Image(systemName: "list.bullet")
                                            .font(.title2)
                                        Text("View All Stations")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.2))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(red: 0.96, green: 0.89, blue: 0.74).opacity(0.4), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Location Status
                        if isRadioEnabled {
                            VStack(spacing: 16) {
                                Text("Location Status")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                VStack(spacing: 12) {
                                    LocationStatusRow(
                                        title: "Location Access",
                                        status: locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways ? "Enabled" : "Disabled",
                                        isEnabled: locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways
                                    )
                                    
                                    if let location = locationManager.currentLocation {
                                        LocationStatusRow(
                                            title: "Current Location",
                                            status: "\(location.coordinate.latitude, specifier: "%.4f"), \(location.coordinate.longitude, specifier: "%.4f")",
                                            isEnabled: true
                                        )
                                    }
                                    
                                    if let station = stationFinder.nearestStation {
                                        LocationStatusRow(
                                            title: "Nearest Station",
                                            status: "\(station.name) - \(station.region)",
                                            isEnabled: true
                                        )
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // Error Display
                        if let error = locationManager.locationError {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.title)
                                    .foregroundColor(.orange)
                                
                                Text("Location Error")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(error)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                
                                Button("Open Settings") {
                                    locationManager.openSettings()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.white)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .onAppear {
            setupRadioIfNeeded()
        }
        .onChange(of: locationManager.currentLocation) { location in
            handleLocationUpdate(location)
        }
        .alert("Location Permission Required", isPresented: $showLocationAlert) {
            Button("Settings") {
                locationManager.openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Location access is needed to find nearby radio stations. Please enable it in Settings.")
        }
        .sheet(isPresented: $showStationList) {
            StationListView(
                stations: stationFinder.getAllStations(),
                currentStation: stationFinder.nearestStation,
                onStationSelected: { station in
                    radioPlayer.playStation(station)
                    showStationList = false
                }
            )
        }
    }
    
    private func setupRadioIfNeeded() {
        if isRadioEnabled && !locationManager.isLocationEnabled {
            locationManager.requestLocationPermission()
        }
    }
    
    private func toggleRadio() {
        isRadioEnabled.toggle()
        
        if isRadioEnabled {
            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                showLocationAlert = true
                isRadioEnabled = false
                return
            }
            locationManager.requestLocationPermission()
        } else {
            radioPlayer.stop()
            locationManager.stopLocationUpdates()
        }
    }
    
    private func handleLocationUpdate(_ location: CLLocation?) {
        guard let location = location, isRadioEnabled else { return }
        
        if stationFinder.updateNearestStation(for: location) {
            if let newStation = stationFinder.nearestStation {
                if radioPlayer.isPlaying {
                    radioPlayer.playStation(newStation)
                }
            }
        }
    }
}

struct LocationStatusRow: View {
    let title: String
    let status: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(status)
                .font(.subheadline)
                .foregroundColor(isEnabled ? .green : .orange)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

struct StationListView: View {
    let stations: [RadioStation]
    let currentStation: RadioStation?
    let onStationSelected: (RadioStation) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(stations) { station in
                StationRow(
                    station: station,
                    isCurrent: station.id == currentStation?.id,
                    onTap: { onStationSelected(station) }
                )
            }
            .navigationTitle("Radio Stations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StationRow: View {
    let station: RadioStation
    let isCurrent: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(station.region)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let frequency = station.frequency {
                        Text(frequency)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    RadioView()
}
