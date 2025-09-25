import SwiftUI

// MARK: - Golden Branch Color Scheme
// Inspired by the beautiful golden branch on forest green background
extension Color {
    
    // MARK: - Primary Colors (Golden Branch Theme)
    
    /// Rich golden color from the branch - primary brand color
    static let goldenBranch = Color(red: 0.83, green: 0.69, blue: 0.22)
    
    /// Deep forest green background - main background color
    static let forestGreen = Color(red: 0.11, green: 0.30, blue: 0.24)
    
    /// Darker forest green for gradients and depth
    static let darkForestGreen = Color(red: 0.08, green: 0.22, blue: 0.18)
    
    /// Light golden accent for highlights and secondary elements
    static let lightGolden = Color(red: 0.96, green: 0.89, blue: 0.74)
    
    /// Medium golden for text and important elements
    static let mediumGolden = Color(red: 0.72, green: 0.58, blue: 0.18)
    
    // MARK: - Semantic Colors
    
    /// Primary button background
    static let primaryButton = goldenBranch
    
    /// Primary button text
    static let primaryButtonText = forestGreen
    
    /// Secondary button background
    static let secondaryButton = lightGolden
    
    /// Secondary button text
    static let secondaryButtonText = forestGreen
    
    /// Card background
    static let cardBackground = forestGreen
    
    /// Text on dark backgrounds
    static let textOnDark = lightGolden
    
    /// Text on light backgrounds
    static let textOnLight = forestGreen
    
    /// Border color
    static let borderColor = lightGolden.opacity(0.4)
    
    /// Progress indicator active
    static let progressActive = goldenBranch
    
    /// Progress indicator inactive
    static let progressInactive = Color.gray.opacity(0.3)
    
    // MARK: - Gradient Definitions
    
    /// Main background gradient
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [forestGreen, darkForestGreen]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Golden accent gradient
    static let goldenGradient = LinearGradient(
        gradient: Gradient(colors: [goldenBranch, mediumGolden]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - View Modifiers for Consistent Styling
extension View {
    
    /// Apply the golden branch background gradient
    func goldenBranchBackground() -> some View {
        self.background(Color.backgroundGradient)
    }
    
    /// Apply primary button styling
    func primaryButtonStyle() -> some View {
        self
            .foregroundColor(.primaryButtonText)
            .background(Color.primaryButton)
            .cornerRadius(12)
    }
    
    /// Apply secondary button styling
    func secondaryButtonStyle() -> some View {
        self
            .foregroundColor(.secondaryButtonText)
            .background(Color.secondaryButton)
            .cornerRadius(12)
    }
    
    /// Apply card styling with golden branch theme
    func goldenBranchCard() -> some View {
        self
            .background(Color.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.borderColor, lineWidth: 1)
            )
    }
    
    /// Apply text styling for dark backgrounds
    func textOnDarkStyle() -> some View {
        self.foregroundColor(.textOnDark)
    }
    
    /// Apply text styling for light backgrounds
    func textOnLightStyle() -> some View {
        self.foregroundColor(.textOnLight)
    }
}
