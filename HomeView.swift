import SwiftUI

struct HomeView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var stationFinder = StationFinder()
    @StateObject private var radioPlayer = RadioPlayer()
    
    @State private var showLocationAlert = false
    @State private var isRadioEnabled = false
    
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
                            Text("Centuries Mutual")
                                .font(.custom("Playfair Display", size: 36))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Wealth Management: Secure Your Legacy")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
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
                        
                        // Main Stats Card
                        VStack(spacing: 20) {
                            HStack(spacing: 20) {
                                StatCard(title: "$14.2M", subtitle: "Assets Under Management")
                                StatCard(title: "25+", subtitle: "Years of Excellence")
                            }
                            
                            StatCard(title: "50K+", subtitle: "Satisfied Clients")
                        }
                        .padding(.horizontal)
                        
                        // Quick Actions
                        VStack(spacing: 16) {
                            Text("Quick Actions")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                QuickActionCard(
                                    title: "Schedule Consultation",
                                    icon: "calendar",
                                    color: .white,
                                    action: { /* Navigate to schedule */ }
                                )
                                
                                QuickActionCard(
                                    title: "Learn More",
                                    icon: "info.circle",
                                    color: .white.opacity(0.1),
                                    action: { /* Navigate to learn more */ }
                                )
                                
                                QuickActionCard(
                                    title: "Tax Preparation",
                                    icon: "calculator",
                                    color: .white.opacity(0.1),
                                    action: { /* Navigate to tax */ }
                                )
                                
                                QuickActionCard(
                                    title: "Insurance",
                                    icon: "heart",
                                    color: .white.opacity(0.1),
                                    action: { /* Navigate to insurance */ }
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Radio Toggle
                        VStack(spacing: 16) {
                            Text("Radio Feature")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
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
                        }
                        .padding(.horizontal)
                        
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

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    HomeView()
}
