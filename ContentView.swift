import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appContext: AppContext
    @State private var selectedTab = 0
    @State private var isLoggedIn = false
    
    var body: some View {
        Group {
            if isLoggedIn {
                MainTabView(selectedTab: $selectedTab)
                    .environmentObject(appContext)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
        .onAppear {
            checkLoginStatus()
        }
    }
    
    private func checkLoginStatus() {
        isLoggedIn = UserDefaults.standard.bool(forKey: "is_logged_in")
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var appContext: AppContext
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            ServicesView()
                .tabItem {
                    Image(systemName: "briefcase.fill")
                    Text("Services")
                }
                .tag(1)
            
            WalletView()
                .tabItem {
                    Image(systemName: "creditcard.fill")
                    Text("Wallet")
                }
                .tag(2)
            
            EnrollmentView()
                .tabItem {
                    Image(systemName: "doc.text.fill")
                    Text("Enroll")
                }
                .tag(3)
            
            RadioView()
                .tabItem {
                    Image(systemName: "radio.fill")
                    Text("Radio")
                }
                .tag(4)
            
            MessagesView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Messages")
                }
                .tag(5)
        }
        .accentColor(Color(red: 0.83, green: 0.69, blue: 0.22)) // Golden branch color
    }
}

#Preview {
    ContentView()
        .environmentObject(AppContext())
}
