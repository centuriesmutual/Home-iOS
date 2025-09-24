import SwiftUI
import Combine

// MARK: - Message Models
struct MessageData: Codable, Identifiable {
    let id: String
    let threadId: String
    let userId: String
    let senderId: String
    let senderType: String
    let subject: String?
    let message: String
    let attachments: [MessageAttachment]
    let enrollmentId: String?
    let timestamp: Date
    
    init(id: String = UUID().uuidString, threadId: String, userId: String, senderId: String, senderType: String, subject: String?, message: String, attachments: [MessageAttachment] = [], enrollmentId: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.threadId = threadId
        self.userId = userId
        self.senderId = senderId
        self.senderType = senderType
        self.subject = subject
        self.message = message
        self.attachments = attachments
        self.enrollmentId = enrollmentId
        self.timestamp = timestamp
    }
}

struct MessageAttachment: Codable {
    let fileName: String
    let fileSize: UInt64
    let dropboxPath: String
}

struct MessageThread: Identifiable {
    let id: String
    let subject: String
    let lastMessage: String
    let lastMessageTime: Date
    let unreadCount: Int
    let senderType: String
    let enrollmentId: String?
}

// MARK: - Messages View Model
class MessagesViewModel: ObservableObject {
    @Published var threads: [MessageThread] = []
    @Published var currentThread: [MessageData] = []
    @Published var selectedThreadId: String?
    @Published var isLoading = false
    @Published var newMessageText = ""
    @Published var showingCompose = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadMockData()
    }
    
    private func loadMockData() {
        // Mock data - in real app, this would fetch from SQLManager
        threads = [
            MessageThread(
                id: "thread1",
                subject: "Welcome to Centuries Mutual",
                lastMessage: "Thank you for choosing our services. We're here to help with all your financial needs.",
                lastMessageTime: Date().addingTimeInterval(-3600),
                unreadCount: 0,
                senderType: "system",
                enrollmentId: nil
            ),
            MessageThread(
                id: "thread2",
                subject: "Insurance Enrollment Update",
                lastMessage: "Your health insurance application has been received and is being processed.",
                lastMessageTime: Date().addingTimeInterval(-7200),
                unreadCount: 1,
                senderType: "agent",
                enrollmentId: "enrollment123"
            ),
            MessageThread(
                id: "thread3",
                subject: "Tax Preparation Reminder",
                lastMessage: "Don't forget to gather your tax documents for this year's filing.",
                lastMessageTime: Date().addingTimeInterval(-86400),
                unreadCount: 0,
                senderType: "agent",
                enrollmentId: nil
            )
        ]
        
        // Mock messages for selected thread
        currentThread = [
            MessageData(
                threadId: "thread2",
                userId: "user123",
                senderId: "agent456",
                senderType: "agent",
                subject: "Insurance Enrollment Update",
                message: "Hello! I wanted to update you on your health insurance enrollment. We've received all your documents and your application is currently being reviewed by our underwriting team.",
                enrollmentId: "enrollment123",
                timestamp: Date().addingTimeInterval(-7200)
            ),
            MessageData(
                threadId: "thread2",
                userId: "user123",
                senderId: "user123",
                senderType: "user",
                subject: "Insurance Enrollment Update",
                message: "Thank you for the update! How long does the review process typically take?",
                enrollmentId: "enrollment123",
                timestamp: Date().addingTimeInterval(-3600)
            ),
            MessageData(
                threadId: "thread2",
                userId: "user123",
                senderId: "agent456",
                senderType: "agent",
                subject: "Insurance Enrollment Update",
                message: "The review process typically takes 5-7 business days. We'll notify you as soon as we have a decision. In the meantime, feel free to reach out if you have any questions!",
                enrollmentId: "enrollment123",
                timestamp: Date().addingTimeInterval(-1800)
            )
        ]
    }
    
    func selectThread(_ threadId: String) {
        selectedThreadId = threadId
        // In real app, this would load messages from SQLManager
        // For now, we'll use the mock data
    }
    
    func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = MessageData(
            threadId: selectedThreadId ?? "new_thread",
            userId: "user123",
            senderId: "user123",
            senderType: "user",
            subject: nil,
            message: newMessageText,
            enrollmentId: nil
        )
        
        currentThread.append(message)
        newMessageText = ""
        
        // In real app, this would save to SQLManager and sync to Dropbox
    }
    
    func markThreadAsRead(_ threadId: String) {
        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            threads[index] = MessageThread(
                id: threads[index].id,
                subject: threads[index].subject,
                lastMessage: threads[index].lastMessage,
                lastMessageTime: threads[index].lastMessageTime,
                unreadCount: 0,
                senderType: threads[index].senderType,
                enrollmentId: threads[index].enrollmentId
            )
        }
    }
}

// MARK: - Main Messages View
struct MessagesView: View {
    @StateObject private var viewModel = MessagesViewModel()
    @State private var showingCompose = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.selectedThreadId == nil {
                    // Thread List View
                    ThreadListView(viewModel: viewModel)
                } else {
                    // Message Detail View
                    MessageDetailView(viewModel: viewModel)
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCompose = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
                
                if viewModel.selectedThreadId != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Back") {
                            viewModel.selectedThreadId = nil
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCompose) {
                ComposeMessageView()
            }
        }
    }
}

// MARK: - Thread List View
struct ThreadListView: View {
    @ObservedObject var viewModel: MessagesViewModel
    
    var body: some View {
        List(viewModel.threads) { thread in
            ThreadRow(thread: thread) {
                viewModel.selectThread(thread.id)
                viewModel.markThreadAsRead(thread.id)
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct ThreadRow: View {
    let thread: MessageThread
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(thread.senderType == "agent" ? Color(red: 0.08, green: 0.26, blue: 0.16) : Color.blue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(thread.senderType == "agent" ? "A" : "U")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(thread.subject)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if thread.unreadCount > 0 {
                            Text("\(thread.unreadCount)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(thread.lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Text(thread.lastMessageTime, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Message Detail View
struct MessageDetailView: View {
    @ObservedObject var viewModel: MessagesViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.currentThread) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    if let lastMessage = viewModel.currentThread.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message Input
            MessageInputView(viewModel: viewModel)
        }
    }
}

struct MessageBubble: View {
    let message: MessageData
    
    private var isFromUser: Bool {
        message.senderType == "user"
    }
    
    var body: some View {
        HStack {
            if isFromUser {
                Spacer()
            }
            
            VStack(alignment: isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.message)
                    .font(.body)
                    .foregroundColor(isFromUser ? .white : .primary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isFromUser ? Color(red: 0.08, green: 0.26, blue: 0.16) : Color(.systemGray5))
                    )
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isFromUser ? .trailing : .leading)
            
            if !isFromUser {
                Spacer()
            }
        }
    }
}

struct MessageInputView: View {
    @ObservedObject var viewModel: MessagesViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $viewModel.newMessageText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(1...4)
            
            Button(action: viewModel.sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(red: 0.08, green: 0.26, blue: 0.16))
                    .clipShape(Circle())
            }
            .disabled(viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
}

// MARK: - Compose Message View
struct ComposeMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recipient = ""
    @State private var subject = ""
    @State private var message = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("To")
                        .font(.headline)
                    TextField("Enter recipient", text: $recipient)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subject")
                        .font(.headline)
                    TextField("Enter subject", text: $subject)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.headline)
                    TextField("Type your message...", text: $message, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(5...10)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        // Send message logic
                        dismiss()
                    }
                    .disabled(recipient.isEmpty || subject.isEmpty || message.isEmpty)
                }
            }
        }
    }
}

#Preview {
    MessagesView()
}
