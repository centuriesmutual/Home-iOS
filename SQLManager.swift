import Foundation
import SQLite3
import Combine

// MARK: - SQL Manager with Dropbox Integration
class SQLManager: ObservableObject {
    static let shared = SQLManager()
    
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "sql.database", qos: .background)
    private var cancellables = Set<AnyCancellable>()
    
    @Published var syncStatus: SyncStatus = .idle
    
    enum SyncStatus {
        case idle
        case syncing
        case completed
        case failed(String)
    }
    
    // MARK: - Database Schema
    struct Tables {
        static let enrollments = "enrollments"
        static let users = "users"
        static let messages = "messages"
        static let documents = "documents"
        static let plans = "insurance_plans"
        static let syncLog = "sync_log"
    }
    
    private init() {
        setupDatabase()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    // MARK: - Database Setup
    private func setupDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("CenturiesMutual.db")
        
        if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
            createTables()
            print("Successfully opened database at \(fileURL.path)")
        } else {
            print("Unable to open database")
        }
    }
    
    private func createTables() {
        createEnrollmentsTable()
        createUsersTable()
        createMessagesTable()
        createDocumentsTable()
        createPlansTable()
        createSyncLogTable()
    }
    
    private func createEnrollmentsTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(Tables.enrollments) (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                plan_id TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                enrollment_date TEXT NOT NULL,
                effective_date TEXT,
                personal_info TEXT NOT NULL,
                beneficiaries TEXT,
                medical_history TEXT,
                documents_uploaded INTEGER DEFAULT 0,
                dropbox_folder_id TEXT,
                last_synced TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES \(Tables.users)(id),
                FOREIGN KEY (plan_id) REFERENCES \(Tables.plans)(id)
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error creating enrollments table: \(errmsg)")
        }
    }
    
    private func createUsersTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(Tables.users) (
                id TEXT PRIMARY KEY,
                email TEXT UNIQUE NOT NULL,
                first_name TEXT NOT NULL,
                last_name TEXT NOT NULL,
                phone TEXT,
                address TEXT,
                date_of_birth TEXT,
                ssn_hash TEXT,
                role TEXT DEFAULT 'user',
                dropbox_folder_id TEXT,
                circle_wallet_id TEXT,
                last_synced TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error creating users table: \(errmsg)")
        }
    }
    
    private func createMessagesTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(Tables.messages) (
                id TEXT PRIMARY KEY,
                thread_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                sender_id TEXT NOT NULL,
                sender_type TEXT NOT NULL,
                subject TEXT,
                message TEXT NOT NULL,
                attachments TEXT,
                read_status INTEGER DEFAULT 0,
                dropbox_file_id TEXT,
                enrollment_id TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES \(Tables.users)(id),
                FOREIGN KEY (enrollment_id) REFERENCES \(Tables.enrollments)(id)
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error creating messages table: \(errmsg)")
        }
    }
    
    private func createDocumentsTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(Tables.documents) (
                id TEXT PRIMARY KEY,
                enrollment_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                document_type TEXT NOT NULL,
                file_name TEXT NOT NULL,
                file_size INTEGER,
                mime_type TEXT,
                dropbox_path TEXT NOT NULL,
                dropbox_file_id TEXT,
                shared_link TEXT,
                upload_date TEXT NOT NULL,
                status TEXT DEFAULT 'uploaded',
                FOREIGN KEY (enrollment_id) REFERENCES \(Tables.enrollments)(id),
                FOREIGN KEY (user_id) REFERENCES \(Tables.users)(id)
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error creating documents table: \(errmsg)")
        }
    }
    
    private func createPlansTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(Tables.plans) (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                type TEXT NOT NULL,
                coverage_details TEXT,
                premium_monthly REAL NOT NULL,
                deductible REAL,
                copay_primary REAL,
                copay_specialist REAL,
                out_of_pocket_max REAL,
                network_providers TEXT,
                plan_document_path TEXT,
                dropbox_folder_id TEXT,
                active INTEGER DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error creating plans table: \(errmsg)")
        }
    }
    
    private func createSyncLogTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(Tables.syncLog) (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                table_name TEXT NOT NULL,
                record_id TEXT NOT NULL,
                operation TEXT NOT NULL,
                dropbox_path TEXT,
                sync_status TEXT NOT NULL,
                error_message TEXT,
                created_at TEXT NOT NULL
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error creating sync_log table: \(errmsg)")
        }
    }
    
    // MARK: - Enrollment Operations
    func createEnrollment(_ enrollment: EnrollmentData) -> AnyPublisher<String, Error> {
        return Future { [weak self] promise in
            self?.dbQueue.async {
                guard let self = self else {
                    promise(.failure(SQLError.databaseNotAvailable))
                    return
                }
                
                let enrollmentId = UUID().uuidString
                let currentTime = ISO8601DateFormatter().string(from: Date())
                
                let insertSQL = """
                    INSERT INTO \(Tables.enrollments) 
                    (id, user_id, plan_id, status, enrollment_date, personal_info, beneficiaries, medical_history, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
                
                var statement: OpaquePointer?
                
                if sqlite3_prepare_v2(self.db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_text(statement, 1, enrollmentId, -1, nil)
                    sqlite3_bind_text(statement, 2, enrollment.userId, -1, nil)
                    sqlite3_bind_text(statement, 3, enrollment.planId, -1, nil)
                    sqlite3_bind_text(statement, 4, "pending", -1, nil)
                    sqlite3_bind_text(statement, 5, currentTime, -1, nil)
                    
                    if let personalInfoData = try? JSONEncoder().encode(enrollment.personalInfo),
                       let personalInfoString = String(data: personalInfoData, encoding: .utf8) {
                        sqlite3_bind_text(statement, 6, personalInfoString, -1, nil)
                    }
                    
                    if let beneficiariesData = try? JSONEncoder().encode(enrollment.beneficiaries),
                       let beneficiariesString = String(data: beneficiariesData, encoding: .utf8) {
                        sqlite3_bind_text(statement, 7, beneficiariesString, -1, nil)
                    }
                    
                    if let medicalHistoryData = try? JSONEncoder().encode(enrollment.medicalHistory),
                       let medicalHistoryString = String(data: medicalHistoryData, encoding: .utf8) {
                        sqlite3_bind_text(statement, 8, medicalHistoryString, -1, nil)
                    }
                    
                    sqlite3_bind_text(statement, 9, currentTime, -1, nil)
                    sqlite3_bind_text(statement, 10, currentTime, -1, nil)
                    
                    if sqlite3_step(statement) == SQLITE_DONE {
                        // Sync to Dropbox
                        self.syncEnrollmentToDropbox(enrollmentId: enrollmentId, enrollment: enrollment)
                        promise(.success(enrollmentId))
                    } else {
                        let errmsg = String(cString: sqlite3_errmsg(self.db)!)
                        promise(.failure(SQLError.insertFailed(errmsg)))
                    }
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(self.db)!)
                    promise(.failure(SQLError.queryPreparationFailed(errmsg)))
                }
                
                sqlite3_finalize(statement)
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getEnrollment(id: String) -> AnyPublisher<EnrollmentData?, Error> {
        return Future { [weak self] promise in
            self?.dbQueue.async {
                guard let self = self else {
                    promise(.failure(SQLError.databaseNotAvailable))
                    return
                }
                
                let querySQL = """
                    SELECT e.*, u.first_name, u.last_name, u.email, p.name as plan_name
                    FROM \(Tables.enrollments) e
                    LEFT JOIN \(Tables.users) u ON e.user_id = u.id
                    LEFT JOIN \(Tables.plans) p ON e.plan_id = p.id
                    WHERE e.id = ?;
                """
                
                var statement: OpaquePointer?
                
                if sqlite3_prepare_v2(self.db, querySQL, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_text(statement, 1, id, -1, nil)
                    
                    if sqlite3_step(statement) == SQLITE_ROW {
                        let enrollment = self.parseEnrollmentFromRow(statement: statement)
                        promise(.success(enrollment))
                    } else {
                        promise(.success(nil))
                    }
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(self.db)!)
                    promise(.failure(SQLError.queryFailed(errmsg)))
                }
                
                sqlite3_finalize(statement)
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getAllEnrollments(userId: String? = nil) -> AnyPublisher<[EnrollmentData], Error> {
        return Future { [weak self] promise in
            self?.dbQueue.async {
                guard let self = self else {
                    promise(.failure(SQLError.databaseNotAvailable))
                    return
                }
                
                var querySQL = """
                    SELECT e.*, u.first_name, u.last_name, u.email, p.name as plan_name
                    FROM \(Tables.enrollments) e
                    LEFT JOIN \(Tables.users) u ON e.user_id = u.id
                    LEFT JOIN \(Tables.plans) p ON e.plan_id = p.id
                """
                
                if let userId = userId {
                    querySQL += " WHERE e.user_id = ?"
                }
                
                querySQL += " ORDER BY e.created_at DESC;"
                
                var statement: OpaquePointer?
                var enrollments: [EnrollmentData] = []
                
                if sqlite3_prepare_v2(self.db, querySQL, -1, &statement, nil) == SQLITE_OK {
                    if let userId = userId {
                        sqlite3_bind_text(statement, 1, userId, -1, nil)
                    }
                    
                    while sqlite3_step(statement) == SQLITE_ROW {
                        if let enrollment = self.parseEnrollmentFromRow(statement: statement) {
                            enrollments.append(enrollment)
                        }
                    }
                    
                    promise(.success(enrollments))
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(self.db)!)
                    promise(.failure(SQLError.queryFailed(errmsg)))
                }
                
                sqlite3_finalize(statement)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Message Operations
    func saveMessage(_ message: MessageData) -> AnyPublisher<String, Error> {
        return Future { [weak self] promise in
            self?.dbQueue.async {
                guard let self = self else {
                    promise(.failure(SQLError.databaseNotAvailable))
                    return
                }
                
                let messageId = UUID().uuidString
                let currentTime = ISO8601DateFormatter().string(from: Date())
                
                let insertSQL = """
                    INSERT INTO \(Tables.messages) 
                    (id, thread_id, user_id, sender_id, sender_type, subject, message, attachments, enrollment_id, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
                
                var statement: OpaquePointer?
                
                if sqlite3_prepare_v2(self.db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_text(statement, 1, messageId, -1, nil)
                    sqlite3_bind_text(statement, 2, message.threadId, -1, nil)
                    sqlite3_bind_text(statement, 3, message.userId, -1, nil)
                    sqlite3_bind_text(statement, 4, message.senderId, -1, nil)
                    sqlite3_bind_text(statement, 5, message.senderType, -1, nil)
                    sqlite3_bind_text(statement, 6, message.subject, -1, nil)
                    sqlite3_bind_text(statement, 7, message.message, -1, nil)
                    
                    if let attachmentsData = try? JSONEncoder().encode(message.attachments),
                       let attachmentsString = String(data: attachmentsData, encoding: .utf8) {
                        sqlite3_bind_text(statement, 8, attachmentsString, -1, nil)
                    }
                    
                    sqlite3_bind_text(statement, 9, message.enrollmentId, -1, nil)
                    sqlite3_bind_text(statement, 10, currentTime, -1, nil)
                    
                    if sqlite3_step(statement) == SQLITE_DONE {
                        // Sync message to Dropbox
                        self.syncMessageToDropbox(messageId: messageId, message: message)
                        promise(.success(messageId))
                    } else {
                        let errmsg = String(cString: sqlite3_errmsg(self.db)!)
                        promise(.failure(SQLError.insertFailed(errmsg)))
                    }
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(self.db)!)
                    promise(.failure(SQLError.queryPreparationFailed(errmsg)))
                }
                
                sqlite3_finalize(statement)
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getMessages(threadId: String) -> AnyPublisher<[MessageData], Error> {
        return Future { [weak self] promise in
            self?.dbQueue.async {
                guard let self = self else {
                    promise(.failure(SQLError.databaseNotAvailable))
                    return
                }
                
                let querySQL = """
                    SELECT * FROM \(Tables.messages) 
                    WHERE thread_id = ? 
                    ORDER BY created_at ASC;
                """
                
                var statement: OpaquePointer?
                var messages: [MessageData] = []
                
                if sqlite3_prepare_v2(self.db, querySQL, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_text(statement, 1, threadId, -1, nil)
                    
                    while sqlite3_step(statement) == SQLITE_ROW {
                        if let message = self.parseMessageFromRow(statement: statement) {
                            messages.append(message)
                        }
                    }
                    
                    promise(.success(messages))
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(self.db)!)
                    promise(.failure(SQLError.queryFailed(errmsg)))
                }
                
                sqlite3_finalize(statement)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Document Operations
    func saveDocument(_ document: DocumentData) -> AnyPublisher<String, Error> {
        return Future { [weak self] promise in
            self?.dbQueue.async {
                guard let self = self else {
                    promise(.failure(SQLError.databaseNotAvailable))
                    return
                }
                
                let documentId = UUID().uuidString
                let currentTime = ISO8601DateFormatter().string(from: Date())
                
                let insertSQL = """
                    INSERT INTO \(Tables.documents) 
                    (id, enrollment_id, user_id, document_type, file_name, file_size, mime_type, dropbox_path, upload_date)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
                
                var statement: OpaquePointer?
                
                if sqlite3_prepare_v2(self.db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_text(statement, 1, documentId, -1, nil)
                    sqlite3_bind_text(statement, 2, document.enrollmentId, -1, nil)
                    sqlite3_bind_text(statement, 3, document.userId, -1, nil)
                    sqlite3_bind_text(statement, 4, document.documentType, -1, nil)
                    sqlite3_bind_text(statement, 5, document.fileName, -1, nil)
                    sqlite3_bind_int64(statement, 6, Int64(document.fileSize))
                    sqlite3_bind_text(statement, 7, document.mimeType, -1, nil)
                    sqlite3_bind_text(statement, 8, document.dropboxPath, -1, nil)
                    sqlite3_bind_text(statement, 9, currentTime, -1, nil)
                    
                    if sqlite3_step(statement) == SQLITE_DONE {
                        promise(.success(documentId))
                    } else {
                        let errmsg = String(cString: sqlite3_errmsg(self.db)!)
                        promise(.failure(SQLError.insertFailed(errmsg)))
                    }
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(self.db)!)
                    promise(.failure(SQLError.queryPreparationFailed(errmsg)))
                }
                
                sqlite3_finalize(statement)
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getDocuments(enrollmentId: String) -> AnyPublisher<[DocumentData], Error> {
        return Future { [weak self] promise in
            self?.dbQueue.async {
                guard let self = self else {
                    promise(.failure(SQLError.databaseNotAvailable))
                    return
                }
                
                let querySQL = """
                    SELECT * FROM \(Tables.documents) 
                    WHERE enrollment_id = ? 
                    ORDER BY upload_date DESC;
                """
                
                var statement: OpaquePointer?
                var documents: [DocumentData] = []
                
                if sqlite3_prepare_v2(self.db, querySQL, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_text(statement, 1, enrollmentId, -1, nil)
                    
                    while sqlite3_step(statement) == SQLITE_ROW {
                        if let document = self.parseDocumentFromRow(statement: statement) {
                            documents.append(document)
                        }
                    }
                    
                    promise(.success(documents))
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(self.db)!)
                    promise(.failure(SQLError.queryFailed(errmsg)))
                }
                
                sqlite3_finalize(statement)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Dropbox Sync Operations
    private func syncEnrollmentToDropbox(enrollmentId: String, enrollment: EnrollmentData) {
        syncStatus = .syncing
        
        // Create enrollment folder in Dropbox
        let folderPath = "\(DropboxManager.Config.Folders.enrollments)/\(enrollmentId)"
        
        DropboxManager.shared.createFolder(path: folderPath)
            .flatMap { _ in
                // Create enrollment summary JSON
                let enrollmentSummary = self.createEnrollmentSummary(enrollment: enrollment)
                let summaryData = try! JSONEncoder().encode(enrollmentSummary)
                
                return DropboxManager.shared.uploadFile(
                    data: summaryData,
                    fileName: "enrollment_summary.json",
                    folderPath: folderPath,
                    metadata: [
                        DropboxManager.Config.Metadata.enrollmentId: enrollmentId,
                        DropboxManager.Config.Metadata.userId: enrollment.userId,
                        DropboxManager.Config.Metadata.status: "pending"
                    ],
                    enrollmentId: enrollmentId
                )
            }
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.syncStatus = .failed(error.localizedDescription)
                        self?.logSyncError(table: Tables.enrollments, recordId: enrollmentId, error: error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] fileInfo in
                    self?.syncStatus = .completed
                    self?.updateEnrollmentDropboxInfo(enrollmentId: enrollmentId, folderPath: folderPath)
                    self?.logSyncSuccess(table: Tables.enrollments, recordId: enrollmentId, dropboxPath: folderPath)
                }
            )
            .store(in: &cancellables)
    }
    
    private func syncMessageToDropbox(messageId: String, message: MessageData) {
        let messageData = try! JSONEncoder().encode(message)
        let folderPath = "\(DropboxManager.Config.Folders.messages)/\(message.threadId)"
        
        // Create thread folder if it doesn't exist
        DropboxManager.shared.createFolder(path: folderPath)
            .flatMap { _ in
                DropboxManager.shared.uploadFile(
                    data: messageData,
                    fileName: "\(messageId)_message.json",
                    folderPath: folderPath,
                    metadata: [
                        DropboxManager.Config.Metadata.userId: message.userId,
                        DropboxManager.Config.Metadata.messageThread: message.threadId,
                        "sender_type": message.senderType
                    ]
                )
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to sync message: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("Message synced to Dropbox")
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    private func parseEnrollmentFromRow(statement: OpaquePointer?) -> EnrollmentData? {
        guard let statement = statement else { return nil }
        
        let id = String(cString: sqlite3_column_text(statement, 0))
        let userId = String(cString: sqlite3_column_text(statement, 1))
        let planId = String(cString: sqlite3_column_text(statement, 2))
        let status = String(cString: sqlite3_column_text(statement, 3))
        
        // Parse JSON fields
        var personalInfo: PersonalInfo?
        if let personalInfoText = sqlite3_column_text(statement, 5) {
            let personalInfoString = String(cString: personalInfoText)
            if let data = personalInfoString.data(using: .utf8) {
                personalInfo = try? JSONDecoder().decode(PersonalInfo.self, from: data)
            }
        }
        
        var beneficiaries: [Beneficiary]?
        if let beneficiariesText = sqlite3_column_text(statement, 6) {
            let beneficiariesString = String(cString: beneficiariesText)
            if let data = beneficiariesString.data(using: .utf8) {
                beneficiaries = try? JSONDecoder().decode([Beneficiary].self, from: data)
            }
        }
        
        var medicalHistory: MedicalHistory?
        if let medicalHistoryText = sqlite3_column_text(statement, 7) {
            let medicalHistoryString = String(cString: medicalHistoryText)
            if let data = medicalHistoryString.data(using: .utf8) {
                medicalHistory = try? JSONDecoder().decode(MedicalHistory.self, from: data)
            }
        }
        
        return EnrollmentData(
            id: id,
            userId: userId,
            planId: planId,
            status: status,
            personalInfo: personalInfo ?? PersonalInfo(),
            beneficiaries: beneficiaries ?? [],
            medicalHistory: medicalHistory ?? MedicalHistory()
        )
    }
    
    private func parseMessageFromRow(statement: OpaquePointer?) -> MessageData? {
        guard let statement = statement else { return nil }
        
        let id = String(cString: sqlite3_column_text(statement, 0))
        let threadId = String(cString: sqlite3_column_text(statement, 1))
        let userId = String(cString: sqlite3_column_text(statement, 2))
        let senderId = String(cString: sqlite3_column_text(statement, 3))
        let senderType = String(cString: sqlite3_column_text(statement, 4))
        let subject = sqlite3_column_text(statement, 5) != nil ? String(cString: sqlite3_column_text(statement, 5)) : nil
        let message = String(cString: sqlite3_column_text(statement, 6))
        let enrollmentId = sqlite3_column_text(statement, 9) != nil ? String(cString: sqlite3_column_text(statement, 9)) : nil
        
        var attachments: [MessageAttachment] = []
        if let attachmentsText = sqlite3_column_text(statement, 7) {
            let attachmentsString = String(cString: attachmentsText)
            if let data = attachmentsString.data(using: .utf8) {
                attachments = (try? JSONDecoder().decode([MessageAttachment].self, from: data)) ?? []
            }
        }
        
        return MessageData(
            id: id,
            threadId: threadId,
            userId: userId,
            senderId: senderId,
            senderType: senderType,
            subject: subject,
            message: message,
            attachments: attachments,
            enrollmentId: enrollmentId
        )
    }
    
    private func parseDocumentFromRow(statement: OpaquePointer?) -> DocumentData? {
        guard let statement = statement else { return nil }
        
        let id = String(cString: sqlite3_column_text(statement, 0))
        let enrollmentId = String(cString: sqlite3_column_text(statement, 1))
        let userId = String(cString: sqlite3_column_text(statement, 2))
        let documentType = String(cString: sqlite3_column_text(statement, 3))
        let fileName = String(cString: sqlite3_column_text(statement, 4))
        let fileSize = UInt64(sqlite3_column_int64(statement, 5))
        let mimeType = sqlite3_column_text(statement, 6) != nil ? String(cString: sqlite3_column_text(statement, 6)) : nil
        let dropboxPath = String(cString: sqlite3_column_text(statement, 7))
        
        return DocumentData(
            id: id,
            enrollmentId: enrollmentId,
            userId: userId,
            documentType: documentType,
            fileName: fileName,
            fileSize: fileSize,
            mimeType: mimeType ?? "",
            dropboxPath: dropboxPath
        )
    }
    
    private func createEnrollmentSummary(enrollment: EnrollmentData) -> [String: Any] {
        return [
            "enrollment_id": enrollment.id,
            "user_id": enrollment.userId,
            "plan_id": enrollment.planId,
            "status": enrollment.status,
            "personal_info": enrollment.personalInfo,
            "beneficiaries": enrollment.beneficiaries,
            "medical_history": enrollment.medicalHistory,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
    }
    
    private func updateEnrollmentDropboxInfo(enrollmentId: String, folderPath: String) {
        let updateSQL = "UPDATE \(Tables.enrollments) SET dropbox_folder_id = ?, last_synced = ? WHERE id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, folderPath, -1, nil)
            sqlite3_bind_text(statement, 2, ISO8601DateFormatter().string(from: Date()), -1, nil)
            sqlite3_bind_text(statement, 3, enrollmentId, -1, nil)
            sqlite3_step(statement)
        }
        
        sqlite3_finalize(statement)
    }
    
    private func logSyncSuccess(table: String, recordId: String, dropboxPath: String) {
        logSync(table: table, recordId: recordId, operation: "sync", dropboxPath: dropboxPath, status: "success", error: nil)
    }
    
    private func logSyncError(table: String, recordId: String, error: String) {
        logSync(table: table, recordId: recordId, operation: "sync", dropboxPath: nil, status: "error", error: error)
    }
    
    private func logSync(table: String, recordId: String, operation: String, dropboxPath: String?, status: String, error: String?) {
        let insertSQL = """
            INSERT INTO \(Tables.syncLog) (table_name, record_id, operation, dropbox_path, sync_status, error_message, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, table, -1, nil)
            sqlite3_bind_text(statement, 2, recordId, -1, nil)
            sqlite3_bind_text(statement, 3, operation, -1, nil)
            sqlite3_bind_text(statement, 4, dropboxPath, -1, nil)
            sqlite3_bind_text(statement, 5, status, -1, nil)
            sqlite3_bind_text(statement, 6, error, -1, nil)
            sqlite3_bind_text(statement, 7, ISO8601DateFormatter().string(from: Date()), -1, nil)
            sqlite3_step(statement)
        }
        
        sqlite3_finalize(statement)
    }
}

// MARK: - Data Models
struct EnrollmentData: Codable {
    let id: String
    let userId: String
    let planId: String
    let status: String
    let personalInfo: PersonalInfo
    let beneficiaries: [Beneficiary]
    let medicalHistory: MedicalHistory
}

struct PersonalInfo: Codable {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var phone: String = ""
    var address: Address = Address()
    var dateOfBirth: String = ""
    var ssn: String = ""
    var emergencyContact: EmergencyContact = EmergencyContact()
}

struct Address: Codable {
    var street: String = ""
    var city: String = ""
    var state: String = ""
    var zipCode: String = ""
}

struct EmergencyContact: Codable {
    var name: String = ""
    var relationship: String = ""
    var phone: String = ""
}

struct Beneficiary: Codable {
    let id: String
    let name: String
    let relationship: String
    let percentage: Double
    let address: Address
}

struct MedicalHistory: Codable {
    var preExistingConditions: [String] = []
    var medications: [String] = []
    var allergies: [String] = []
    var primaryPhysician: String = ""
    var lastPhysicalDate: String = ""
}

struct DocumentData: Codable {
    let id: String
    let enrollmentId: String
    let userId: String
    let documentType: String
    let fileName: String
    let fileSize: UInt64
    let mimeType: String
    let dropboxPath: String
}

// MARK: - Error Types
enum SQLError: LocalizedError {
    case databaseNotAvailable
    case queryPreparationFailed(String)
    case queryFailed(String)
    case insertFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseNotAvailable:
            return "Database is not available"
        case .queryPreparationFailed(let message):
            return "Query preparation failed: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        case .insertFailed(let message):
            return "Insert operation failed: \(message)"
        case .updateFailed(let message):
            return "Update operation failed: \(message)"
        case .deleteFailed(let message):
            return "Delete operation failed: \(message)"
        }
    }
}
