import SwiftUI
import Combine

// MARK: - Main Wallet View
struct WalletView: View {
    @StateObject private var earningsManager: UserEarningsManager
    @StateObject private var externalWalletManager: ExternalWalletManager
    @StateObject private var riskManager = RiskManagementService()
    @State private var showingWithdrawSheet = false
    @State private var showingConnectWalletSheet = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    init(userId: String) {
        let circleAPI = CircleAPIService()
        self._earningsManager = StateObject(wrappedValue: UserEarningsManager(circleAPI: circleAPI, userId: userId))
        self._externalWalletManager = StateObject(wrappedValue: ExternalWalletManager(circleAPI: circleAPI))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Balance Card
                    WalletBalanceCard(earnings: earningsManager.userEarnings)
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button(action: { showingWithdrawSheet = true }) {
                            ActionButtonView(
                                title: "Withdraw",
                                icon: "arrow.up.circle.fill",
                                color: .blue
                            )
                        }
                        .disabled(earningsManager.userEarnings?.availableBalance ?? 0 < 10)
                        
                        Button(action: { showingConnectWalletSheet = true }) {
                            ActionButtonView(
                                title: "Connect Wallet",
                                icon: "link.circle.fill",
                                color: .green
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Connected Wallets Section
                    if !externalWalletManager.connectedWallets.isEmpty {
                        ConnectedWalletsSection(
                            wallets: externalWalletManager.connectedWallets,
                            onDisconnect: { walletId in
                                externalWalletManager.disconnectWallet(walletId: walletId)
                            }
                        )
                    }
                    
                    // Earnings History
                    EarningsHistorySection(
                        earnings: earningsManager.userEarnings?.earningsHistory ?? []
                    )
                }
                .padding()
            }
            .navigationTitle("My Wallet")
            .refreshable {
                earningsManager.loadUserEarnings()
            }
            .sheet(isPresented: $showingWithdrawSheet) {
                WithdrawSheet(
                    earningsManager: earningsManager,
                    riskManager: riskManager,
                    onComplete: { success, message in
                        alertMessage = message
                        showingAlert = true
                    }
                )
            }
            .sheet(isPresented: $showingConnectWalletSheet) {
                ConnectWalletSheet(
                    externalWalletManager: externalWalletManager,
                    onComplete: { success, message in
                        alertMessage = message
                        showingAlert = true
                    }
                )
            }
            .alert("Wallet Update", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

// MARK: - Wallet Balance Card
struct WalletBalanceCard: View {
    let earnings: UserEarnings?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available Balance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("$\(earnings?.availableBalance ?? 0, specifier: "%.2f")")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Pending")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("$\(earnings?.pendingBalance ?? 0, specifier: "%.2f")")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Earned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(earnings?.totalEarned ?? 0, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last Updated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(earnings?.lastUpdated.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Action Button View
struct ActionButtonView: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .cornerRadius(25)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Connected Wallets Section
struct ConnectedWalletsSection: View {
    let wallets: [ConnectedWallet]
    let onDisconnect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Wallets")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(wallets) { wallet in
                ConnectedWalletRow(
                    wallet: wallet,
                    onDisconnect: { onDisconnect(wallet.id) }
                )
            }
        }
    }
}

struct ConnectedWalletRow: View {
    let wallet: ConnectedWallet
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: walletIcon)
                .foregroundColor(walletColor)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(walletColor.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(wallet.name)
                    .font(.headline)
                
                Text("\(wallet.balance) \(wallet.currency)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(wallet.address.prefix(10) + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Disconnect") {
                onDisconnect()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
    
    private var walletIcon: String {
        switch wallet.type {
        case .coinbase: return "bitcoinsign.circle.fill"
        case .robinhood: return "chart.line.uptrend.xyaxis.circle.fill"
        case .circle: return "circle.fill"
        }
    }
    
    private var walletColor: Color {
        switch wallet.type {
        case .coinbase: return .blue
        case .robinhood: return .green
        case .circle: return .purple
        }
    }
}

// MARK: - Earnings History Section
struct EarningsHistorySection: View {
    let earnings: [EarningTransaction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Earnings")
                .font(.headline)
                .padding(.horizontal)
            
            if earnings.isEmpty {
                EmptyEarningsView()
            } else {
                ForEach(earnings.prefix(10)) { transaction in
                    EarningTransactionRow(transaction: transaction)
                }
            }
        }
    }
}

struct EarningTransactionRow: View {
    let transaction: EarningTransaction
    
    var body: some View {
        HStack {
            Image(systemName: transactionIcon)
                .foregroundColor(transactionColor)
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(transactionColor.opacity(0.1))
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(transaction.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(transaction.amount, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text(transaction.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
        }
        .padding(.horizontal)
    }
    
    private var transactionIcon: String {
        switch transaction.type {
        case .survey: return "doc.text.fill"
        case .workout: return "figure.run"
        case .referral: return "person.2.fill"
        case .engagement: return "heart.fill"
        case .bonus: return "star.fill"
        }
    }
    
    private var transactionColor: Color {
        switch transaction.type {
        case .survey: return .blue
        case .workout: return .orange
        case .referral: return .green
        case .engagement: return .pink
        case .bonus: return .purple
        }
    }
    
    private var statusColor: Color {
        switch transaction.status {
        case .pending: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}

struct EmptyEarningsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No earnings yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Complete surveys and workouts to start earning!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Withdraw Sheet
struct WithdrawSheet: View {
    @ObservedObject var earningsManager: UserEarningsManager
    @ObservedObject var riskManager: RiskManagementService
    @State private var withdrawAmount: String = ""
    @State private var selectedWallet: ConnectedWallet?
    @State private var isProcessing = false
    @Environment(\.presentationMode) var presentationMode
    
    let onComplete: (Bool, String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Available Balance
                VStack(spacing: 8) {
                    Text("Available Balance")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("$\(earningsManager.userEarnings?.availableBalance ?? 0, specifier: "%.2f")")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top)
                
                // Withdrawal Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Withdrawal Amount")
                        .font(.headline)
                    
                    HStack {
                        Text("$")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        TextField("0.00", text: $withdrawAmount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Quick Amount Buttons
                    HStack {
                        ForEach([25.0, 50.0, 100.0], id: \.self) { amount in
                            Button("$\(Int(amount))") {
                                withdrawAmount = String(format: "%.2f", amount)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(20)
                        }
                        Spacer()
                    }
                }
                
                // Risk Validation Display
                if let amount = Double(withdrawAmount), amount > 0 {
                    let validation = riskManager.validateTransaction(amount: amount, type: .withdrawal)
                    
                    if !validation.isValid {
                        ValidationIssuesView(issues: validation.issues)
                    }
                    
                    if validation.requiresApproval {
                        ApprovalRequiredView()
                    }
                }
                
                Spacer()
                
                // Withdraw Button
                Button(action: processWithdrawal) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isProcessing ? "Processing..." : "Withdraw Funds")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canWithdraw ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canWithdraw || isProcessing)
            }
            .padding()
            .navigationTitle("Withdraw Funds")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private var canWithdraw: Bool {
        guard let amount = Double(withdrawAmount),
              amount >= 10.0,
              amount <= (earningsManager.userEarnings?.availableBalance ?? 0) else {
            return false
        }
        
        let validation = riskManager.validateTransaction(amount: amount, type: .withdrawal)
        return validation.isValid
    }
    
    private func processWithdrawal() {
        guard let amount = Double(withdrawAmount) else { return }
        
        isProcessing = true
        
        // Simulate processing time
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isProcessing = false
            
            // Record the transaction for risk management
            self.riskManager.recordTransaction(amount: amount, type: .withdrawal)
            
            // In a real implementation, this would trigger the actual withdrawal
            self.onComplete(true, "Withdrawal of $\(amount, specifier: "%.2f") initiated successfully")
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Validation Issues View
struct ValidationIssuesView: View {
    let issues: [ValidationIssue]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Transaction Issues")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            ForEach(issues.indices, id: \.self) { index in
                Text(issueDescription(issues[index]))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func issueDescription(_ issue: ValidationIssue) -> String {
        switch issue {
        case .exceedsMaxSingleTransaction(let max):
            return "Exceeds maximum single transaction limit of $\(max, specifier: "%.2f")"
        case .exceedsDailyLimit(let current, let max):
            return "Would exceed daily limit. Current: $\(current, specifier: "%.2f"), Max: $\(max, specifier: "%.2f")"
        case .exceedsMonthlyLimit(let current, let max):
            return "Would exceed monthly limit. Current: $\(current, specifier: "%.2f"), Max: $\(max, specifier: "%.2f")"
        case .belowMinimumAmount(let min):
            return "Below minimum withdrawal amount of $\(min, specifier: "%.2f")"
        case .suspiciousEarningsAmount:
            return "Suspicious earnings amount detected"
        case .insufficientFunds:
            return "Insufficient funds available"
        case .invalidWallet:
            return "Invalid wallet selected"
        }
    }
}

struct ApprovalRequiredView: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.blue)
            Text("This transaction requires admin approval")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Connect Wallet Sheet
struct ConnectWalletSheet: View {
    @ObservedObject var externalWalletManager: ExternalWalletManager
    @State private var selectedWalletType: WalletType?
    @State private var authCode = ""
    @State private var isConnecting = false
    @Environment(\.presentationMode) var presentationMode
    
    let onComplete: (Bool, String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Connect External Wallet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Link your Coinbase or Robinhood wallet to withdraw funds directly")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Wallet Type Selection
                VStack(spacing: 12) {
                    WalletTypeButton(
                        type: .coinbase,
                        name: "Coinbase",
                        icon: "bitcoinsign.circle.fill",
                        color: .blue,
                        isSelected: selectedWalletType == .coinbase
                    ) {
                        selectedWalletType = .coinbase
                    }
                    
                    WalletTypeButton(
                        type: .robinhood,
                        name: "Robinhood",
                        icon: "chart.line.uptrend.xyaxis.circle.fill",
                        color: .green,
                        isSelected: selectedWalletType == .robinhood
                    ) {
                        selectedWalletType = .robinhood
                    }
                }
                
                if selectedWalletType != nil {
                    // Auth Code Input (simulated)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Authorization Code")
                            .font(.headline)
                        
                        TextField("Enter authorization code", text: $authCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("You'll get this code after authorizing Centuries Mutual in your \(selectedWalletType?.rawValue.capitalized ?? "") app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Connect Button
                if selectedWalletType != nil {
                    Button(action: connectWallet) {
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isConnecting ? "Connecting..." : "Connect Wallet")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canConnect ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canConnect || isConnecting)
                }
            }
            .padding()
            .navigationTitle("Connect Wallet")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private var canConnect: Bool {
        selectedWalletType != nil && !authCode.isEmpty
    }
    
    private func connectWallet() {
        guard let walletType = selectedWalletType else { return }
        
        isConnecting = true
        
        let publisher: AnyPublisher<ConnectedWallet, Error>
        
        switch walletType {
        case .coinbase:
            publisher = externalWalletManager.connectCoinbaseWallet(authCode: authCode)
        case .robinhood:
            publisher = externalWalletManager.connectRobinhoodWallet(authCode: authCode)
        case .circle:
            // Circle wallets are created internally
            return
        }
        
        publisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isConnecting = false
                    if case .failure = completion {
                        self.onComplete(false, "Failed to connect wallet")
                    }
                },
                receiveValue: { wallet in
                    self.onComplete(true, "Successfully connected \(wallet.name)")
                    self.presentationMode.wrappedValue.dismiss()
                }
            )
            .store(in: &externalWalletManager.cancellables)
    }
}

struct WalletTypeButton: View {
    let type: WalletType
    let name: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                    .frame(width: 40)
                
                Text(name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Admin Dashboard View
struct AdminDashboardView: View {
    @StateObject private var adminManager: AdminDashboardManager
    @State private var showingWithdrawSheet = false
    @State private var withdrawAmount = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    init(edwardJonesAccountId: String) {
        let circleAPI = CircleAPIService()
        self._adminManager = StateObject(wrappedValue: AdminDashboardManager(circleAPI: circleAPI, edwardJonesAccountId: edwardJonesAccountId))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Revenue Overview
                    AdminRevenueCard(
                        totalRevenue: adminManager.totalRevenue,
                        totalInterest: adminManager.totalInterestEarned,
                        activeUsers: adminManager.activeUsers
                    )
                    
                    // Quick Actions
                    HStack(spacing: 16) {
                        Button(action: { showingWithdrawSheet = true }) {
                            AdminActionButton(
                                title: "Withdraw to\nEdward Jones",
                                icon: "banknote.fill",
                                color: .green
                            )
                        }
                        
                        Button(action: { adminManager.loadDashboardData() }) {
                            AdminActionButton(
                                title: "Refresh\nData",
                                icon: "arrow.clockwise",
                                color: .blue
                            )
                        }
                    }
                    
                    // Pending Withdrawals
                    if !adminManager.pendingWithdrawals.isEmpty {
                        PendingWithdrawalsSection(
                            withdrawals: adminManager.pendingWithdrawals,
                            onApprove: { id in adminManager.approveWithdrawal(withdrawalId: id) },
                            onReject: { id, reason in adminManager.rejectWithdrawal(withdrawalId: id, reason: reason) }
                        )
                    }
                    
                    // Recent Transactions
                    AdminTransactionsSection(
                        transactions: adminManager.recentTransactions
                    )
                }
                .padding()
            }
            .navigationTitle("Admin Dashboard")
            .refreshable {
                adminManager.loadDashboardData()
            }
        }
        .sheet(isPresented: $showingWithdrawSheet) {
            AdminWithdrawSheet(
                adminManager: adminManager,
                onComplete: { success, message in
                    alertMessage = message
                    showingAlert = true
                }
            )
        }
        .alert("Admin Action", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

struct AdminRevenueCard: View {
    let totalRevenue: Double
    let totalInterest: Double
    let activeUsers: Int
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Revenue Overview")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                VStack {
                    Text("Total Revenue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(totalRevenue, specifier: "%.2f")")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                VStack {
                    Text("Interest Earned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(totalInterest, specifier: "%.2f")")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                VStack {
                    Text("Active Users")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(activeUsers)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

struct AdminActionButton: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(color)
                .cornerRadius(30)
            
            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
        }
    }
}

struct PendingWithdrawalsSection: View {
    let withdrawals: [PendingWithdrawal]
    let onApprove: (String) -> Void
    let onReject: (String, String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pending Withdrawals")
                .font(.headline)
            
            ForEach(withdrawals) { withdrawal in
                PendingWithdrawalRow(
                    withdrawal: withdrawal,
                    onApprove: { onApprove(withdrawal.id) },
                    onReject: { reason in onReject(withdrawal.id, reason) }
                )
            }
        }
    }
}

struct PendingWithdrawalRow: View {
    let withdrawal: PendingWithdrawal
    let onApprove: () -> Void
    let onReject: (String) -> Void
    
    @State private var showingRejectSheet = false
    @State private var rejectionReason = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(withdrawal.userName)
                        .font(.headline)
                    Text("$\(withdrawal.amount, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Text(withdrawal.requestDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if withdrawal.status == .pending {
                HStack {
                    Button("Approve") {
                        onApprove()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(8)
                    
                    Button("Reject") {
                        showingRejectSheet = true
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(8)
                }
            } else {
                Text(withdrawal.status.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingRejectSheet) {
            NavigationView {
                VStack {
                    TextField("Rejection reason", text: $rejectionReason, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Spacer()
                    
                    Button("Reject Withdrawal") {
                        onReject(rejectionReason)
                        showingRejectSheet = false
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                    .padding()
                }
                .navigationTitle("Reject Withdrawal")
                .navigationBarItems(
                    trailing: Button("Cancel") {
                        showingRejectSheet = false
                    }
                )
            }
        }
    }
    
    private var statusColor: Color {
        switch withdrawal.status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        case .completed: return .blue
        }
    }
}

struct AdminTransactionsSection: View {
    let transactions: [AdminTransaction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transactions")
                .font(.headline)
            
            if transactions.isEmpty {
                Text("No recent transactions")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(transactions) { transaction in
                    AdminTransactionRow(transaction: transaction)
                }
            }
        }
    }
}

struct AdminTransactionRow: View {
    let transaction: AdminTransaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.type.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(transaction.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(transaction.amount, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(transaction.status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AdminWithdrawSheet: View {
    @ObservedObject var adminManager: AdminDashboardManager
    @State private var withdrawAmount = ""
    @State private var isProcessing = false
    @Environment(\.presentationMode) var presentationMode
    
    let onComplete: (Bool, String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Withdraw to Edward Jones")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Available Revenue Display
                VStack(spacing: 8) {
                    Text("Available Revenue")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("$\(adminManager.totalRevenue, specifier: "%.2f")")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                // Withdrawal Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Withdrawal Amount")
                        .font(.headline)
                    
                    HStack {
                        Text("$")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        TextField("0.00", text: $withdrawAmount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Quick Amount Buttons
                    HStack {
                        let quarterAmount = adminManager.totalRevenue / 4
                        let halfAmount = adminManager.totalRevenue / 2
                        let fullAmount = adminManager.totalRevenue
                        
                        ForEach([quarterAmount, halfAmount, fullAmount], id: \.self) { amount in
                            if amount > 0 {
                                Button(amount == fullAmount ? "All" : "$\(Int(amount))") {
                                    withdrawAmount = String(format: "%.2f", amount)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(20)
                            }
                        }
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Withdraw Button
                Button(action: processWithdrawal) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isProcessing ? "Processing..." : "Withdraw to Edward Jones")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canWithdraw ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canWithdraw || isProcessing)
            }
            .padding()
            .navigationTitle("Admin Withdrawal")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private var canWithdraw: Bool {
        guard let amount = Double(withdrawAmount),
              amount > 0,
              amount <= adminManager.totalRevenue else {
            return false
        }
        return true
    }
    
    private func processWithdrawal() {
        guard let amount = Double(withdrawAmount) else { return }
        
        isProcessing = true
        
        adminManager.withdrawToEdwardJones(amount: amount)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isProcessing = false
                    if case .failure(let error) = completion {
                        self.onComplete(false, "Withdrawal failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { success in
                    if success {
                        HyperledgerFabricLogger.logAdminAction(
                            action: "withdrawal_to_edward_jones",
                            amount: amount,
                            adminId: "admin_user_id"
                        )
                        self.onComplete(true, "Successfully withdrew $\(amount, specifier: "%.2f") to Edward Jones")
                    } else {
                        self.onComplete(false, "Withdrawal failed")
                    }
                    self.presentationMode.wrappedValue.dismiss()
                }
            )
            .store(in: &adminManager.cancellables)
    }
}

// MARK: - Integration Helper Extensions
private var cancellables = Set<AnyCancellable>()

// Extension to add Circle functionality to existing user models
extension UserEarningsManager {
    func addSurveyEarning(surveyId: String, amount: Double = 5.0) {
        addEarning(
            type: .survey,
            amount: amount,
            description: "Survey Completed: \(surveyId)"
        )
        
        // Log to Hyperledger Fabric for compliance
        if let earnings = userEarnings {
            let transaction = EarningTransaction(
                id: UUID().uuidString,
                type: .survey,
                amount: amount,
                description: "Survey Completed: \(surveyId)",
                timestamp: Date(),
                status: .completed
            )
            HyperledgerFabricLogger.logTransaction(transaction, userId: userId)
        }
    }
    
    func addWorkoutEarning(workoutType: String, duration: TimeInterval) {
        let baseAmount = 2.0
        let bonusAmount = duration > 1800 ? 1.0 : 0.0 // Bonus for 30+ min workouts
        let totalAmount = baseAmount + bonusAmount
        
        addEarning(
            type: .workout,
            amount: totalAmount,
            description: "Workout: \(workoutType) (\(Int(duration/60))min)"
        )
    }
    
    func addReferralEarning(referredUserId: String) {
        addEarning(
            type: .referral,
            amount: 10.0,
            description: "Referred new user: \(referredUserId)"
        )
    }
    
    func addEngagementBonus(activity: String) {
        addEarning(
            type: .engagement,
            amount: 1.0,
            description: "Engagement bonus: \(activity)"
        )
    }
}

// MARK: - Sandbox Testing Helpers
#if DEBUG
struct CircleTestingHelper {
    static func createTestData() {
        // Create sample earnings for testing
        let testUserId = "test_user_123"
        UserDefaults.standard.set(45.50, forKey: "total_earned_\(testUserId)")
        UserDefaults.standard.set(23.75, forKey: "available_balance_\(testUserId)")
        UserDefaults.standard.set(5.00, forKey: "pending_balance_\(testUserId)")
        
        // Create sample earnings history
        let sampleTransactions = [
            EarningTransaction(
                id: "1",
                type: .survey,
                amount: 5.0,
                description: "Health Survey #1",
                timestamp: Date().addingTimeInterval(-86400),
                status: .completed
            ),
            EarningTransaction(
                id: "2",
                type: .workout,
                amount: 3.0,
                description: "30-min Cardio Session",
                timestamp: Date().addingTimeInterval(-43200),
                status: .completed
            ),
            EarningTransaction(
                id: "3",
                type: .referral,
                amount: 10.0,
                description: "Referred John Doe",
                timestamp: Date().addingTimeInterval(-21600),
                status: .completed
            ),
            EarningTransaction(
                id: "4",
                type: .survey,
                amount: 5.0,
                description: "Wellness Check Survey",
                timestamp: Date(),
                status: .pending
            )
        ]
        
        if let data = try? JSONEncoder().encode(sampleTransactions) {
            UserDefaults.standard.set(data, forKey: "earnings_history_\(testUserId)")
        }
        
        // Set admin test data
        UserDefaults.standard.set(2847.32, forKey: "admin_total_revenue")
        UserDefaults.standard.set(127.45, forKey: "admin_total_interest")
        UserDefaults.standard.set(156, forKey: "admin_active_users")
    }
    
    static func simulateCircleAPIResponse<T: Codable>(data: T, delay: TimeInterval = 1.0) -> AnyPublisher<T, Error> {
        return Future<T, Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                promise(.success(data))
            }
        }
        .eraseToAnyPublisher()
    }
    
    static func testWalletCreation() {
        let testWallet = CircleWallet(
            walletId: "test_wallet_123",
            entityId: "test_entity_456",
            type: "end_user_wallet",
            description: "Test Centuries Mutual Wallet",
            balances: [
                WalletBalance(amount: "0.00", currency: "USD")
            ],
            createDate: ISO8601DateFormatter().string(from: Date()),
            updateDate: ISO8601DateFormatter().string(from: Date())
        )
        
        print("Test wallet created: \(testWallet)")
    }
}
#endif

// MARK: - Integration Instructions
/*
 INTEGRATION INSTRUCTIONS FOR EXISTING CENTURIES MUTUAL APP:
 
 1. **Dependencies & Setup:**
    - Add Combine framework import to your existing view controllers
    - Ensure your app has proper keychain entitlements in capabilities
    - Add Circle API key to your app's configuration (use different keys for sandbox/production)
    
 2. **Existing Architecture Integration:**
    - Add CircleAPIService as a singleton or inject it through your existing dependency injection
    - Integrate UserEarningsManager into your existing user management system
    - Connect external wallet functionality to your existing authentication flows
    
 3. **Backend Integration Points:**
    - Replace UserDefaults storage with your existing backend API calls
    - Integrate with your Hyperledger Fabric implementation for transaction logging
    - Connect risk management limits to your existing admin controls
    
 4. **UI Integration:**
    - Add WalletView to your existing tab bar or navigation structure
    - Integrate earning triggers in your survey completion and workout tracking logic
    - Add AdminDashboardView to your existing admin portal
    
 5. **Security Implementation:**
    - Implement proper API key rotation and management
    - Use your existing user authentication for Circle API calls
    - Ensure all sensitive operations require additional authentication
    
 6. **Testing & Sandbox:**
    - Use Circle's sandbox environment for all development and testing
    - Implement the CircleTestingHelper methods for UI testing
    - Test all withdrawal limits and risk management scenarios
    
 7. **Production Deployment:**
    - Switch to Circle's production API endpoints
    - Implement proper error handling and retry logic
    - Set up monitoring for transaction failures and API issues
    - Configure proper logging for compliance and debugging
    
 8. **Compliance & Logging:**
    - Ensure all financial transactions are logged to Hyperledger Fabric
    - Implement proper audit trails for admin actions
    - Set up alerts for suspicious transaction patterns
    - Regular backup of user earnings and transaction data
 */

#Preview {
    WalletView(userId: "preview_user_123")
}
                