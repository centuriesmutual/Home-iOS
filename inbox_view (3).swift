import SwiftUI
import CoreData
import CryptoKit
import SwiftyDropbox
import UniformTypeIdentifiers

// Message Model
struct Message: Identifiable, Codable {
    let id: String
    let sender: String
    let date: String // ISO8601 format
    let title: String
    let content: String // Encrypted
    let type: String // "broker" or "system"
    let attachmentURL: String? // Dropbox link
}

// Core Data Entity
@objc(CDMessage)
class CDMessage: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var sender: String
    @NSManaged var date: String
    @NSManaged var title: String
    @NSManaged var content: Data // Encrypted
    @NSManaged var type: String
    @NSManaged var attachmentURL: String?
}

struct InboxView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDMessage.date, ascending: false)],
        predicate: nil,
        animation: .default)
    private var messages: FetchedResults<CDMessage>
    
    @State private var showDetail: Message? = nil
    @State private var selectedType: String = "All"
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showDropboxLogin: Bool = false
    @State private var isDropboxAuthenticated: Bool = false
    
    var filteredMessages: [Message] {
        let allMessages = messages.map { cdMessage in
            Message(
                id: cdMessage.id,
                sender: cdMessage.sender,
                date: cdMessage.date,
                title: cdMessage.title,
                content: decrypt(data: cdMessage.content) ?? "",
                type: cdMessage.type,
                attachmentURL: cdMessage.attachmentURL
            )
        }
        return selectedType == "All" ? allMessages : allMessages.filter { $0.type == selectedType.lowercased() }
    }
    
    var body: some View {
        VStack {
            if !isDropboxAuthenticated {
                VStack {
                    Text("Please log in with Dropbox to access messages")
                        .font(.title2)
                        .padding()
                    Button("Log In with Dropbox") {
                        showDropboxLogin = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .sheet(isPresented: $showDropboxLogin) {
                    DropboxLoginView { success in
                        isDropboxAuthenticated = success
                        if success {
                            fetchMessages()
                        }
                    }
                }
            } else {
                // Toggle for Broker/System
                Picker("Filter", selection: $selectedType) {
                    Text("All").tag("All")
                    Text("Broker").tag("Broker")
                    Text("System").tag("System")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Coverage card
                Text("Status: Health Insurance Coverage Status")
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(10)
                
                if isLoading {
                    ProgressView("Loading Messages...")
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else if filteredMessages.isEmpty {
                    Text("No Messages")
                        .foregroundColor(.gray)
                } else {
                    List {
                        ForEach(filteredMessages) { message in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(message.sender)
                                    Text(message.title)
                                }
                                Spacer()
                                Text(message.date)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showDetail = message
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Clear") {
                                    clearMessage(message.id)
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Inbox")
        .navigationDestination(item: $showDetail) { message in
            MessageDetailView(message: message)
        }
        .gesture(DragGesture(minimumDistance: 50, coordinateSpace: .global)
            .onEnded { value in
                if value.translation.width > 0 {
                    // Long left-to-right swipe to go home
                }
            })
        .onAppear {
            checkDropboxAuth()
            deleteOldMessages()
        }
    }
    
    private func checkDropboxAuth() {
        isDropboxAuthenticated = DropboxClientsManager.authorizedClient != nil
        if isDropboxAuthenticated {
            fetchMessages()
        }
    }
    
    private func fetchMessages() {
        guard isDropboxAuthenticated else { return }
        isLoading = true
        guard let url = URL(string: "https://your-self-hosted-server/messages/123") else {
            errorMessage = "Invalid server URL"
            isLoading = false
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                if let data = data, let decoded = try? JSONDecoder().decode([Message].self, from: data) {
                    // Clear existing messages
                    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = CDMessage.fetchRequest()
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    try? viewContext.execute(deleteRequest)
                    
                    // Save new messages
                    for message in decoded {
                        let cdMessage = CDMessage(context: viewContext)
                        cdMessage.id = message.id
                        cdMessage.sender = message.sender
                        cdMessage.date = message.date
                        cdMessage.title = message.title
                        cdMessage.content = Data((encrypt(text: message.content) ?? "").utf8)
                        cdMessage.type = message.type
                        cdMessage.attachmentURL = message.attachmentURL
                    }
                    try? viewContext.save()
                    backupToDropbox()
                }
            }
        }.resume()
    }
    
    private func clearMessage(_ messageId: String) {
        guard isDropboxAuthenticated else { return }
        let fetchRequest: NSFetchRequest<CDMessage> = CDMessage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", messageId)
        if let message = try? viewContext.fetch(fetchRequest).first {
            viewContext.delete(message)
            try? viewContext.save()
        }
        // Delete from server
        guard let url = URL(string: "https://your-self-hosted-server/messages/123/\(messageId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Failed to clear message: \(error.localizedDescription)"
                }
            }
        }.resume()
        backupToDropbox()
    }
    
    private func deleteOldMessages() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let fetchRequest: NSFetchRequest<CDMessage> = CDMessage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date < %@", ISO8601DateFormatter().string(from: thirtyDaysAgo))
        if let oldMessages = try? viewContext.fetch(fetchRequest) {
            for message in oldMessages {
                viewContext.delete(message)
            }
            try? viewContext.save()
        }
        // Delete from server
        guard let url = URL(string: "https://your-self-hosted-server/messages/123/delete_old") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["before": ISO8601DateFormatter().string(from: thirtyDaysAgo)]
        request.httpBody = try? JSONEncoder().encode(body)
        URLSession.shared.dataTask(with: request).resume()
        cleanupOldDropboxBackups()
    }
    
    private func sendMessageToServer(_ message: Message) {
        guard isDropboxAuthenticated else { return }
        guard let url = URL(string: "https://your-self-hosted-server/messages/123") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(message)
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Failed to send message: \(error.localizedDescription)"
                }
                return
            }
            // Save locally
            let cdMessage = CDMessage(context: viewContext)
            cdMessage.id = message.id
            cdMessage.sender = message.sender
            cdMessage.date = message.date
            cdMessage.title = message.title
            cdMessage.content = Data(message.content.utf8)
            cdMessage.type = message.type
            cdMessage.attachmentURL = message.attachmentURL
            try? viewContext.save()
            backupToDropbox()
        }.resume()
    }
    
    private func backupToDropbox() {
        guard let client = DropboxClientsManager.authorizedClient else { return }
        guard let dbURL = viewContext.persistentStoreCoordinator?.persistentStores.first?.url else { return }
        
        // Encrypt SQLite file
        guard let encryptedData = encryptFile(url: dbURL) else { return }
        let encryptedURL = FileManager.default.temporaryDirectory.appendingPathComponent("messages_encrypted.sqlite")
        try? encryptedData.write(to: encryptedURL)
        
        // Client backup
        let clientPath = "/users/123/messages_\(ISO8601DateFormatter().string(from: Date())).sqlite"
        client.files.upload(path: clientPath, input: encryptedURL)
            .response { _, error in
                if let error = error {
                    print("Client Dropbox upload error: \(error)")
                }
                try? FileManager.default.removeItem(at: encryptedURL)
            }
        
        // Company backup
        guard let companyClient = DropboxClientsManager.authorizedClientWithAppKey("your-company-app-key") else { return }
        let companyPath = "/company/users/123/messages_\(ISO8601DateFormatter().string(from: Date())).sqlite"
        companyClient.files.upload(path: companyPath, input: encryptedURL)
            .response { _, error in
                if let error = error {
                    print("Company Dropbox upload error: \(error)")
                }
            }
        cleanupOldDropboxBackups()
    }
    
    private func cleanupOldDropboxBackups() {
        guard let client = DropboxClientsManager.authorizedClient else { return }
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let dateStr = ISO8601DateFormatter().string(from: thirtyDaysAgo)
        client.files.listFolder(path: "/users/123").response { response, error in
            if let response = response {
                for entry in response.entries where entry.name.hasSuffix(".sqlite") && entry.name < "messages_\(dateStr).sqlite" {
                    client.files.deleteV2(path: entry.pathLower ?? "")
                }
            }
        }
        guard let companyClient = DropboxClientsManager.authorizedClientWithAppKey("your-company-app-key") else { return }
        companyClient.files.listFolder(path: "/company/users/123").response { response, error in
            if let response = response {
                for entry in response.entries where entry.name.hasSuffix(".sqlite") && entry.name < "messages_\(dateStr).sqlite" {
                    companyClient.files.deleteV2(path: entry.pathLower ?? "")
                }
            }
        }
    }
    
    private func encrypt(text: String) -> String? {
        guard let key = getEncryptionKey() else { return nil }
        let data = text.data(using: .utf8)!
        let sealedBox = try? AES.GCM.seal(data, using: key)
        return sealedBox?.combined.base64EncodedString()
    }
    
    private func decrypt(data: Data) -> String? {
        guard let key = getEncryptionKey(),
              let sealedBox = try? AES.GCM.SealedBox(combined: data),
              let decryptedData = try? AES.GCM.open(sealedBox, using: key) else { return nil }
        return String(data: decryptedData, encoding: .utf8)
    }
    
    private func encryptFile(url: URL) -> Data? {
        guard let key = getEncryptionKey(),
              let data = try? Data(contentsOf: url),
              let sealedBox = try? AES.GCM.seal(data, using: key) else { return nil }
        return sealedBox.combined
    }
    
    private func getEncryptionKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: "com.centuriesmutual.key",
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: "com.centuriesmutual.key",
            kSecValueData as String: key.withUnsafeBytes { Data($0) }
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
        return key
    }
}

struct DropboxLoginView: UIViewControllerRepresentable {
    let onCompletion: (Bool) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        DropboxClientsManager.authorizeFromControllerV2(
            UIApplication.shared,
            controller: controller,
            loadingStatusDelegate: nil,
            openURL: { url in UIApplication.shared.open(url) },
            scopeRequest: .init(scopes: ["files.content.write"], includeGrantedScopes: false)
        ) { result in
            switch result {
            case .success:
                onCompletion(true)
            case .cancel, .error:
                onCompletion(false)
            }
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct MessageDetailView: View {
    let message: Message
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showReply: Bool = false
    @State private var showDocumentPicker: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("From: \(message.sender)")
            Text("Date: \(message.date)")
            Text(message.content)
                .padding()
            
            if let url = message.attachmentURL {
                Link("View Attachment", destination: URL(string: url)!)
                    .padding()
            }
            
            Button("Reply") {
                showReply = true
            }
            .buttonStyle(.bordered)
            
            Button("Send Document") {
                showDocumentPicker = true
            }
            .buttonStyle(.bordered)
            
            Button("Request Renewal") {
                sendRenewalRequest()
            }
            .buttonStyle(.bordered)
            
            Spacer()
        }
        .navigationTitle("Read Mail")
        .navigationDestination(isPresented: $showReply) {
            ReplyView(subject: "RE: \(message.title)")
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { url in
                uploadDocument(url, for: message.id)
            }
        }
    }
    
    private func sendRenewalRequest() {
        let renewalMessage = Message(
            id: UUID().uuidString,
            sender: "123",
            date: ISO8601DateFormatter().string(from: Date()),
            title: "Renewal Request",
            content: encrypt(text: "Request to renew insurance plan") ?? "",
            type: "system",
            attachmentURL: nil
        )
        // Note: This would need to be refactored to access InboxView's method
        // InboxView().sendMessageToServer(renewalMessage)
    }
    
    private func uploadDocument(_ url: URL, for messageId: String) {
        guard let client = DropboxClientsManager.authorizedClient else { return }
        let fileManager = FileManager.default
        let localURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(url.lastPathComponent)
        try? fileManager.copyItem(at: url, to: localURL)
        
        let dropboxPath = "/users/123/documents/\(url.lastPathComponent)"
        client.files.upload(path: dropboxPath, input: localURL)
            .response { _, error in
                if let error = error {
                    print("Dropbox upload error: \(error)")
                    return
                }
                client.files.getTemporaryLink(path: dropboxPath).response { response, error in
                    if let link = response?.link {
                        let fetchRequest: NSFetchRequest<CDMessage> = CDMessage.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "id == %@", messageId)
                        if let message = try? viewContext.fetch(fetchRequest).first {
                            message.attachmentURL = link
                            try? viewContext.save()
                            let updatedMessage = Message(
                                id: message.id,
                                sender: message.sender,
                                date: message.date,
                                title: message.title,
                                content: decrypt(data: message.content) ?? "",
                                type: message.type,
                                attachmentURL: link
                            )
                            // Note: This would need to be refactored to access InboxView's method
                            // InboxView().sendMessageToServer(updatedMessage)
                        }
                    }
                }
            }
    }
    
    private func encrypt(text: String) -> String? {
        guard let key = getEncryptionKey() else { return nil }
        let data = text.data(using: .utf8)!
        let sealedBox = try? AES.GCM.seal(data, using: key)
        return sealedBox?.combined.base64EncodedString()
    }
    
    private func decrypt(data: Data) -> String? {
        guard let key = getEncryptionKey(),
              let sealedBox = try? AES.GCM.SealedBox(combined: data),
              let decryptedData = try? AES.GCM.open(sealedBox, using: key) else { return nil }
        return String(data: decryptedData, encoding: .utf8)
    }
    
    private func getEncryptionKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: "com.centuriesmutual.key",
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: "com.centuriesmutual.key",
            kSecValueData as String: key.withUnsafeBytes { Data($0) }
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
        return key
    }
}

struct ReplyView: View {
    let subject: String
    @Environment(\.managedObjectContext) private var viewContext
    @State private var response: String = ""
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            Text("To: Centuries Mutual")
            Text(subject)
            
            TextEditor(text: $response)
                .frame(height: 200)
                .border(Color.gray)
            
            if isSending {
                ProgressView("Sending...")
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            }
            
            Button("Send") {
                sendReply()
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .navigationTitle("Response")
    }
    
    private func sendReply() {
        guard !response.isEmpty else {
            errorMessage = "Message cannot be empty"
            return
        }
        isSending = true
        let replyMessage = Message(
            id: UUID().uuidString,
            sender: "123",
            date: ISO8601DateFormatter().string(from: Date()),
            title: subject,
            content: encrypt(text: response) ?? "",
            type: "broker",
            attachmentURL: nil
        )
        // Note: This would need to be refactored to access InboxView's method
        // InboxView().sendMessageToServer(replyMessage)
        isSending = false
        response = ""
    }
    
    private func encrypt(text: String) -> String? {
        guard let key = getEncryptionKey() else { return nil }
        let data = text.data(using: .utf8)!
        let sealedBox = try? AES.GCM.seal(data, using: key)
        return sealedBox?.combined.base64EncodedString()
    }
    
    private func getEncryptionKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: "com.centuriesmutual.key",
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: "com.centuriesmutual.key",
            kSecValueData as String: key.withUnsafeBytes { Data($0) }
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
        return key
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onSelect: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSelect: (URL) -> Void
        
        init(onSelect: @escaping (URL) -> Void) {
            self.onSelect = onSelect
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onSelect(url)
            }
        }
    }
}

#Preview {
    InboxView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}