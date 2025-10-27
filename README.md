# TapTrack - iOS Wallet Transaction Tracker

A modern iOS app built with SwiftUI, SwiftData, and App Intents that helps users automatically track Apple Wallet transactions and monitor credit card spending goals.

## Features

### 🏠 Dashboard
- Total spending overview with month-over-month comparison
- Credit card goal progress tracking
- Weekly spending trends chart
- Upcoming payment reminders

### 💳 Card Management
- Detailed card views with transaction history
- Circular progress indicators for spending goals
- Reward tracking (miles, cashback, points)
- Goal deadline monitoring

### 🎯 Goals Management
- Active and completed goal tracking
- Progress visualization with progress bars
- Reward type categorization
- Goal creation and editing

### 📊 Analytics & Insights
- Spending breakdown by category
- Interactive donut charts
- Monthly spending trends
- Category-based spending analysis

### ⚙️ Settings
- Auto-sync Wallet toggle
- Data management (CSV import/export)
- Privacy and security settings
- App configuration

## Technical Architecture

### Core Technologies
- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Local data persistence
- **App Intents** - Wallet tap automation integration
- **Charts** - Data visualization
- **Combine** - Reactive programming

### Data Models
- `Card` - Credit card information and goals
- `Transaction` - Individual transaction records
- Relationship-based data structure

### Key Components
- `MainTabView` - Main navigation container
- `DashboardView` - Home screen with overview
- `CardDetailView` - Individual card details
- `GoalsView` - Goal management interface
- `InsightsView` - Analytics and charts
- `SettingsView` - App configuration
- `TransactionManager` - Data operations service

## App Intent Integration

The app includes App Intent support for automatic transaction logging:

```swift
struct WalletTransactionIntent: AppIntent {
    @Parameter(title: "Merchant Name")
    var merchantName: String
    
    @Parameter(title: "Amount")
    var amount: Double
    
    @Parameter(title: "Card Name")
    var cardName: String
    
    // ... implementation
}
```

## Setup Instructions

1. Open the project in Xcode
2. Build and run on iOS 17.0+ device or simulator
3. The app includes mock data for preview purposes
4. Configure Wallet tap automation in Shortcuts app

## Design System

### Color Palette
- Primary: Dark Navy Blue (#0D1A33)
- Accent: Teal (#00D4AA)
- Secondary: Gold/Yellow (#FFD700)
- Text: White with opacity variations

### Typography
- Primary: SF Pro Display
- Weights: Regular, Semibold, Bold
- Hierarchy: Title, Headline, Body, Caption

### UI Components
- Rounded corner cards
- Progress indicators (linear and circular)
- Interactive charts
- Modern iOS navigation patterns

## Future Enhancements

- Push notifications for goal milestones
- Apple Watch companion app
- Widget support for quick overview
- Advanced analytics and insights
- Multi-currency support
- Bank integration APIs

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+