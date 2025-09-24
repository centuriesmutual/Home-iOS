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
                                currentStep = currentStep.previous()
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
                                currentStep = currentStep.next()
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
                    
                    Text(plan