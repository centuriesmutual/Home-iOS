import Foundation
import Combine
import UserNotifications

// MARK: - Messaging Manager with Dropbox Integration
class MessagingManager: NSObject, ObservableObject {
    static let shared = MessagingManager()
    
    @Published var conversations: [Conversation] = []
    @Published var unreadCount = 0
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    private let sqlManager = SQLManager.shared
    private let dropboxManager = DropboxManager.shared
    
    // MARK: - Configuration
    struct Config {
        static let maxAttachmentSize: UInt64 = 25 * 1024 * 1024 // 25MB
        static let supportedFileTypes = ["pdf", "doc", "docx", "jpg", "jpeg", "png", "txt"]
        static let messageRetentionDays = 2555 // 7 years for compliance
    }
    
    enum SenderType: String, Codable {
        case user = "user"
        case admin = "admin"
        case system = "system"
    }
    
    enum MessageStatus: String, Codable {
        case sent = "sent"
        case delivered = "delivered"
        case read = "read"
        case failed = "failed"
    }
    
    private override init() {
        super.init()
        setupNotifications()
        loadConversations()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    // MARK: - Message Operations
    func sendMessage(
        to userId: String,
        subject: String?,
        message: String,
        attachments: [MessageAttachment] = [],
        enrollmentId: String? = nil,
        senderType: SenderType = .user
    ) -> AnyPublisher<String, Error> {
        
        isLoading = true
        
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(MessagingError.managerNotAvailable))
                return
            }
            
            // Create thread ID if needed
            let threadId = self.generateThreadId(userId: userId, enrollmentId: enrollmentId)
            
            // Validate attachments
            do {
                try self.validateAttachments(attachments)
            } catch {
                promise(.failure(error))
                return
            }
            
            let messageData = MessageData(
                id: UUID().uuidString,
                threadId: threadId,
                userId: userId,
                senderId: self.getCurrentUserId(),
                senderType: senderType.rawValue,
                subject: subject,
                message: message,
                attachments: attachments,
                enrollmentId: enrollmentId
            )
            
            // Save to SQL and sync to Dropbox
            self.sqlManager.saveMessage(messageData)
                .flatMap { messageId in
                    self.uploadAttachmentsToDropbox(messageId: messageId, attachments: attachments, threadId: threadId)
                }
                .flatMap { _ in
                    self.createMessageNotification(messageData: messageData)
                }
                .sink(
                    receiveCompletion: { [weak self] completion in
                        self?.isLoading = false
                        