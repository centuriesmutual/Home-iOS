import SwiftUI

@main
struct CenturiesMutualApp: App {
    @StateObject private var appContext = AppContext()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appContext)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Initialize Circle API
        appContext.setupCircleIntegration()
        
        // Initialize Dropbox
        appContext.setupDropboxIntegration()
        
        // Initialize SQL Manager
        _ = SQLManager.shared
        
        // Setup user earnings manager if user is logged in
        if let userId = UserDefaults.standard.string(forKey: "current_user_id") {
            appContext.setupUserEarningsManager(for: userId)
        }
    }
}

// MARK: - App Context for Dependency Injection
class AppContext: ObservableObject {
    var circleAPI: CircleAPIService?
    var adminManager: AdminDashboardManager?
    var currentUserEarningsManager: UserEarningsManager?
    var dropboxManager: DropboxManager = DropboxManager.shared
    
    func setupCircleIntegration() {
        do {
            let circleAPI = CircleAPIService()
            try circleAPI.initialize(apiKey: CenturiesMutualConfig.shared.getCurrentAPIKey())
            self.circleAPI = circleAPI
            
            if UserDefaults.standard.bool(forKey: "is_admin_user") {
                let adminManager = AdminDashboardManager(
                    circleAPI: circleAPI,
                    edwardJonesAccountId: CenturiesMutualConfig.CircleConfig.edwardJonesAccountId
                )
                self.adminManager = adminManager
            }
        } catch {
            print("Failed to initialize Circle API: \(error)")
        }
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
    
    func setupUserEarningsManager(for userId: String) {
        guard let circleAPI = circleAPI else {
            print("Circle API not initialized")
            return
        }
        
        currentUserEarningsManager = UserEarningsManager(circleAPI: circleAPI, userId: userId)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
