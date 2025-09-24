import Foundation

// MARK: - CMS Medicare API Manager
class CMSMedicareAPI: ObservableObject {
    static let shared = CMSMedicareAPI()
    
    private let baseURL = "https://data.cms.gov/api/v1"
    private let medicareAPIURL = "https://api.cms.gov/v1"
    
    @Published var medicarePlans: [MedicarePlan] = []
    @Published var partDPlans: [PartDPlan] = []
    @Published var providers: [MedicareProvider] = []
    @Published var isLoading = false
    
    private init() {}
    
    // MARK: - Medicare Advantage Plans
    func getMedicareAdvantagePlans(
        state: String,
        county: String? = nil,
        zipCode: String? = nil
    ) async throws -> [MedicarePlan] {
        isLoading = true
        defer { isLoading = false }
        
        let url = URL(string: "\(medicareAPIURL)/medicare-advantage/plans")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.cmsAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "state", value: state)]
        
        if let county = county {
            queryItems.append(URLQueryItem(name: "county", value: county))
        }
        
        if let zipCode = zipCode {
            queryItems.append(URLQueryItem(name: "zip_code", value: zipCode))
        }
        
        components.queryItems = queryItems
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CMSError.medicarePlansFailed
        }
        
        let plansResponse = try JSONDecoder().decode(MedicarePlansResponse.self, from: data)
        self.medicarePlans = plansResponse.plans
        return plansResponse.plans
    }
    
    func getMedicarePlanDetails(planId: String) async throws -> MedicarePlanDetails {
        let url = URL(string: "\(medicareAPIURL)/medicare-advantage/plans/\(planId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.cmsAPIKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CMSError.planDetailsFailed
        }
        
        return try JSONDecoder().decode(MedicarePlanDetails.self, from: data)
    }
    
    // MARK: - Part D Prescription Drug Plans
    func getPartDPlans(
        state: String,
        region: String? = nil
    ) async throws -> [PartDPlan] {
        let url = URL(string: "\(medicareAPIURL)/part-d/plans")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.cmsAPIKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "state", value: state)]
        
        if let region = region {
            queryItems.append(URLQueryItem(name: "region", value: region))
        }
        
        components.queryItems = queryItems
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CMSError.partDPlansFailed
        }
        
        let plansResponse = try JSONDecoder().decode(PartDPlansResponse.self, from: data)
        self.partDPlans = plansResponse.plans
        return plansResponse.plans
    }
    
    func getPartDPlanFormulary(planId: String) async throws -> PartDFormulary {
        let url = URL(string: "\(medicareAPIURL)/part-d/plans/\(planId)/formulary")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.cmsAPIKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CMSError.formularyFailed
        }
        
        return try JSONDecoder().decode(PartDFormulary.self, from: data)
    }
    
    // MARK: - Provider Directory
    func getMedicareProviders(
        state: String,
        specialty: String? = nil,
        city: String? = nil,
        zipCode: String? = nil
    ) async throws -> [MedicareProvider] {
        let url = URL(string: "\(medicareAPIURL)/providers")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.cmsAPIKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "state", value: state)]
        
        if let specialty = specialty {
            queryItems.append(URLQueryItem(name: "specialty", value: specialty))
        }
        
        if let city = city {
            queryItems.append(URLQueryItem(name: "city", value: city))
        }
        
        if let zipCode = zipCode {
            queryItems.append(URLQueryItem(name: "zip_code", value: zipCode))
        }
        
        components.queryItems = queryItems
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CMSError.providersFailed
        }
        
        let providersResponse = try JSONDecoder().decode(MedicareProvidersResponse.self, from: data)
        self.providers = providersResponse.providers
        return providersResponse.providers
    }
    
    // MARK: - Quality Ratings
    func getPlanQualityRatings(planId: String) async throws -> PlanQualityRating {
        let url = URL(string: "\(medicareAPIURL)/quality-ratings/plans/\(planId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.cmsAPIKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CMSError.qualityRatingsFailed
        }
        
        return try JSONDecoder().decode(PlanQualityRating.self, from: data)
    }
    
    // MARK: - Star Ratings
    func getStarRatings(planId: String) async throws -> StarRating {
        let url = URL(string: "\(medicareAPIURL)/star-ratings/plans/\(planId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.cmsAPIKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CMSError.starRatingsFailed
        }
        
        return try JSONDecoder().decode(StarRating.self, from: data)
    }
    
    // MARK: - Cost Data
    func getPlanCosts(planId: String, zipCode: String) async throws -> PlanCosts {
        let url = URL(string: "\(medicareAPIURL)/costs/plans/\(planId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.cmsAPIKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "zip_code", value: zipCode)]
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CMSError.costDataFailed
        }
        
        return try JSONDecoder().decode(PlanCosts.self, from: data)
    }
    
    // MARK: - Enrollment Data
    func getEnrollmentData(planId: String) async throws -> EnrollmentData {
        let url = URL(string: "\(medicareAPIURL)/enrollment/plans/\(planId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.cmsAPIKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CMSError.enrollmentDataFailed
        }
        
        return try JSONDecoder().decode(EnrollmentData.self, from: data)
    }
    
    // MARK: - Beneficiary Data
    func getBeneficiaryEligibility(
        medicareNumber: String,
        dateOfBirth: String,
        firstName: String,
        lastName: String
    ) async throws -> BeneficiaryEligibility {
        let url = URL(string: "\(medicareAPIURL)/beneficiaries/eligibility")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(CenturiesMutualConfig.shared.cmsAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let eligibilityRequest = BeneficiaryEligibilityRequest(
            medicareNumber: medicareNumber,
            dateOfBirth: dateOfBirth,
            firstName: firstName,
            lastName: lastName
        )
        
        request.httpBody = try JSONEncoder().encode(eligibilityRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CMSError.beneficiaryEligibilityFailed
        }
        
        return try JSONDecoder().decode(BeneficiaryEligibility.self, from: data)
    }
    
    // MARK: - Claims Data
    func getClaimsData(
        providerId: String? = nil,
        planId: String? = nil,
        startDate: String,
        endDate: String
    ) async throws -> ClaimsData {
        let url = URL(string: "\(medicareAPIURL)/claims")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.cmsAPIKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]
        
        if let providerId = providerId {
            queryItems.append(URLQueryItem(name: "provider_id", value: providerId))
        }
        
        if let planId = planId {
            queryItems.append(URLQueryItem(name: "plan_id", value: planId))
        }
        
        components.queryItems = queryItems
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CMSError.claimsDataFailed
        }
        
        return try JSONDecoder().decode(ClaimsData.self, from: data)
    }
}

// MARK: - Supporting Types
struct MedicarePlansResponse: Codable {
    let plans: [MedicarePlan]
    let totalCount: Int
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case plans
        case totalCount = "total_count"
        case lastUpdated = "last_updated"
    }
}

struct MedicarePlan: Codable, Identifiable {
    let id: String
    let name: String
    let organizationName: String
    let planType: MedicarePlanType
    let state: String
    let county: String
    let zipCode: String
    let monthlyPremium: Double
    let annualDeductible: Double
    let outOfPocketMaximum: Double
    let copay: Double?
    let coinsurance: Double?
    let benefits: [MedicareBenefit]
    let networkType: MedicareNetworkType
    let starRating: Double?
    let enrollmentCount: Int?
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, state, county, zipCode
        case organizationName = "organization_name"
        case planType = "plan_type"
        case monthlyPremium = "monthly_premium"
        case annualDeductible = "annual_deductible"
        case outOfPocketMaximum = "out_of_pocket_maximum"
        case copay, coinsurance, benefits
        case networkType = "network_type"
        case starRating = "star_rating"
        case enrollmentCount = "enrollment_count"
        case lastUpdated = "last_updated"
    }
}

enum MedicarePlanType: String, Codable {
    case hmo = "HMO"
    case ppo = "PPO"
    case pffs = "PFFS"
    case snp = "SNP"
    case msa = "MSA"
}

enum MedicareNetworkType: String, Codable {
    case local = "Local"
    case regional = "Regional"
    case national = "National"
}

struct MedicareBenefit: Codable {
    let category: String
    let name: String
    let covered: Bool
    let copay: Double?
    let coinsurance: Double?
    let deductible: Double?
    let limit: String?
}

struct MedicarePlanDetails: Codable {
    let plan: MedicarePlan
    let summaryOfBenefits: String
    let evidenceOfCoverage: String
    let providerDirectory: String
    let formulary: [FormularyDrug]
    let appealsProcess: String
    let grievanceProcess: String
    let languageServices: [String]
    let accessibilityServices: [String]
    
    enum CodingKeys: String, CodingKey {
        case plan
        case summaryOfBenefits = "summary_of_benefits"
        case evidenceOfCoverage = "evidence_of_coverage"
        case providerDirectory = "provider_directory"
        case formulary
        case appealsProcess = "appeals_process"
        case grievanceProcess = "grievance_process"
        case languageServices = "language_services"
        case accessibilityServices = "accessibility_services"
    }
}

struct PartDPlansResponse: Codable {
    let plans: [PartDPlan]
    let totalCount: Int
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case plans
        case totalCount = "total_count"
        case lastUpdated = "last_updated"
    }
}

struct PartDPlan: Codable, Identifiable {
    let id: String
    let name: String
    let organizationName: String
    let state: String
    let region: String
    let monthlyPremium: Double
    let annualDeductible: Double
    let initialCoverageLimit: Double
    let coverageGap: Bool
    let catastrophicCoverage: Bool
    let formulary: [FormularyDrug]
    let starRating: Double?
    let enrollmentCount: Int?
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, state, region
        case organizationName = "organization_name"
        case monthlyPremium = "monthly_premium"
        case annualDeductible = "annual_deductible"
        case initialCoverageLimit = "initial_coverage_limit"
        case coverageGap = "coverage_gap"
        case catastrophicCoverage = "catastrophic_coverage"
        case formulary
        case starRating = "star_rating"
        case enrollmentCount = "enrollment_count"
        case lastUpdated = "last_updated"
    }
}

struct PartDFormulary: Codable {
    let planId: String
    let drugs: [FormularyDrug]
    let tiers: [FormularyTier]
    case restrictions: [FormularyRestriction]
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case drugs, tiers, restrictions
        case lastUpdated = "last_updated"
    }
}

struct FormularyTier: Codable {
    let tier: Int
    let name: String
    let copay: Double?
    let coinsurance: Double?
    let description: String
}

struct FormularyRestriction: Codable {
    let drugName: String
    let restrictionType: String
    let description: String
    let requiredDocumentation: [String]
    
    enum CodingKeys: String, CodingKey {
        case drugName = "drug_name"
        case restrictionType = "restriction_type"
        case description
        case requiredDocumentation = "required_documentation"
    }
}

struct MedicareProvidersResponse: Codable {
    let providers: [MedicareProvider]
    let totalCount: Int
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case providers
        case totalCount = "total_count"
        case lastUpdated = "last_updated"
    }
}

struct MedicareProvider: Codable, Identifiable {
    let id: String
    let name: String
    let specialty: String
    let address: MedicareAddress
    let phone: String?
    let acceptingNewPatients: Bool
    let languages: [String]
    let medicareAssignment: Bool
    let starRating: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, specialty, address, phone
        case acceptingNewPatients = "accepting_new_patients"
        case languages
        case medicareAssignment = "medicare_assignment"
        case starRating = "star_rating"
    }
}

struct MedicareAddress: Codable {
    let street: String
    let city: String
    let state: String
    let zipCode: String
    let latitude: Double?
    let longitude: Double?
    
    enum CodingKeys: String, CodingKey {
        case street, city, state
        case zipCode = "zip_code"
        case latitude, longitude
    }
}

struct PlanQualityRating: Codable {
    let planId: String
    let overallRating: Double
    let stayHealthyRatings: StayHealthyRatings
    let managingChronicConditions: ManagingChronicConditions
    let memberExperience: MemberExperience
    let memberComplaints: MemberComplaints
    let customerService: CustomerService
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case overallRating = "overall_rating"
        case stayHealthyRatings = "stay_healthy_ratings"
        case managingChronicConditions = "managing_chronic_conditions"
        case memberExperience = "member_experience"
        case memberComplaints = "member_complaints"
        case customerService = "customer_service"
        case lastUpdated = "last_updated"
    }
}

struct StayHealthyRatings: Codable {
    let breastCancerScreening: Double
    let colorectalCancerScreening: Double
    let diabetesCare: Double
    let fluVaccination: Double
    let monitoringPhysicalActivity: Double
    
    enum CodingKeys: String, CodingKey {
        case breastCancerScreening = "breast_cancer_screening"
        case colorectalCancerScreening = "colorectal_cancer_screening"
        case diabetesCare = "diabetes_care"
        case fluVaccination = "flu_vaccination"
        case monitoringPhysicalActivity = "monitoring_physical_activity"
    }
}

struct ManagingChronicConditions: Codable {
    let diabetesCare: Double
    let heartDiseaseCare: Double
    let copdCare: Double
    let medicationAdherence: Double
    
    enum CodingKeys: String, CodingKey {
        case diabetesCare = "diabetes_care"
        case heartDiseaseCare = "heart_disease_care"
        case copdCare = "copd_care"
        case medicationAdherence = "medication_adherence"
    }
}

struct MemberExperience: Codable {
    let gettingCareEasily: Double
    let gettingNeededCare: Double
    let doctorCommunication: Double
    let customerService: Double
    
    enum CodingKeys: String, CodingKey {
        case gettingCareEasily = "getting_care_easily"
        case gettingNeededCare = "getting_needed_care"
        case doctorCommunication = "doctor_communication"
        case customerService = "customer_service"
    }
}

struct MemberComplaints: Codable {
    let complaintsAboutPlan: Double
    let membersChoosingToLeave: Double
    let problemsGettingServices: Double
    
    enum CodingKeys: String, CodingKey {
        case complaintsAboutPlan = "complaints_about_plan"
        case membersChoosingToLeave = "members_choosing_to_leave"
        case problemsGettingServices = "problems_getting_services"
    }
}

struct CustomerService: Codable {
    let callCenter: Double
    let appeals: Double
    let newMember: Double
    
    enum CodingKeys: String, CodingKey {
        case callCenter = "call_center"
        case appeals
        case newMember = "new_member"
    }
}

struct StarRating: Codable {
    let planId: String
    let overallRating: Double
    let ratings: [StarRatingCategory]
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case overallRating = "overall_rating"
        case ratings
        case lastUpdated = "last_updated"
    }
}

struct StarRatingCategory: Codable {
    let category: String
    let rating: Double
    let description: String
}

struct PlanCosts: Codable {
    let planId: String
    let zipCode: String
    let monthlyPremium: Double
    let annualDeductible: Double
    let outOfPocketMaximum: Double
    let copay: Double?
    let coinsurance: Double?
    let costSharing: [CostSharingDetail]
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case zipCode = "zip_code"
        case monthlyPremium = "monthly_premium"
        case annualDeductible = "annual_deductible"
        case outOfPocketMaximum = "out_of_pocket_maximum"
        case copay, coinsurance
        case costSharing = "cost_sharing"
        case lastUpdated = "last_updated"
    }
}

struct CostSharingDetail: Codable {
    let service: String
    let copay: Double?
    let coinsurance: Double?
    let deductible: Double?
    let limit: String?
}

struct EnrollmentData: Codable {
    let planId: String
    let totalEnrollment: Int
    let enrollmentByState: [StateEnrollment]
    let enrollmentByAge: [AgeEnrollment]
    let enrollmentByGender: [GenderEnrollment]
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case totalEnrollment = "total_enrollment"
        case enrollmentByState = "enrollment_by_state"
        case enrollmentByAge = "enrollment_by_age"
        case enrollmentByGender = "enrollment_by_gender"
        case lastUpdated = "last_updated"
    }
}

struct StateEnrollment: Codable {
    let state: String
    let enrollment: Int
}

struct AgeEnrollment: Codable {
    let ageRange: String
    let enrollment: Int
    
    enum CodingKeys: String, CodingKey {
        case ageRange = "age_range"
        case enrollment
    }
}

struct GenderEnrollment: Codable {
    let gender: String
    let enrollment: Int
}

struct BeneficiaryEligibilityRequest: Codable {
    let medicareNumber: String
    let dateOfBirth: String
    let firstName: String
    let lastName: String
    
    enum CodingKeys: String, CodingKey {
        case medicareNumber = "medicare_number"
        case dateOfBirth = "date_of_birth"
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct BeneficiaryEligibility: Codable {
    let eligible: Bool
    let medicareNumber: String
    let partA: PartEligibility
    let partB: PartEligibility
    let partC: PartEligibility
    let partD: PartEligibility
    let effectiveDate: String
    let terminationDate: String?
    
    enum CodingKeys: String, CodingKey {
        case eligible
        case medicareNumber = "medicare_number"
        case partA = "part_a"
        case partB = "part_b"
        case partC = "part_c"
        case partD = "part_d"
        case effectiveDate = "effective_date"
        case terminationDate = "termination_date"
    }
}

struct PartEligibility: Codable {
    let eligible: Bool
    let effectiveDate: String
    let terminationDate: String?
    let premium: Double?
    let deductible: Double?
    
    enum CodingKeys: String, CodingKey {
        case eligible
        case effectiveDate = "effective_date"
        case terminationDate = "termination_date"
        case premium, deductible
    }
}

struct ClaimsData: Codable {
    let totalClaims: Int
    let totalAmount: Double
    let claimsByType: [ClaimsByType]
    let claimsByProvider: [ClaimsByProvider]
    let claimsByDate: [ClaimsByDate]
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case totalClaims = "total_claims"
        case totalAmount = "total_amount"
        case claimsByType = "claims_by_type"
        case claimsByProvider = "claims_by_provider"
        case claimsByDate = "claims_by_date"
        case lastUpdated = "last_updated"
    }
}

struct ClaimsByType: Codable {
    let type: String
    let count: Int
    let amount: Double
}

struct ClaimsByProvider: Codable {
    let providerId: String
    let providerName: String
    let count: Int
    let amount: Double
    
    enum CodingKeys: String, CodingKey {
        case providerId = "provider_id"
        case providerName = "provider_name"
        case count, amount
    }
}

struct ClaimsByDate: Codable {
    let date: String
    let count: Int
    let amount: Double
}

enum CMSError: Error, LocalizedError {
    case medicarePlansFailed
    case planDetailsFailed
    case partDPlansFailed
    case formularyFailed
    case providersFailed
    case qualityRatingsFailed
    case starRatingsFailed
    case costDataFailed
    case enrollmentDataFailed
    case beneficiaryEligibilityFailed
    case claimsDataFailed
    case invalidAPIKey
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .medicarePlansFailed:
            return "Failed to fetch Medicare Advantage plans."
        case .planDetailsFailed:
            return "Failed to fetch plan details."
        case .partDPlansFailed:
            return "Failed to fetch Part D prescription drug plans."
        case .formularyFailed:
            return "Failed to fetch formulary information."
        case .providersFailed:
            return "Failed to fetch provider directory."
        case .qualityRatingsFailed:
            return "Failed to fetch quality ratings."
        case .starRatingsFailed:
            return "Failed to fetch star ratings."
        case .costDataFailed:
            return "Failed to fetch cost data."
        case .enrollmentDataFailed:
            return "Failed to fetch enrollment data."
        case .beneficiaryEligibilityFailed:
            return "Failed to check beneficiary eligibility."
        case .claimsDataFailed:
            return "Failed to fetch claims data."
        case .invalidAPIKey:
            return "Invalid API key for CMS services."
        case .networkError:
            return "Network error occurred while accessing CMS data."
        }
    }
}
