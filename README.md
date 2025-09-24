# Centuries Mutual iOS App

A comprehensive iOS application for Centuries Mutual insurance services, featuring advanced financial management, healthcare marketplace integration, radio streaming, insurance enrollment, and enterprise-grade authentication.

## Features

### 🏠 Home Dashboard
- Welcome screen with company branding
- Quick access to all services
- Real-time statistics display
- YouTube-powered radio feature integration

### 💼 Services
- **Tax Preparation**: Expert tax services and planning
- **Health Insurance**: Comprehensive health coverage options with marketplace integration
- **Life Insurance**: Family protection and legacy planning
- **Medicare Plans**: CMS Medicare API integration for senior coverage
- Detailed service information and enrollment

### 💳 Digital Wallet
- **Circle API Integration**: Secure financial transactions
- **Multi-Balance Support**: Evergreen, Steps, and Ad Revenue balances
- **Financial Health Tracking**: Score-based progress monitoring
- **Transaction History**: Complete earnings and spending records
- **Quick Actions**: Cash out, transfer, and redeem options

### 📻 Radio Feature
- **YouTube API Integration**: Advanced radio and video content control
- **Location-Based Streaming**: Automatically finds nearby public radio stations
- **Background Playback**: Continues playing when app is backgrounded
- **Lock Screen Controls**: Full media control integration
- **Content Management**: Admin controls for radio and video content

### 📋 Insurance Enrollment
- **Multi-Step Process**: Guided enrollment with progress tracking
- **Marketplace Integration**: Healthcare.gov subsidized plan finder
- **Plan Selection**: Compare different insurance options
- **Document Upload**: Secure file management with Dropbox Advanced integration
- **Personal Information**: Comprehensive data collection
- **Review & Submit**: Final confirmation before submission

### 💬 Messaging System
- **Thread-Based Communication**: Organized conversation management
- **Real-Time Updates**: Instant message delivery
- **File Attachments**: Document sharing capabilities
- **Agent Communication**: Direct contact with insurance agents

### 🔒 Security & Data Management
- **Keycloak Authentication**: Enterprise-grade user authentication
- **SQLite Database**: Local data storage and caching
- **Dropbox Advanced Integration**: Enterprise cloud document synchronization
- **Keychain Security**: Secure credential storage
- **Encrypted Communications**: End-to-end data protection

### 💰 Monetization
- **AppLovin Integration**: Banner, interstitial, and rewarded ads
- **Revenue Tracking**: Comprehensive ad revenue analytics
- **Reward System**: User rewards for ad engagement
- **Privacy Compliance**: GDPR and CCPA compliant ad targeting

## Technical Architecture

### Core Technologies
- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming for data flow
- **Core Location**: GPS-based radio station detection
- **AVFoundation**: Audio streaming and playback
- **SQLite3**: Local database management
- **CryptoKit**: Encryption and security

### API Integrations
- **Circle API**: Financial services and wallet management
- **Keycloak**: Enterprise authentication and user management
- **Dropbox Advanced API**: Enterprise document storage and collaboration
- **Healthcare.gov API**: Marketplace plan finder with subsidies
- **CMS Medicare API**: Medicare plan data and provider information
- **YouTube API**: Content management for radio and video features
- **AppLovin**: Ad monetization and revenue tracking
- **Linode**: Cloud hosting and infrastructure management

### Design System
- **Color Scheme**: Matches website branding (#14432A primary green)
- **Typography**: Playfair Display for headings, system fonts for body
- **Components**: Reusable UI components with consistent styling
- **Navigation**: Tab-based navigation with modal presentations

## Project Structure

```
CenturiesMutual/
├── CenturiesMutualApp.swift              # Main app entry point
├── ContentView.swift                     # Root navigation view
├── LoginView.swift                       # Keycloak authentication screen
├── HomeView.swift                        # Dashboard and overview
├── ServicesView.swift                    # Service catalog
├── WalletView.swift                      # Digital wallet interface
├── RadioView.swift                       # YouTube-powered radio streaming
├── EnrollmentView.swift                  # Insurance enrollment flow
├── MessagesView.swift                    # Messaging system
├── RadioComponents.swift                 # Radio-related components
├── CenturiesMutualConfig.swift           # Comprehensive app configuration
├── CircleAPIService.swift                # Financial API integration
├── KeycloakAuthManager.swift             # Enterprise authentication
├── DropboxAdvancedManager.swift          # Advanced cloud storage
├── MarketplaceFinderAPI.swift            # Healthcare marketplace integration
├── CMSMedicareAPI.swift                  # Medicare data integration
├── YouTubeAPIManager.swift               # YouTube content management
├── AppLovinManager.swift                 # Ad monetization
├── LinodeHostingConfig.swift             # Cloud hosting management
├── SQLManager.swift                      # Database management
├── DropboxManager.swift                  # Legacy cloud storage
└── Info.plist                           # App permissions and settings
```

## Setup Instructions

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later
- Swift 5.9 or later
- Linode hosting account
- Keycloak server instance

### Configuration
1. **API Keys**: Update `CenturiesMutualConfig.swift` with your API keys:
   - Circle API keys for financial services
   - Keycloak configuration for authentication
   - Dropbox Advanced API credentials
   - Healthcare.gov API key
   - CMS Medicare API key
   - YouTube API key
   - AppLovin SDK key
   - Linode hosting credentials

2. **Permissions**: The app requires the following permissions:
   - Location access for radio feature
   - Camera access for document upload
   - Photo library access for document selection
   - Microphone access for voice messages
   - Background audio for radio playback

3. **URL Schemes**: Configure external integrations:
   - Coinbase: `centuriesmutual://coinbase-auth`
   - Robinhood: `centuriesmutual://robinhood-auth`
   - Keycloak: `centuriesmutual://keycloak-auth`
   - Dropbox: `centuriesmutual://dropbox-auth`

### Installation
1. Clone the repository
2. Open `CenturiesMutual.xcodeproj` in Xcode
3. Configure your development team and bundle identifier
4. Update all API keys in the configuration file
5. Build and run on simulator or device

## Key Features Implementation

### Enterprise Authentication
- Keycloak integration for enterprise-grade security
- Role-based access control
- Single sign-on (SSO) capabilities
- User profile and password management
- Session management and token refresh

### Healthcare Marketplace Integration
- Healthcare.gov API for subsidized individual plans
- Real-time subsidy eligibility calculation
- Provider network information
- Enrollment eligibility checking
- State and county data management

### Medicare Integration
- CMS Medicare API for comprehensive Medicare data
- Medicare Advantage and Part D plan information
- Provider directories and quality ratings
- Cost data and beneficiary eligibility
- Claims data access and analytics

### YouTube Content Management
- YouTube API for radio and video content control
- Video search and playlist management
- Content upload and metadata management
- Analytics and reporting
- Audio streaming for radio feature

### Advanced Cloud Storage
- Dropbox Advanced API for enterprise features
- Team collaboration and sharing
- Enhanced search and metadata
- Version control and permissions
- Enterprise security features

### Ad Monetization
- AppLovin integration for comprehensive ad management
- Banner, interstitial, and rewarded ads
- Native ad integration
- Revenue tracking and analytics
- User targeting and reward system

### Cloud Infrastructure
- Linode hosting for scalable cloud infrastructure
- Server monitoring and deployment management
- Database backup and restore capabilities
- SSL certificate management
- Environment variable management

### Radio Feature
- YouTube API integration for content management
- Location-based station detection
- Background audio playback
- Lock screen controls
- Admin content management capabilities

### Wallet Integration
- Circle API integration for secure financial transactions
- Multi-currency support with real-time balance updates
- Interest calculation on idle funds (4.5% APY)
- Risk management with transaction limits
- External wallet connections (Coinbase, Robinhood)

### Database Management
- SQLite3 for local data persistence
- Automatic synchronization with cloud storage
- Comprehensive data models for all features
- Transaction logging and audit trails
- Ad revenue tracking

### Security Features
- Keycloak enterprise authentication
- Keychain storage for sensitive credentials
- Encrypted API communications
- Secure document upload and sharing
- Privacy compliance (GDPR, CCPA)

## Customization

### Branding
- Update colors in `CenturiesMutualConfig.swift`
- Modify logo assets in the project bundle
- Customize typography and spacing in view files

### Features
- Enable/disable specific features through configuration
- Add new insurance plan types
- Extend radio station database
- Customize earning rates and limits
- Configure ad placement and rewards

### API Integration
- Replace mock data with real API endpoints
- Add additional financial service providers
- Implement webhook handlers for real-time updates
- Configure enterprise authentication settings

## Testing

The app includes comprehensive error handling and user feedback:
- Network connectivity checks
- Location permission handling
- File upload progress indicators
- Transaction status updates
- Error recovery mechanisms
- API failure handling
- Authentication flow testing

## Deployment

### Linode Cloud Infrastructure
- Automated deployment pipelines
- Server monitoring and health checks
- Database backup and restore
- SSL certificate management
- Environment variable management
- Log monitoring and analytics

### App Store Requirements
- Complete all required app metadata
- Provide privacy policy and terms of service
- Submit for App Store review
- Configure production API endpoints
- Implement enterprise authentication

### Enterprise Distribution
- Configure enterprise certificates
- Set up internal distribution channels
- Implement device management policies
- Configure Keycloak for enterprise SSO

## Support

For technical support or feature requests, please contact the development team or refer to the project documentation.

## License

This project is proprietary software developed for Centuries Mutual. All rights reserved.

---

**Version**: 2.0  
**Last Updated**: January 2024  
**Minimum iOS Version**: 17.0  
**Target Devices**: iPhone, iPad  
**Hosting**: Linode Cloud Infrastructure  
**Authentication**: Keycloak Enterprise