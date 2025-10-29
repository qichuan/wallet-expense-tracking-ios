# CardPulse - iOS Wallet Transaction Tracker

A modern iOS app built with SwiftUI, SwiftData, and App Intents that helps users automatically track Apple Wallet transactions and monitor credit card spending goals.

## Features

### 🏠 Home
- Latest transactions list (shows up to 10)
- Edit transaction inline (sheet)
- "View All" button at the end of the list

### 💳 Card Management
- Cards screen with floating "+" button (bottom-right)
- Monthly cycle based on Statement Day (1–31)
- Progress for current cycle: $spentThisCycle / $minimumSpending
- Reward tracking (miles, cashback)

### 🎯 Cards (formerly Goals)
- Simplified list of all cards (no Active/Completed tabs)
- Add/Edit Card screens: card info + minimum spending + statement day
- Custom Day-of-Month picker component for Statement Day

### 📊 Analysis
- Day/Week/Month/Year filters with arrow navigation
- Date constraints and smart stepping that skips empty dates
- Month picker (months with data) and Year picker (years with data)
- Spending breakdown by category (donut)
- Spending over time (stacked bar):
  - Week: shows all 7 days, even with zero transactions
  - Month: always shows wk1–wk4, even with zero transactions
- Recent transactions section for Day/Week

### ⚙️ Settings
- CSV import/export (Merchant,Amount,Category,Card,Date,Note)
- Native document picker for export; date-range selection and preview
- Robust CSV import with header-aware parsing and preview
- Wallet/App configuration

### 📦 CSV Import/Export
- Export: choose date range → preview → save via native file picker
- Import: select a CSV (UTF-8) with header `Merchant,Amount,Category,Card,Date,Note`
- iOS file access is handled with security-scoped URLs for real devices
- CSV escaping supported (quotes/commas)

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
- `HomeView` - Latest transactions
- `CardsView` - Card list and actions
- `AnalysisView` - Analytics and charts
- `SettingsView` - App configuration
- `TransactionManager` - Data operations service
- `MerchantUtils` - Centralized category, icon, and color logic
- `TransactionRow` - Standardized transaction list row used across the app
 - `DayOfMonthPicker` - Custom picker for statement day

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
3. Configure Wallet tap automation in Shortcuts app (optional)
4. Import your CSV data via Settings → Import/Export to get started
   - On device: grant access in the file picker when prompted

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

## Project Structure

```
CardPulse/
  Models/                // Card, Transaction, MockData (for previews)
  Views/                 // Home, Cards, Analysis, Settings, Transactions, Components
  Utils/                 // MerchantUtils, helpers
  Services/              // TransactionManager (SwiftData operations)
  Intents/               // WalletTransactionIntent (App Intents)
  Assets.xcassets        // App assets
```