import SwiftUI

struct SplashView: View {
    @State private var isActive: Bool = false
    
    var body: some View {
        VStack {
            if isActive {
                LoginView()
            } else {
                Text("Centuries Mutual")
                    .font(.largeTitle)
                    .bold()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                isActive = true
                            }
                        }
                    }
            }
        }
    }
}

// LoginView.swift
struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoggedIn: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Centuries Mutual")
                .font(.largeTitle)
                .bold()
            
            TextField("Email:", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            SecureField("Password:", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Forgot Password") {
                // Handle forgot password
            }
            .foregroundColor(.blue)
            
            Button("Create An Account") {
                // Handle account creation
            }
            .foregroundColor(.blue)
            
            Button("Login") {
                isLoggedIn = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationDestination(isPresented: $isLoggedIn) {
            MainTabView()
        }
    }
}

#Preview {
    SplashView()
}