import SwiftUI

struct Transaction: Identifiable {
    let id = UUID()
    let description: String
    let amount: String
    let date: String
}

struct WalletView: View {
    @State private var balance: Double = 58.28
    @State private var showHistory: Bool = false
    @State private var showWithdraw: Bool = false
    
    var body: some View {
        VStack {
            Text("Wallet")
                .font(.title)
            
            Text("Balance: $\(balance, specifier: "%.2f")")
                .font(.largeTitle)
            
            // Coverage card (always visible)
            Text("Status: Health Insurance Coverage Status")
                .padding()
                .background(Color.green.opacity(0.2))
                .cornerRadius(10)
            
            Button("Withdraw") {
                showWithdraw = true
            }
            .buttonStyle(.bordered)
            
            Button("Transaction History") {
                showHistory = true
            }
            .buttonStyle(.bordered)
            
            Text("Tax: Coming Soon")
                .foregroundColor(.gray)
            
            Spacer()
        }
        .navigationTitle("Wallet")
        .navigationDestination(isPresented: $showHistory) {
            TransactionHistoryView()
        }
        .navigationDestination(isPresented: $showWithdraw) {
            WithdrawView(balance: $balance)
        }
        .gesture(DragGesture(minimumDistance: 50, coordinateSpace: .global)
            .onEnded { value in
                if value.translation.width > 0 {
                    // Long left-to-right swipe to go home
                    // Already in tab view, so no action needed
                }
            })
    }
}

struct TransactionHistoryView: View {
    let transactions: [Transaction] = [
        Transaction(description: "My Brothers Keeper", amount: "+ $2.33", date: "05/01/2025"),
        Transaction(description: "Conservatory Gift", amount: "+ $8.21", date: "06/01/2025"),
        Transaction(description: "Credit 400", amount: "+ Credit", date: "05/12/2025")
    ]
    
    var body: some View {
        List(transactions) { transaction in
            HStack {
                Text(transaction.description)
                Spacer()
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
    
    var body: some View {
        VStack {
            Text("Confirm Amount")
                .font(.title)
            
            TextField("Amount", text: $amount)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Withdraw") {
                if let withdrawAmount = Double(amount), withdrawAmount <= balance {
                    isProcessing = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isProcessing = false
                        balance -= withdrawAmount
                        isSuccess = true
                    }
                }
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
            
            Spacer()
        }
        .navigationTitle("Withdraw")
    }
}

#Preview {
    NavigationStack {
        WalletView()
    }
}