import SwiftUI
import Stripe

struct Transaction: Identifiable {
    let id: UUID
    let description: String
    let amount: String
    let date: String
    let appName: String  // To track earnings from different apps
}

struct Promotion: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let offerCode: String  // For custom offers
}

struct WalletView: View {
    @State private var balance: Double = 0.0
    @State private var transactions: [Transaction] = []
    @State private var promotions: [Promotion] = []
    @State private var showHistory: Bool = false
    @State private var showTax: Bool = false
    @State private var showAccount: Bool = false
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading Wallet...")
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else {
                // Available Balance (tappable for history)
                Text("Balance: $\(balance, specifier: "%.2f")")
                    .font(.largeTitle)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .onTapGesture {
                        showHistory = true
                    }
                    .navigationDestination(isPresented: $showHistory) {
                        TransactionHistoryView(transactions: $transactions)
                    }
                
                // Tax Button
                Button("Tax") {
                    showTax = true
                }
                .buttonStyle(.bordered)
                .navigationDestination(isPresented: $showTax) {
                    Text("Tax Filing: Coming Soon")
                        .navigationTitle("Tax")
                }
                
                // Account Button
                Button("Account") {
                    showAccount = true
                }
                .buttonStyle(.bordered)
                .navigationDestination(isPresented: $showAccount) {
                    AccountView()
                }
                
                // Custom Offers/Promotions
                if !promotions.isEmpty {
                    Section(header: Text("Promotions").font(.headline)) {
                        List(promotions) { promotion in
                            VStack(alignment: .leading) {
                                Text(promotion.title)
                                    .font(.subheadline)
                                Text(promotion.description)
                                    .font(.caption)
                                Text("Offer Code: \(promotion.offerCode)")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
        .navigationTitle("Wallet")
        .gesture(DragGesture(minimumDistance: 50, coordinateSpace: .global)
            .onEnded { value in
                if value.translation.width > 0 {
                    // Long left-to-right swipe to go home
                }
            })
        .onAppear {
            fetchWalletData()
        }
    }
    
    private func fetchWalletData() {
        isLoading = true
        errorMessage = nil
        
        // Fetch balance from backend API (which uses Stripe)
        guard let balanceURL = URL(string: "https://your-self-hosted-server/wallet/balance?userId=123") else { return }
        URLSession.shared.dataTask(with: balanceURL) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    return
                }
                if let data = data, let decoded = try? JSONDecoder().decode([String: Double].self, from: data), let bal = decoded["balance"] {
                    balance = bal
                }
            }
        }.resume()
        
        // Fetch transactions from backend API (aggregated across apps)
        guard let transactionsURL = URL(string: "https://your-self-hosted-server/wallet/transactions?userId=123") else { return }
        URLSession.shared.dataTask(with: transactionsURL) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    return
                }
                if let data = data, let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
                    transactions = decoded
                }
            }
        }.resume()
        
        // Fetch promotions/custom offers from backend API (admin-managed)
        guard let promotionsURL = URL(string: "https://your-self-hosted-server/wallet/promotions?userId=123") else { return }
        URLSession.shared.dataTask(with: promotionsURL) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                if let data = data, let decoded = try? JSONDecoder().decode([Promotion].self, from: data) {
                    promotions = decoded
                }
            }
        }.resume()
    }
}

struct TransactionHistoryView: View {
    @Binding var transactions: [Transaction]
    
    var body: some View {
        List(transactions) { transaction in
            VStack(alignment: .leading) {
                Text(transaction.description)
                Text("App: \(transaction.appName)")
                Text(transaction.amount)
                Text(transaction.date)
            }
        }
        .navigationTitle("Transaction History")
    }
}

struct WithdrawView: View {
    @Binding var balance: Double
    @State private var amount: String = ""
    @State private var isProcessing: Bool = false
    @State private var isSuccess: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack {
            Text("Confirm Amount")
                .font(.title)
            
            TextField("Amount", text: $amount)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Withdraw") {
                withdraw()
            }
            .buttonStyle(.borderedProminent)
            
            if isProcessing {
                Text("Processing")
                    .padding()
            }
            
            if isSuccess {
                Text("Success!")
                    .padding()
            }
            
            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .navigationTitle("Withdraw")
    }
    
    private func withdraw() {
        if let withdrawAmount = Double(amount), withdrawAmount <= balance {
            isProcessing = true
            guard let url = URL(string: "https://your-self-hosted-server/wallet/withdraw?userId=123") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["amount": withdrawAmount]
            request.httpBody = try? JSONEncoder().encode(body)
            URLSession.shared.dataTask(with: request) { data, _, error in
                DispatchQueue.main.async {
                    isProcessing = false
                    if let error = error {
                        errorMessage = error.localizedDescription
                        return
                    }
                    if let data = data, let decoded = try? JSONDecoder().decode([String: Bool].self, from: data), decoded["success"] == true {
                        balance -= withdrawAmount
                        isSuccess = true
                    } else {
                        errorMessage = "Withdrawal failed"
                    }
                }
            }.resume()
        } else {
            errorMessage = "Invalid amount"
        }
    }
}

struct AccountView: View {
    var body: some View {
        VStack {
            Button("Logout") {
                // Handle logout
            }
            
            Button("Contact Broker") {
                // Handle contact
            }
            
            Text("Status: Not Enrolled")
            
            Button("Start Enrollment") {
                // Handle enrollment
            }
            
            Spacer()
        }
        .navigationTitle("Account")
    }
}

#Preview {
    NavigationStack {
        WalletView()
    }
}