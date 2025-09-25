import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
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
                        Spacer()
                        
                        // Logo and Title
                        VStack(spacing: 20) {
                            Image("cmlogotreesmall")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 60)
                                .foregroundColor(.white)
                            
                            Text("Centuries Mutual")
                                .font(.custom("Playfair Display", size: 32))
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Wealth Management: Secure Your Legacy")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Login Form
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                TextField("Enter your email", text: $email)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                SecureField("Enter your password", text: $password)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            Button(action: login) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    Text(isLoading ? "Signing In..." : "Sign In")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0.83, green: 0.69, blue: 0.22))
                                .foregroundColor(Color(red: 0.11, green: 0.30, blue: 0.24))
                                .cornerRadius(12)
                            }
                            .disabled(isLoading || email.isEmpty || password.isEmpty)
                        }
                        .padding(.horizontal, 30)
                        
                        // Stats Cards
                        VStack(spacing: 16) {
                            HStack(spacing: 20) {
                                StatCard(title: "$14.2M", subtitle: "Assets Under Management")
                                StatCard(title: "25+", subtitle: "Years of Excellence")
                            }
                            
                            StatCard(title: "50K+", subtitle: "Satisfied Clients")
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer()
                    }
                }
            }
        }
        .alert("Login Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func login() {
        isLoading = true
        
        // Simulate login process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // For demo purposes, accept any email/password
            if !email.isEmpty && !password.isEmpty {
                UserDefaults.standard.set(true, forKey: "is_logged_in")
                UserDefaults.standard.set(email, forKey: "current_user_id")
                isLoggedIn = true
            } else {
                alertMessage = "Please enter both email and password"
                showAlert = true
            }
            isLoading = false
        }
    }
}

struct StatCard: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22))
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false))
}
