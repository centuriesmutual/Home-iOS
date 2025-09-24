import SwiftUI

struct ServicesView: View {
    @State private var selectedService: Service?
    
    let services = [
        Service(
            title: "Tax Preparation",
            description: "Expert tax preparation services ensuring maximum returns and full compliance.",
            icon: "calculator",
            color: Color(red: 0.08, green: 0.26, blue: 0.16),
            features: [
                "Individual Tax Returns",
                "Business Tax Preparation",
                "Tax Planning & Strategy",
                "IRS Audit Support",
                "Quarterly Tax Estimates"
            ]
        ),
        Service(
            title: "Health Insurance",
            description: "Comprehensive health insurance solutions tailored to your needs.",
            icon: "heart",
            color: Color(red: 0.10, green: 0.33, blue: 0.21),
            features: [
                "Individual Health Plans",
                "Family Coverage Options",
                "Medicare Supplement Plans",
                "Health Savings Accounts",
                "Prescription Drug Coverage"
            ]
        ),
        Service(
            title: "Life Insurance",
            description: "Protect your family's future with our comprehensive life insurance plans.",
            icon: "shield",
            color: Color(red: 0.12, green: 0.40, blue: 0.26),
            features: [
                "Term Life Insurance",
                "Whole Life Insurance",
                "Universal Life Insurance",
                "Final Expense Insurance",
                "Business Life Insurance"
            ]
        )
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Professional Services")
                            .font(.custom("Playfair Display", size: 32))
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.08, green: 0.26, blue: 0.16))
                            .multilineTextAlignment(.center)
                        
                        Text("Comprehensive financial solutions tailored to your unique needs and goals")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // Services Grid
                    LazyVStack(spacing: 20) {
                        ForEach(services) { service in
                            ServiceCard(service: service) {
                                selectedService = service
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // CTA Section
                    VStack(spacing: 20) {
                        Text("Ready to Get Started?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Schedule a consultation with our experts to discuss your financial needs")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            // Navigate to schedule
                        }) {
                            Text("Schedule Consultation")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(Color(red: 0.08, green: 0.26, blue: 0.16))
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(red: 0.08, green: 0.26, blue: 0.16))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .sheet(item: $selectedService) { service in
            ServiceDetailView(service: service)
        }
    }
}

struct Service: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let features: [String]
}

struct ServiceCard: View {
    let service: Service
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: service.icon)
                        .font(.title)
                        .foregroundColor(service.color)
                        .frame(width: 50, height: 50)
                        .background(service.color.opacity(0.1))
                        .cornerRadius(12)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundColor(service.color)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(service.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(service.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                HStack {
                    Text("Learn More")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(service.color)
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ServiceDetailView: View {
    let service: Service
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: service.icon)
                            .font(.system(size: 60))
                            .foregroundColor(service.color)
                            .frame(width: 100, height: 100)
                            .background(service.color.opacity(0.1))
                            .cornerRadius(20)
                        
                        Text(service.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(service.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What's Included")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            ForEach(service.features, id: \.self) { feature in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(service.color)
                                    
                                    Text(feature)
                                        .font(.body)
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // CTA Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            // Navigate to enrollment or contact
                        }) {
                            Text("Get Started")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(service.color)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            // Navigate to contact
                        }) {
                            Text("Contact Us")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle(service.title)
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

#Preview {
    ServicesView()
}
