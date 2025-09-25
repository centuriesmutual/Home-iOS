import SwiftUI
import MessageUI

// MARK: - Main App
struct ContentView: View {
    @State private var currentScreen: AppScreen = .splash
    @State private var showingSplash = true
    
    enum AppScreen {
        case splash, home, mailbox, cloudNetwork, wallet
    }
    
    var body: some View {
        ZStack {
            // Background
            Image("background") // You'll need to add this vintage map background
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.3)
            
            switch currentScreen {
            case .splash:
                SplashScreen()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                currentScreen = .home
                            }
                        }
                    }
            case .home:
                HomeScreen(currentScreen: $currentScreen)
            case .mailbox:
                MailboxScreen(currentScreen: $currentScreen)
            case .cloudNetwork:
                CloudNetworkScreen(currentScreen: $currentScreen)
            case .wallet:
                WalletScreen(currentScreen: $currentScreen)
            }
        }
    }
}

// MARK: - Splash Screen
struct SplashScreen: View {
    @State private var animateElements = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Decorative branch element
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                    .scaleEffect(animateElements ? 1.0 : 0.5)
                    .opacity(animateElements ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 1.5).delay(0.5), value: animateElements)
                
                Text("Welcome Back")
                    .font(.system(size: 32, weight: .light, design: .serif))
                    .foregroundColor(.white)
                    .opacity(animateElements ? 1.0 : 0.0)
                    .offset(y: animateElements ? 0 : 20)
                    .animation(.easeInOut(duration: 1.0).delay(1.0), value: animateElements)
            }
        }
        .onAppear {
            animateElements = true
        }
    }
}

// MARK: - Home Screen
struct HomeScreen: View {
    @Binding var currentScreen: ContentView.AppScreen
    @State private var selectedDate = Date()
    @State private var showingCloud = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Status Bar
            HStack {
                Text("2:34")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "signal.2")
                        .foregroundColor(.white)
                    Image(systemName: "wifi")
                        .foregroundColor(.white)
                    Image(systemName: "battery.100")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer()
            
            // Main Content Area
            VStack(spacing: 20) {
                // Cloud Visual Area
                ZStack {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.3),
                                Color.cyan.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 200)
                    
                    if showingCloud {
                        VStack {
                            // Cloud representation
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("September")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.white)
                            
                            Text("16")
                                .font(.system(size: 48, weight: .thin))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Calendar View
                CalendarView(selectedDate: $selectedDate)
                    .padding(.horizontal, 20)
                
                // Bottom Action Buttons
                HStack(spacing: 30) {
                    // Mail Button
                    Button(action: {
                        currentScreen = .mailbox
                    }) {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // Cloud Network Button
                    Button(action: {
                        currentScreen = .cloudNetwork
                    }) {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "icloud.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // Wallet Button
                    Button(action: {
                        currentScreen = .wallet
                    }) {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "creditcard.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .padding(.bottom, 30)
            }
            
            Spacer()
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.green.opacity(0.8),
                    Color.black.opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Calendar View
struct CalendarView: View {
    @Binding var selectedDate: Date
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    private let weekdays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    
    var body: some View {
        VStack(spacing: 15) {
            // Weekday headers
            HStack {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            HStack {
                ForEach(12...18, id: \.self) { day in
                    Button(action: {
                        // Handle date selection
                    }) {
                        Text("\(day)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(day == 16 ? .black : .white)
                            .frame(width: 35, height: 35)
                            .background(
                                day == 16 ? Color.white : Color.clear
                            )
                            .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.6))
        )
    }
}

// MARK: - Mailbox Screen
struct MailboxScreen: View {
    @Binding var currentScreen: ContentView.AppScreen
    @State private var showingComposeSheet = false
    @State private var lastMessageDate: Date?
    @State private var showingRateLimitAlert = false
    
    private let mailData = [
        MailItem(sender: "Centuries Mutual", subject: "Request", date: "Mon", isNew: true),
        MailItem(sender: "Centuries Mutual", subject: "Request", date: "Aug 3", isNew: true),
        MailItem(sender: "Broker", subject: "Update", date: "July 21", isNew: false)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("2:34")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "signal.2")
                        .foregroundColor(.white)
                    Image(systemName: "wifi")
                        .foregroundColor(.white)
                    Image(systemName: "battery.100")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Navigation Bar
            HStack {
                Button(action: {
                    currentScreen = .home
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                }
                
                Text("Inbox")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.leading, 10)
                
                Spacer()
                
                Button(action: {
                    checkAndShowCompose()
                }) {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Mail List
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(mailData) { mail in
                        MailRowView(mail: mail)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            
            Spacer()
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.green.opacity(0.8),
                    Color.black.opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .sheet(isPresented: $showingComposeSheet) {
            ComposeMailView()
        }
        .alert("Rate Limit", isPresented: $showingRateLimitAlert) {
            Button("OK") { }
        } message: {
            Text("You can only send one message per day. Please try again tomorrow.")
        }
    }
    
    private func checkAndShowCompose() {
        let calendar = Calendar.current
        let today = Date()
        
        if let lastDate = lastMessageDate,
           calendar.isDate(lastDate, inSameDayAs: today) {
            showingRateLimitAlert = true
        } else {
            showingComposeSheet = true
        }
    }
}

// MARK: - Mail Item Model
struct MailItem: Identifiable {
    let id = UUID()
    let sender: String
    let subject: String
    let date: String
    let isNew: Bool
}

// MARK: - Mail Row View
struct MailRowView: View {
    let mail: MailItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mail.sender)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    Text(mail.subject)
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.7))
                }
                
                Spacer()
                
                Text(mail.date)
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.9))
        )
    }
}

// MARK: - Compose Mail View
struct ComposeMailView: View {
    @Environment(\.dismiss) var dismiss
    @State private var messageText = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("To: admin@yourcompany.com")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Text("Subject: User Message")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                TextEditor(text: $messageText)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .frame(minHeight: 200)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: sendMessage) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Sending..." : "Send Message")
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isLoading = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Here you would implement actual email sending logic
            // For example, using a service like EmailJS or a backend API
            
            isLoading = false
            dismiss()
        }
    }
}

// MARK: - Cloud Network Screen
struct CloudNetworkScreen: View {
    @Binding var currentScreen: ContentView.AppScreen
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    currentScreen = .home
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                }
                
                Text("Cloud Network")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.leading, 10)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            
            Spacer()
            
            Image(systemName: "icloud.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            Text("Cloud Network")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            Text("Coming Soon")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 10)
            
            Spacer()
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.green.opacity(0.8),
                    Color.black.opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Wallet Screen
struct WalletScreen: View {
    @Binding var currentScreen: ContentView.AppScreen
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    currentScreen = .home
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                }
                
                Text("Wallet")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.leading, 10)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            
            Spacer()
            
            Image(systemName: "creditcard.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            Text("Digital Wallet")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            Text("Coming Soon")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 10)
            
            Spacer()
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.green.opacity(0.8),
                    Color.black.opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}