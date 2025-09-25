import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Main Enrollment View
struct EnrollmentView: View {
    @StateObject private var viewModel = EnrollmentViewModel()
    @State private var currentStep: EnrollmentStep = .personalInfo
    @State private var showingDocumentPicker = false
    @State private var showingPlanDetails = false
    @State private var selectedPlan: InsurancePlan?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Indicator
                ProgressIndicatorView(currentStep: currentStep, totalSteps: EnrollmentStep.allCases.count)
                
                // Main Content
                TabView(selection: $currentStep) {
                    PersonalInfoStepView(viewModel: viewModel)
                        .tag(EnrollmentStep.personalInfo)
                    
                    PlanSelectionStepView(
                        viewModel: viewModel,
                        selectedPlan: $selectedPlan,
                        showingPlanDetails: $showingPlanDetails
                    )
                    .tag(EnrollmentStep.planSelection)
                    
                    BeneficiariesStepView(viewModel: viewModel)
                        .tag(EnrollmentStep.beneficiaries)
                    
                    MedicalHistoryStepView(viewModel: viewModel)
                        .tag(EnrollmentStep.medicalHistory)
                    
                    DocumentUploadStepView(
                        viewModel: viewModel,
                        showingDocumentPicker: $showingDocumentPicker
                    )
                    .tag(EnrollmentStep.documents)
                    
                    ReviewSubmitStepView(viewModel: viewModel)
                        .tag(EnrollmentStep.review)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Navigation Buttons
                HStack {
                    if currentStep != .personalInfo {
                        Button("Back") {
                            withAnimation {
                                currentStep = currentStep.previous() ?? .personalInfo
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    
                    Spacer()
                    
                    Button(currentStep == .review ? "Submit" : "Next") {
                        if currentStep == .review {
                            viewModel.submitEnrollment()
                        } else {
                            withAnimation {
                                if let nextStep = currentStep.next() {
                                    currentStep = nextStep
                                }
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!viewModel.canProceed(from: currentStep))
                }
                .padding()
            }
            .navigationTitle("Health Insurance Enrollment")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView { documents in
                    viewModel.uploadDocuments(documents)
                }
            }
            .sheet(isPresented: $showingPlanDetails) {
                if let plan = selectedPlan {
                    PlanDetailsView(plan: plan)
                }
            }
            .alert("Enrollment Status", isPresented: $viewModel.showingAlert) {
                Button("OK") {
                    if viewModel.enrollmentCompleted {
                        // Navigate to success screen or dismiss
                    }
                }
            } message: {
                Text(viewModel.alertMessage)
            }
            .overlay {
                if viewModel.isLoading {
                    LoadingOverlay()
                }
            }
        }
        .onAppear {
            viewModel.loadInsurancePlans()
        }
    }
}

// MARK: - Personal Info Step
struct PersonalInfoStepView: View {
    @ObservedObject var viewModel: EnrollmentViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Personal Information")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    HStack {
                        TextField("First Name", text: $viewModel.personalInfo.firstName)
                            .textFieldStyle(CustomTextFieldStyle())
                        
                        TextField("Last Name", text: $viewModel.personalInfo.lastName)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    TextField("Email Address", text: $viewModel.personalInfo.email)
                        .textFieldStyle(CustomTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Phone Number", text: $viewModel.personalInfo.phone)
                        .textFieldStyle(CustomTextFieldStyle())
                        .keyboardType(.phonePad)
                    
                    DatePicker("Date of Birth", selection: $viewModel.dateOfBirth, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Address")
                            .font(.headline)
                        
                        TextField("Street Address", text: $viewModel.personalInfo.address.street)
                            .textFieldStyle(CustomTextFieldStyle())
                        
                        HStack {
                            TextField("City", text: $viewModel.personalInfo.address.city)
                                .textFieldStyle(CustomTextFieldStyle())
                            
                            TextField("State", text: $viewModel.personalInfo.address.state)
                                .textFieldStyle(CustomTextFieldStyle())
                            
                            TextField("ZIP", text: $viewModel.personalInfo.address.zipCode)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Emergency Contact")
                            .font(.headline)
                        
                        TextField("Name", text: $viewModel.personalInfo.emergencyContact.name)
                            .textFieldStyle(CustomTextFieldStyle())
                        
                        HStack {
                            TextField("Relationship", text: $viewModel.personalInfo.emergencyContact.relationship)
                                .textFieldStyle(CustomTextFieldStyle())
                            
                            TextField("Phone", text: $viewModel.personalInfo.emergencyContact.phone)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.phonePad)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Plan Selection Step
struct PlanSelectionStepView: View {
    @ObservedObject var viewModel: EnrollmentViewModel
    @Binding var selectedPlan: InsurancePlan?
    @Binding var showingPlanDetails: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Choose Your Plan")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.availablePlans) { plan in
                        PlanCardView(
                            plan: plan,
                            isSelected: viewModel.selectedPlanId == plan.id
                        ) {
                            viewModel.selectedPlanId = plan.id
                        } onDetailsPressed: {
                            selectedPlan = plan
                            showingPlanDetails = true
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct PlanCardView: View {
    let plan: InsurancePlan
    let isSelected: Bool
    let onSelect: () -> Void
    let onDetailsPressed: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(plan.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Details", action: onDetailsPressed)
                    .font(.caption)
                    .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Monthly Premium:")
                        .font(.subheadline)
                    Spacer()
                    Text("$\(plan.premiumMonthly, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                if let deductible = plan.deductible {
                    HStack {
                        Text("Deductible:")
                            .font(.subheadline)
                        Spacer()
                        Text("$\(deductible, specifier: "%.0f")")
                            .font(.subheadline)
                    }
                }
            }
            
            Button(action: onSelect) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? Color(red: 0.83, green: 0.69, blue: 0.22) : .gray)
                    Text(isSelected ? "Selected" : "Select Plan")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSelected ? Color(red: 0.83, green: 0.69, blue: 0.22).opacity(0.1) : Color(.systemGray6))
                .foregroundColor(isSelected ? Color(red: 0.83, green: 0.69, blue: 0.22) : .primary)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color(red: 0.83, green: 0.69, blue: 0.22) : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Placeholder Views for Other Steps
struct BeneficiariesStepView: View {
    @ObservedObject var viewModel: EnrollmentViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Beneficiaries")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Beneficiary information is optional for health insurance enrollment.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
}

struct MedicalHistoryStepView: View {
    @ObservedObject var viewModel: EnrollmentViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Medical History")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Medical history information is optional for health insurance enrollment.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
}

struct DocumentUploadStepView: View {
    @ObservedObject var viewModel: EnrollmentViewModel
    @Binding var showingDocumentPicker: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Document Upload")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Upload any required documents for your enrollment.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("Upload Documents") {
                    showingDocumentPicker = true
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

struct ReviewSubmitStepView: View {
    @ObservedObject var viewModel: EnrollmentViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Review & Submit")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Please review your information before submitting your enrollment.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
}

// MARK: - Supporting Views
struct PlanDetailsView: View {
    let plan: InsurancePlan
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(plan.description)
                        .font(.body)
                        .padding()
                }
            }
            .navigationTitle(plan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DocumentPickerView: View {
    let onDocumentsSelected: ([DocumentData]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Document Picker")
                    .font(.title2)
                    .padding()
                
                Text("This would integrate with the document picker to upload files.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .navigationTitle("Upload Documents")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Processing...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
        }
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding()
            .background(Color(red: 0.83, green: 0.69, blue: 0.22))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundColor(Color(red: 0.08, green: 0.26, blue: 0.16))
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Data Models
struct PersonalInfo {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var phone: String = ""
    var address = Address()
    var emergencyContact = EmergencyContact()
}

struct Address {
    var street: String = ""
    var city: String = ""
    var state: String = ""
    var zipCode: String = ""
}

struct EmergencyContact {
    var name: String = ""
    var relationship: String = ""
    var phone: String = ""
}

struct Beneficiary {
    let id = UUID()
    var name: String = ""
    var relationship: String = ""
    var percentage: Double = 0.0
}

struct MedicalHistory {
    var hasConditions: Bool = false
    var conditions: [String] = []
    var medications: [String] = []
}

struct DocumentData {
    let id = UUID()
    var fileName: String = ""
    var fileData: Data = Data()
    var uploadDate: Date = Date()
}

// MARK: - Enrollment Models
struct InsurancePlan: Identifiable, Codable {
    let id = UUID()
    let name: String
    let type: String
    let coverageDetails: String
    let premiumMonthly: Double
    let deductible: Double?
    let copayPrimary: Double?
    let copaySpecialist: Double?
    let outOfPocketMax: Double?
    let networkProviders: String?
    let description: String
}

enum EnrollmentStep: String, CaseIterable {
    case personalInfo = "Personal Information"
    case planSelection = "Plan Selection"
    case beneficiaries = "Beneficiaries"
    case medicalHistory = "Medical History"
    case documents = "Documents"
    case review = "Review & Submit"
    
    func next() -> EnrollmentStep? {
        let allSteps = EnrollmentStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: self) else { return nil }
        return currentIndex < allSteps.count - 1 ? allSteps[currentIndex + 1] : nil
    }
    
    func previous() -> EnrollmentStep? {
        let allSteps = EnrollmentStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: self) else { return nil }
        return currentIndex > 0 ? allSteps[currentIndex - 1] : nil
    }
}

// MARK: - Enrollment View Model
class EnrollmentViewModel: ObservableObject {
    @Published var personalInfo = PersonalInfo()
    @Published var selectedPlanId: UUID?
    @Published var beneficiaries: [Beneficiary] = []
    @Published var medicalHistory = MedicalHistory()
    @Published var uploadedDocuments: [DocumentData] = []
    @Published var availablePlans: [InsurancePlan] = []
    @Published var isLoading = false
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var enrollmentCompleted = false
    
    var dateOfBirth = Date()
    
    func loadInsurancePlans() {
        // Mock data - in real app, this would fetch from API
        availablePlans = [
            InsurancePlan(
                name: "Basic Health Plan",
                type: "Health",
                coverageDetails: "Essential health benefits with basic coverage",
                premiumMonthly: 250.0,
                deductible: 5000.0,
                copayPrimary: 25.0,
                copaySpecialist: 50.0,
                outOfPocketMax: 8000.0,
                networkProviders: "Local network providers",
                description: "Comprehensive basic health coverage with essential benefits"
            ),
            InsurancePlan(
                name: "Premium Health Plan",
                type: "Health",
                coverageDetails: "Comprehensive health benefits with premium coverage",
                premiumMonthly: 450.0,
                deductible: 2000.0,
                copayPrimary: 15.0,
                copaySpecialist: 30.0,
                outOfPocketMax: 5000.0,
                networkProviders: "Extended network providers",
                description: "Premium health coverage with comprehensive benefits and lower out-of-pocket costs"
            ),
            InsurancePlan(
                name: "Life Insurance Plan",
                type: "Life",
                coverageDetails: "Term life insurance with flexible coverage options",
                premiumMonthly: 75.0,
                deductible: nil,
                copayPrimary: nil,
                copaySpecialist: nil,
                outOfPocketMax: nil,
                networkProviders: nil,
                description: "Term life insurance providing financial protection for your loved ones"
            )
        ]
    }
    
    func canProceed(from step: EnrollmentStep) -> Bool {
        switch step {
        case .personalInfo:
            return !personalInfo.firstName.isEmpty && 
                   !personalInfo.lastName.isEmpty && 
                   !personalInfo.email.isEmpty
        case .planSelection:
            return selectedPlanId != nil
        case .beneficiaries:
            return true // Beneficiaries are optional
        case .medicalHistory:
            return true // Medical history is optional
        case .documents:
            return true // Documents are optional
        case .review:
            return true
        }
    }
    
    func submitEnrollment() {
        isLoading = true
        
        // Simulate enrollment submission
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isLoading = false
            self.enrollmentCompleted = true
            self.alertMessage = "Enrollment submitted successfully! You will receive a confirmation email shortly."
            self.showingAlert = true
        }
    }
    
    func uploadDocuments(_ documents: [DocumentData]) {
        uploadedDocuments.append(contentsOf: documents)
    }
}

// MARK: - Progress Indicator
struct ProgressIndicatorView: View {
    let currentStep: EnrollmentStep
    let totalSteps: Int
    
    private var currentStepIndex: Int {
        EnrollmentStep.allCases.firstIndex(of: currentStep) ?? 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStepIndex ? Color(red: 0.83, green: 0.69, blue: 0.22) : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    if index < totalSteps - 1 {
                        Rectangle()
                            .fill(index < currentStepIndex ? Color(red: 0.83, green: 0.69, blue: 0.22) : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            
            Text("Step \(currentStepIndex + 1) of \(totalSteps): \(currentStep.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        EnrollmentView()
    }
}
