# Ad Networks Integration Guide

This document provides a comprehensive overview of all ad network integrations implemented in the Centuries Mutual iOS app.

## Overview

The app now supports **9 different ad networks** with a unified placement system:

### Radio View Ad Networks
- **AppLovin** - Primary monetization platform
- **AdSense** - Google's advertising platform

### Inbox Ad Networks
- **IronSource** - Mobile advertising platform
- **Magnite** - Programmatic advertising
- **Outbrain** - Content discovery platform
- **Qualtrics** - Survey-based ads
- **Survey Monkey** - Survey-based ads
- **Taboola** - Content recommendation platform
- **Typeform** - Form-based ads

## Architecture

### Unified Ad Placement Manager
The `AdPlacementManager` class provides a centralized interface for managing all ad networks:

```swift
// Initialize all networks
try await AdPlacementManager.shared.initializeAllNetworks()

// Load ads for specific placements
try await AdPlacementManager.shared.loadInboxAds()
try await AdPlacementManager.shared.loadRadioAds()

// Show ads
try await AdPlacementManager.shared.showInboxAd(networkType: .ironSource, adType: .interstitial)
try await AdPlacementManager.shared.showRadioAd(networkType: .appLovin, adType: .banner)
```

### Network-Specific Managers
Each ad network has its own dedicated manager class:

- `AppLovinManager` - AppLovin integration
- `IronSourceAPIManager` - IronSource integration
- `MagniteAPIManager` - Magnite integration
- `OutbrainAPIManager` - Outbrain integration
- `QualtricsAPIManager` - Qualtrics integration
- `SurveyMonkeyAPIManager` - Survey Monkey integration
- `TaboolaAPIManager` - Taboola integration
- `TypeformAPIManager` - Typeform integration
- `AdSenseAPIManager` - AdSense integration

## Configuration

All API keys and configuration are managed in `CenturiesMutualConfig.swift`:

```swift
// AppLovin
static let appLovinSDKKey = "YOUR_APPLOVIN_SDK_KEY"

// IronSource
static let ironSourceAppKey = "YOUR_IRONSOURCE_APP_KEY"

// Magnite
static let magniteAPIKey = "YOUR_MAGNITE_API_KEY"

// Outbrain
static let outbrainAPIKey = "YOUR_OUTBRAIN_API_KEY"

// Qualtrics
static let qualtricsAPIKey = "YOUR_QUALTRICS_API_KEY"

// Survey Monkey
static let surveyMonkeyAPIKey = "YOUR_SURVEYMONKEY_API_KEY"

// Taboola
static let taboolaAPIKey = "YOUR_TABOOLA_API_KEY"

// Typeform
static let typeformAPIKey = "YOUR_TYPEFORM_API_KEY"

// AdSense
static let adSenseAPIKey = "YOUR_ADSENSE_API_KEY"
```

## Ad Types Supported

### Traditional Ad Types
- **Banner Ads** - Display ads at top/bottom of screens
- **Interstitial Ads** - Full-screen ads between content
- **Rewarded Ads** - Video ads that reward users
- **Native Ads** - Ads that match app's design

### Specialized Ad Types
- **Survey Ads** (Qualtrics, Survey Monkey) - Interactive surveys
- **Form Ads** (Typeform) - Interactive forms
- **Content Discovery** (Outbrain, Taboola) - Content recommendations

## Revenue Tracking

All ad networks include comprehensive revenue tracking:

```swift
// Track revenue for any network
AdPlacementManager.shared.trackRevenue(
    networkType: .appLovin,
    adUnitId: "banner_ad_unit",
    revenue: 0.01,
    currency: "USD"
)

// Get analytics
let analytics = try await AdPlacementManager.shared.getAnalytics()
```

## Reward System

Users earn rewards for engaging with ads:

### Reward Amounts by Network
- **AppLovin**: $0.01 - $0.005 per ad
- **IronSource**: $0.01 - $0.02 per ad
- **Magnite**: $0.01 - $0.005 per ad
- **Outbrain**: $0.01 - $0.005 per ad
- **Qualtrics**: $0.05 per survey
- **Survey Monkey**: $0.05 per survey
- **Taboola**: $0.01 - $0.005 per ad
- **Typeform**: $0.05 per form
- **AdSense**: $0.01 - $0.03 per ad

## Placement Strategy

### Radio View
- **Primary**: AppLovin (banner, interstitial, rewarded)
- **Secondary**: AdSense (banner, interstitial, rewarded)
- **Purpose**: Monetize radio streaming feature

### Inbox View
- **Primary**: IronSource, Magnite, Outbrain, Taboola (traditional ads)
- **Secondary**: Qualtrics, Survey Monkey, Typeform (interactive content)
- **Purpose**: Monetize messaging and communication features

## User Experience

### Privacy Compliance
- GDPR and CCPA compliant
- User consent management
- Age-restricted user handling
- Do Not Sell (DNT) support

### User Targeting
- User ID management
- Interest-based targeting
- Keyword targeting
- Demographic targeting

### Error Handling
- Comprehensive error handling for all networks
- Fallback mechanisms
- User-friendly error messages
- Network failure recovery

## Implementation Examples

### Loading Inbox Ads
```swift
// Load all inbox ad networks
try await AdPlacementManager.shared.loadInboxAds()

// Show specific ad
try await AdPlacementManager.shared.showInboxAd(
    networkType: .ironSource,
    adType: .interstitial
)
```

### Loading Radio Ads
```swift
// Load radio ad networks
try await AdPlacementManager.shared.loadRadioAds()

// Show banner ad in radio view
try await AdPlacementManager.shared.showRadioAd(
    networkType: .appLovin,
    adType: .banner
)
```

### Revenue Tracking
```swift
// Track revenue from any network
AdPlacementManager.shared.trackRevenue(
    networkType: .adSense,
    adUnitId: "radio_banner",
    revenue: 0.02,
    currency: "USD"
)
```

## Analytics and Reporting

### Network Analytics
Each network provides detailed analytics:
- Revenue per ad unit
- Impression counts
- Click-through rates (CTR)
- Revenue per mille (RPM)
- User engagement metrics

### Unified Analytics
The `AdPlacementManager` aggregates analytics from all networks:
- Total revenue across all networks
- Performance comparison between networks
- Placement effectiveness analysis
- User engagement patterns

## Best Practices

### Ad Loading
1. Initialize all networks at app startup
2. Preload ads for better user experience
3. Implement fallback mechanisms
4. Monitor ad load success rates

### Revenue Optimization
1. A/B test different ad placements
2. Monitor revenue per network
3. Optimize ad frequency
4. Balance user experience with monetization

### User Experience
1. Respect user privacy preferences
2. Provide clear reward information
3. Implement smooth ad transitions
4. Handle network failures gracefully

## Troubleshooting

### Common Issues
1. **Ad Not Loading**: Check API keys and network connectivity
2. **Revenue Not Tracking**: Verify backend integration
3. **User Consent Issues**: Ensure proper consent flow
4. **Network Failures**: Implement fallback mechanisms

### Debug Information
All managers provide detailed logging for debugging:
- Ad load status
- Revenue tracking
- User interactions
- Error messages

## Future Enhancements

### Planned Features
1. **Real-time Bidding**: Implement header bidding
2. **Advanced Targeting**: Machine learning-based targeting
3. **Cross-platform Sync**: Sync ads across iOS and web
4. **Performance Optimization**: AI-driven ad optimization

### Integration Opportunities
1. **Additional Networks**: Support for more ad networks
2. **Video Ads**: Enhanced video ad support
3. **AR/VR Ads**: Immersive advertising experiences
4. **Blockchain Integration**: Cryptocurrency-based rewards

## Support and Documentation

### API Documentation
Each ad network manager includes comprehensive documentation:
- Method signatures
- Parameter descriptions
- Return value explanations
- Usage examples

### Error Handling
All managers implement consistent error handling:
- Network-specific error types
- Localized error messages
- Recovery suggestions
- Debug information

## Conclusion

The ad network integration provides a comprehensive monetization solution for the Centuries Mutual iOS app. With support for 9 different ad networks, unified placement management, and comprehensive revenue tracking, the app is well-positioned for successful monetization while maintaining a positive user experience.

The modular architecture allows for easy addition of new ad networks and provides flexibility in ad placement strategies. The reward system encourages user engagement while the privacy-compliant implementation ensures user trust and regulatory compliance.
