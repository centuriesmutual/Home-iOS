import Foundation
import CoreLocation

// MARK: - Marketplace Finder API Manager
class MarketplaceFinderAPI: ObservableObject {
    static let shared = MarketplaceFinderAPI()
    
    private let baseURL = "https://api.healthcare.gov"
    private let subsidyURL = "https://api.healthcare.gov/api/v1"
    
    @Published var availablePlans: [MarketplacePlan] = []
    @Published var subsidyEligibility: SubsidyEligibility?
    @Published var isLoading = false
    
    private init() {}
    
    // MARK: - Plan Search
    func searchPlans(
        state: String,
        county: String,
        householdSize: Int,
        householdIncome: Double,
        age: Int,
        tobaccoUser: Bool = false
    ) async throws -> [MarketplacePlan] {
        isLoading = true
        defer { isLoading = false }
        
        let url = URL(string: "\(baseURL)/api/v1/plans/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(CenturiesMutualConfig.shared.marketplaceAPIKey)", forHTTPHeaderField: "Authorization")
        
        let searchRequest = MarketplaceSearchRequest(
            state: state,
            county: county,
            householdSize: householdSize,
            householdIncome: householdIncome,
            age: age,
            tobaccoUser: tobaccoUser
        )
        
        request.httpBody = try JSONEncoder().encode(searchRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketplaceError.searchFailed
        }
        
        let searchResponse = try JSONDecoder().decode(MarketplaceSearchResponse.self, from: data)
        self.availablePlans = searchResponse.plans
        return searchResponse.plans
    }
    
    func getSubsidizedPlans(
        state: String,
        county: String,
        householdSize: Int,
        householdIncome: Double,
        age: Int
    ) async throws -> [SubsidizedPlan] {
        let plans = try await searchPlans(
            state: state,
            county: county,
            householdSize: householdSize,
            householdIncome: householdIncome,
            age: age
        )
        
        let subsidyInfo = try await calculateSubsidy(
            state: state,
            county: county,
            householdSize: householdSize,
            householdIncome: householdIncome,
            age: age
        )
        
        return plans.compactMap { plan in
            guard let subsidy = subsidyInfo else { return nil }
            
            let subsidizedPremium = max(0, plan.premium - subsidy.premiumTaxCredit)
            let totalCost = subsidizedPremium + plan.deductible + plan.outOfPocketMaximum
            
            return SubsidizedPlan(
                plan: plan,
                originalPremium: plan.premium,
                subsidizedPremium: subsidizedPremium,
                premiumTaxCredit: subsidy.premiumTaxCredit,
                costSharingReduction: subsidy.costSharingReduction,
                totalEstimatedCost: totalCost,
                savings: plan.premium - subsidizedPremium
            )
        }
    }
    
    // MARK: - Subsidy Calculation
    func calculateSubsidy(
        state: String,
        county: String,
        householdSize: Int,
        householdIncome: Double,
        age: Int
    ) async throws -> SubsidyEligibility {
        let url = URL(string: "\(subsidyURL)/subsidy/calculate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(CenturiesMutualConfig.shared.marketplaceAPIKey)", forHTTPHeaderField: "Authorization")
        
        let subsidyRequest = SubsidyCalculationRequest(
            state: state,
            county: county,
            householdSize: householdSize,
            householdIncome: householdIncome,
            age: age,
            taxYear: Calendar.current.component(.year, from: Date())
        )
        
        request.httpBody = try JSONEncoder().encode(subsidyRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketplaceError.subsidyCalculationFailed
        }
        
        let subsidyResponse = try JSONDecoder().decode(SubsidyEligibility.self, from: data)
        self.subsidyEligibility = subsidyResponse
        return subsidyResponse
    }
    
    // MARK: - Plan Details
    func getPlanDetails(planId: String) async throws -> MarketplacePlanDetails {
        let url = URL(string: "\(baseURL)/api/v1/plans/\(planId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.marketplaceAPIKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketplaceError.planDetailsFailed
        }
        
        return try JSONDecoder().decode(MarketplacePlanDetails.self, from: data)
    }
    
    // MARK: - Provider Network
    func getProviderNetwork(planId: String, zipCode: String) async throws -> ProviderNetwork {
        let url = URL(string: "\(baseURL)/api/v1/plans/\(planId)/providers")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.marketplaceAPIKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "zip_code", value: zipCode)]
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketplaceError.providerNetworkFailed
        }
        
        return try JSONDecoder().decode(ProviderNetwork.self, from: data)
    }
    
    // MARK: - Enrollment
    func checkEnrollmentEligibility(
        state: String,
        householdSize: Int,
        householdIncome: Double,
        citizenshipStatus: String = "citizen"
    ) async throws -> EnrollmentEligibility {
        let url = URL(string: "\(baseURL)/api/v1/enrollment/eligibility")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(CenturiesMutualConfig.shared.marketplaceAPIKey)", forHTTPHeaderField: "Authorization")
        
        let eligibilityRequest = EnrollmentEligibilityRequest(
            state: state,
            householdSize: householdSize,
            householdIncome: householdIncome,
            citizenshipStatus: citizenshipStatus
        )
        
        request.httpBody = try JSONEncoder().encode(eligibilityRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketplaceError.enrollmentEligibilityFailed
        }
        
        return try JSONDecoder().decode(EnrollmentEligibility.self, from: data)
    }
    
    // MARK: - State and County Data
    func getStates() async throws -> [State] {
        let url = URL(string: "\(baseURL)/api/v1/states")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.marketplaceAPIKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketplaceError.statesFetchFailed
        }
        
        let statesResponse = try JSONDecoder().decode(StatesResponse.self, from: data)
        return statesResponse.states
    }
    
    func getCounties(state: String) async throws -> [County] {
        let url = URL(string: "\(baseURL)/api/v1/states/\(state)/counties")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.marketplaceAPIKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketplaceError.countiesFetchFailed
        }
        
        let countiesResponse = try JSONDecoder().decode(CountiesResponse.self, from: data)
        return countiesResponse.counties
    }
    
    // MARK: - Open Enrollment Period
    func getOpenEnrollmentPeriod(state: String) async throws -> OpenEnrollmentPeriod {
        let url = URL(string: "\(baseURL)/api/v1/enrollment/period")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(CenturiesMutualConfig.shared.marketplaceAPIKey)", forHTTPHeaderField: "Authorization")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "state", value: state)]
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketplaceError.enrollmentPeriodFailed
        }
        
        return try JSONDecoder().decode(OpenEnrollmentPeriod.self, from: data)
    }
}

// MARK: - Supporting Types
struct MarketplaceSearchRequest: Codable {
    let state: String
    let county: String
    let householdSize: Int
    let householdIncome: Double
    let age: Int
    let tobaccoUser: Bool
}

struct MarketplaceSearchResponse: Codable {
    let plans: [MarketplacePlan]
    let totalCount: Int
    let searchCriteria: SearchCriteria
    
    enum CodingKeys: String, CodingKey {
        case plans
        case totalCount = "total_count"
        case searchCriteria = "search_criteria"
    }
}

struct SearchCriteria: Codable {
    let state: String
    let county: String
    let householdSize: Int
    let householdIncome: Double
    let age: Int
    let tobaccoUser: Bool
}

struct MarketplacePlan: Codable, Identifiable {
    let id: String
    let name: String
    let issuer: String
    let metalLevel: MetalLevel
    let premium: Double
    let deductible: Double
    let outOfPocketMaximum: Double
    let copay: Double?
    let coinsurance: Double?
    let networkType: NetworkType
    let planType: PlanType
    let benefits: [PlanBenefit]
    let formulary: [FormularyDrug]?
    let rating: PlanRating?
    
    enum CodingKeys: String, CodingKey {
        case id, name, issuer
        case metalLevel = "metal_level"
        case premium, deductible
        case outOfPocketMaximum = "out_of_pocket_maximum"
        case copay, coinsurance
        case networkType = "network_type"
        case planType = "plan_type"
        case benefits, formulary, rating
    }
}

enum MetalLevel: String, Codable, CaseIterable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    case platinum = "Platinum"
    case catastrophic = "Catastrophic"
}

enum NetworkType: String, Codable {
    case hmo = "HMO"
    case ppo = "PPO"
    case epo = "EPO"
    case pos = "POS"
}

enum PlanType: String, Codable {
    case individual = "Individual"
    case family = "Family"
    case childOnly = "Child Only"
}

struct PlanBenefit: Codable {
    let category: String
    let name: String
    let covered: Bool
    let copay: Double?
    let coinsurance: Double?
    let deductible: Double?
}

struct FormularyDrug: Codable {
    let name: String
    let tier: Int
    let copay: Double?
    let coinsurance: Double?
    let priorAuthorization: Bool
    let stepTherapy: Bool
    
    enum CodingKeys: String, CodingKey {
        case name, tier, copay, coinsurance
        case priorAuthorization = "prior_authorization"
        case stepTherapy = "step_therapy"
    }
}

struct PlanRating: Codable {
    let overall: Double
    let medicalCare: Double
    let memberExperience: Double
    let planAdministration: Double
    
    enum CodingKeys: String, CodingKey {
        case overall
        case medicalCare = "medical_care"
        case memberExperience = "member_experience"
        case planAdministration = "plan_administration"
    }
}

struct SubsidizedPlan: Codable, Identifiable {
    let id: String
    let plan: MarketplacePlan
    let originalPremium: Double
    let subsidizedPremium: Double
    let premiumTaxCredit: Double
    let costSharingReduction: Double?
    let totalEstimatedCost: Double
    let savings: Double
    
    init(plan: MarketplacePlan, originalPremium: Double, subsidizedPremium: Double, premiumTaxCredit: Double, costSharingReduction: Double?, totalEstimatedCost: Double, savings: Double) {
        self.id = plan.id
        self.plan = plan
        self.originalPremium = originalPremium
        self.subsidizedPremium = subsidizedPremium
        self.premiumTaxCredit = premiumTaxCredit
        self.costSharingReduction = costSharingReduction
        self.totalEstimatedCost = totalEstimatedCost
        self.savings = savings
    }
}

struct SubsidyCalculationRequest: Codable {
    let state: String
    let county: String
    let householdSize: Int
    let householdIncome: Double
    let age: Int
    let taxYear: Int
}

struct SubsidyEligibility: Codable {
    let eligible: Bool
    let premiumTaxCredit: Double
    let costSharingReduction: Double?
    let federalPovertyLevel: Double
    let incomePercentage: Double
    let maxPremiumContribution: Double
    let eligibilityReason: String?
    
    enum CodingKeys: String, CodingKey {
        case eligible
        case premiumTaxCredit = "premium_tax_credit"
        case costSharingReduction = "cost_sharing_reduction"
        case federalPovertyLevel = "federal_poverty_level"
        case incomePercentage = "income_percentage"
        case maxPremiumContribution = "max_premium_contribution"
        case eligibilityReason = "eligibility_reason"
    }
}

struct MarketplacePlanDetails: Codable {
    let plan: MarketplacePlan
    let summaryOfBenefits: String
    let evidenceOfCoverage: String
    let formulary: [FormularyDrug]
    let providerDirectory: String
    let appealsProcess: String
    let grievanceProcess: String
    let languageServices: [String]
    let accessibilityServices: [String]
    
    enum CodingKeys: String, CodingKey {
        case plan
        case summaryOfBenefits = "summary_of_benefits"
        case evidenceOfCoverage = "evidence_of_coverage"
        case formulary
        case providerDirectory = "provider_directory"
        case appealsProcess = "appeals_process"
        case grievanceProcess = "grievance_process"
        case languageServices = "language_services"
        case accessibilityServices = "accessibility_services"
    }
}

struct ProviderNetwork: Codable {
    let planId: String
    let networkName: String
    let providers: [Provider]
    let hospitals: [Hospital]
    let pharmacies: [Pharmacy]
    let networkSize: NetworkSize
    
    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case networkName = "network_name"
        case providers, hospitals, pharmacies
        case networkSize = "network_size"
    }
}

struct Provider: Codable {
    let id: String
    let name: String
    let specialty: String
    let address: Address
    let phone: String?
    let acceptingNewPatients: Bool
    let languages: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, name, specialty, address, phone
        case acceptingNewPatients = "accepting_new_patients"
        case languages
    }
}

struct Hospital: Codable {
    let id: String
    let name: String
    let type: String
    let address: Address
    let phone: String?
    let emergencyServices: Bool
    let rating: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, address, phone
        case emergencyServices = "emergency_services"
        case rating
    }
}

struct Pharmacy: Codable {
    let id: String
    let name: String
    let address: Address
    let phone: String?
    let hours: [String]
    let deliveryAvailable: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, address, phone, hours
        case deliveryAvailable = "delivery_available"
    }
}

struct Address: Codable {
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

struct NetworkSize: Codable {
    let totalProviders: Int
    let totalHospitals: Int
    let totalPharmacies: Int
    let coverageArea: String
    
    enum CodingKeys: String, CodingKey {
        case totalProviders = "total_providers"
        case totalHospitals = "total_hospitals"
        case totalPharmacies = "total_pharmacies"
        case coverageArea = "coverage_area"
    }
}

struct EnrollmentEligibilityRequest: Codable {
    let state: String
    let householdSize: Int
    let householdIncome: Double
    let citizenshipStatus: String
}

struct EnrollmentEligibility: Codable {
    let eligible: Bool
    let reason: String?
    let specialEnrollmentPeriod: Bool
    let openEnrollmentActive: Bool
    let enrollmentDeadline: String?
    let requiredDocuments: [String]
    
    enum CodingKeys: String, CodingKey {
        case eligible, reason
        case specialEnrollmentPeriod = "special_enrollment_period"
        case openEnrollmentActive = "open_enrollment_active"
        case enrollmentDeadline = "enrollment_deadline"
        case requiredDocuments = "required_documents"
    }
}

struct State: Codable, Identifiable {
    let id: String
    let name: String
    let code: String
    let marketplaceType: String
    let website: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, code
        case marketplaceType = "marketplace_type"
        case website
    }
}

struct County: Codable, Identifiable {
    let id: String
    let name: String
    let state: String
    let fipsCode: String
    let population: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, state
        case fipsCode = "fips_code"
        case population
    }
}

struct StatesResponse: Codable {
    let states: [State]
}

struct CountiesResponse: Codable {
    let counties: [County]
}

struct OpenEnrollmentPeriod: Codable {
    let state: String
    let startDate: String
    let endDate: String
    let isActive: Bool
    let specialEnrollmentPeriods: [SpecialEnrollmentPeriod]
    
    enum CodingKeys: String, CodingKey {
        case state
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case specialEnrollmentPeriods = "special_enrollment_periods"
    }
}

struct SpecialEnrollmentPeriod: Codable {
    let reason: String
    let startDate: String
    let endDate: String
    let documentationRequired: [String]
    
    enum CodingKeys: String, CodingKey {
        case reason
        case startDate = "start_date"
        case endDate = "end_date"
        case documentationRequired = "documentation_required"
    }
}

enum MarketplaceError: Error, LocalizedError {
    case searchFailed
    case subsidyCalculationFailed
    case planDetailsFailed
    case providerNetworkFailed
    case enrollmentEligibilityFailed
    case statesFetchFailed
    case countiesFetchFailed
    case enrollmentPeriodFailed
    case invalidAPIKey
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .searchFailed:
            return "Failed to search for marketplace plans."
        case .subsidyCalculationFailed:
            return "Failed to calculate subsidy eligibility."
        case .planDetailsFailed:
            return "Failed to fetch plan details."
        case .providerNetworkFailed:
            return "Failed to fetch provider network information."
        case .enrollmentEligibilityFailed:
            return "Failed to check enrollment eligibility."
        case .statesFetchFailed:
            return "Failed to fetch available states."
        case .countiesFetchFailed:
            return "Failed to fetch counties for the selected state."
        case .enrollmentPeriodFailed:
            return "Failed to fetch enrollment period information."
        case .invalidAPIKey:
            return "Invalid API key for marketplace services."
        case .networkError:
            return "Network error occurred while accessing marketplace data."
        }
    }
}
