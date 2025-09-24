import SwiftUI
import Stripe

struct Transaction: Identifiable, Codable {
    let id: UUID
    let description: String
    let amount: Double
    let date: String
    let category: TransactionCategory
    let status: TransactionStatus
}

enum TransactionCategory: String, Codable, CaseIterable {
    case evergreen = "Evergreen"
    case steps = "Steps"
    case adRevenue = "Ad Revenue"
    
    var icon: String {
        switch self {
        case .evergreen: return "leaf.fill"
        case .steps: return "figure.walk"
        case .adRevenue: return "dollarsign.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .evergreen: return .green
        case .steps: return .blue
        case .adRevenue: return .orange
        }
    }
}

enum TransactionStatus: String, Codable {
    case pending = "Pending"
    case completed = "Completed"
    case failed = "Failed"
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct WalletBalances: Codable {
    let evergreen: Double
    let steps: Double
    let adRevenue: Double
}

struct FinancialHealthScore: Codable {
    let score: Int // 0-100
    let level: String
    let nextGoal: String
}

struct WalletView: View {
    @State private var balances = WalletBalances(evergreen: 0.0, steps: 0.0, adRevenue: 0.0)
    @State private var transactions: [Transaction] = []
    @State private var healthScore = FinancialHealthScore(score: 0, level: "Getting Started", nextGoal: "Reach $100 total balance")
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Navigation states
    @State private var showCashOut = false
    @State private var showTransfer = false
    @State private var showRedeem = false
    @State private var showAllTransactions = false
    
    var totalBalance: Double {
        balances.evergreen + balances.steps + balances.adRevenue
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Loading Wallet...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(50)
                } else if let error = errorMessage {
                    ErrorView(message: error) {
                        fetchWalletData()
                    }
                } else {
                    // Main Evergreen Balance Card
                    EvergreenBalanceCard(balance: balances.evergreen)
                    
                    // Secondary Balance Cards
                    HStack(spacing: 16) {
                        SecondaryBalanceCard(
                            title: "Steps Balance",
                            balance: balances.steps,
                            icon: "figure.walk",
                            color: .blue,
                            subtitle: "From MyBrother'sKeeper"
                        )
                        
                        SecondaryBalanceCard(
                            title: "Ad Revenue",
                            balance: balances.adRevenue,
                            icon: "dollarsign.circle.fill",
                            color: .orange,
                            subtitle: "Saint Daniels & Conservatory"
                        )
                    }
                    
                    // Quick Actions
                    QuickActionsRow(
                        onCashOut: { showCashOut = true },
                        onTransfer: { showTransfer = true },
                        onRedeem: { showRedeem = true }
                    )
                    
                    // Financial Health Score
                    FinancialHealthCard(healthScore: healthScore)
                    
                    // Recent Transactions
                    RecentTransactionsCard(
                        transactions: Array(transactions.prefix(5)),
                        onViewAll: { showAllTransactions = true }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            fetchWalletData()
        }
        .navigationDestination(isPresented: $showCashOut) {
            CashOutView(totalBalance: totalBalance)
        }
        .navigationDestination(isPresented: $showTransfer) {
            TransferView(balances: balances)
        }
        .navigationDestination(isPresented: $showRedeem) {
            RedeemView(evergreenBalance: balances.evergreen)
        }
        .navigationDestination(isPresented: $showAllTransactions) {
            AllTransactionsView(transactions: transactions)
        }
        .onAppear {
            fetchWalletData()
        }
    }
    
    private func fetchWalletData() {
        isLoading = true
        errorMessage = nil
        
        let group = DispatchGroup()
        var fetchError: String?
        
        // Fetch balances
        group.enter()
        fetchBalances { result in
            switch result {
            case .success(let fetchedBalances):
                balances = fetchedBalances
            case .failure(let error):
                fetchError = error.localizedDescription
            }
            group.leave()
        }
        
        // Fetch transactions
        group.enter()
        fetchTransactions { result in
            switch result {
            case .success(let fetchedTransactions):
                transactions = fetchedTransactions
            case .failure(let error):
                fetchError = error.localizedDescription
            }
            group.leave()
        }
        
        // Fetch health score
        group.enter()
        fetchHealthScore { result in
            switch result {
            case .success(let score):
                healthScore = score
            case .failure(let error):
                fetchError = error.localizedDescription
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            isLoading = false
            errorMessage = fetchError
        }
    }
    
    private func fetchBalances(completion: @escaping (Result<WalletBalances, Error>) -> Void) {
        guard let url = URL(string: "https://your-self-hosted-server/wallet/balances?userId=123") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = data, let balances = try? JSONDecoder().decode(WalletBalances.self, from: data) {
                completion(.success(balances))
            } else {
                completion(.failure(URLError(.badServerResponse)))
            }
        }.resume()
    }
    
    private func fetchTransactions(completion: @escaping (Result<[Transaction], Error>) -> Void) {
        guard let url = URL(string: "https://your-self-hosted-server/wallet/transactions?userId=123") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = data, let transactions = try? JSONDecoder().decode([Transaction].self, from: data) {
                completion(.success(transactions))
            } else {
                completion(.failure(URLError(.badServerResponse)))
            }
        }.resume()
    }
    
    private func fetchHealthScore(completion: @escaping (Result<FinancialHealthScore, Error>) -> Void) {
        guard let url = URL(string: "https://your-self-hosted-server/wallet/health-score?userId=123") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = data, let score = try? JSONDecoder().decode(FinancialHealthScore.self, from: data) {
                completion(.success(score))
            } else {
                completion(.failure(URLError(.badServerResponse)))
            }
        }.resume()
    }
}

struct EvergreenBalanceCard: View {
    let balance: Double
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Evergreen Balance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("$\(balance, specifier: "%.2f")")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
                Image(systemName: "leaf.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
                    .background(
                        Circle()
                            .fill(.green.opacity(0.1))
                            .frame(width: 60, height: 60)
                    )
            }
            
            HStack {
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.green)
                Text("Growing your impact")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct SecondaryBalanceCard: View {
    let title: String
    let balance: Double
    let icon: String
    let color: Color
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text("$\(balance, specifier: "%.2f")")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
}

struct QuickActionsRow: View {
    let onCashOut: () -> Void
    let onTransfer: () -> Void
    let onRedeem: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            QuickActionButton(
                title: "Cash Out",
                icon: "banknote",
                color: .blue,
                action: onCashOut
            )
            
            QuickActionButton(
                title: "Transfer",
                icon: "arrow.left.arrow.right",
                color: .purple,
                action: onTransfer
            )
            
            QuickActionButton(
                title: "Redeem",
                icon: "gift",
                color: .green,
                action: onRedeem
            )
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FinancialHealthCard: View {
    let healthScore: FinancialHealthScore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Financial Health")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(healthScore.score)/100")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            ProgressView(value: Double(healthScore.score), total: 100)
                .tint(.green)
                .scaleEffect(y: 2)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level: \(healthScore.level)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Next Goal: \(healthScore.nextGoal)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct RecentTransactionsCard: View {
    let transactions: [Transaction]
    let onViewAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("View All", action: onViewAll)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            if transactions.isEmpty {
                Text("No transactions yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(transactions) { transaction in
                        TransactionRow(transaction: transaction)
                        if transaction.id != transactions.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.category.icon)
                .font(.title3)
                .foregroundColor(transaction.category.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(transaction.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("+$\(transaction.amount, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text(transaction.status.rawValue)
                    .font(.caption2)
                    .foregroundColor(transaction.status.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(transaction.status.color.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

// Placeholder views for navigation destinations
struct CashOutView: View {
    let totalBalance: Double
    
    var body: some View {
        Text("Cash Out: $\(totalBalance, specifier: "%.2f")")
            .navigationTitle("Cash Out")
    }
}

struct TransferView: View {
    let balances: WalletBalances
    
    var body: some View {
        Text("Transfer Between Balances")
            .navigationTitle("Transfer")
    }
}

struct RedeemView: View {
    let evergreenBalance: Double
    
    var body: some View {
        Text("Redeem Evergreen: $\(evergreenBalance, specifier: "%.2f")")
            .navigationTitle("Redeem")
    }
}

struct AllTransactionsView: View {
    let transactions: [Transaction]
    
    var body: some View {
        List(transactions) { transaction in
            TransactionRow(transaction: transaction)
        }
        .navigationTitle("All Transactions")
    }
}

#Preview {
    NavigationStack {
        WalletView()
    }
}