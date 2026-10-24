# CardLah! - iOS Wallet Transaction Tracker

A modern iOS app built with SwiftUI, SwiftData, and App Intents that helps users automatically track Apple Wallet transactions and monitor credit card spending goals.

App Store download link: https://apps.apple.com/sg/app/cardpulse-spending-tracker/id6754640005 

## Screenshots

<p align="center">
  <img src="appstore/appstore_screenshots/iPhone%206.3in%20(1206x2622)/1-today.png" width="19%" alt="Today: min-spend progress across cards and recent Wallet taps" />
  <img src="appstore/appstore_screenshots/iPhone%206.3in%20(1206x2622)/2-cards.png" width="19%" alt="Cards: minimum-spend goals per card" />
  <img src="appstore/appstore_screenshots/iPhone%206.3in%20(1206x2622)/3-recap.png" width="19%" alt="Recap: spending by period and category, with rewards earned" />
  <img src="appstore/appstore_screenshots/iPhone%206.3in%20(1206x2622)/4-me.png" width="19%" alt="Me: streaks, badges and settings" />
  <img src="appstore/appstore_screenshots/iPhone%206.3in%20(1206x2622)/5-today-dark.png" width="19%" alt="Today tab in dark mode" />
</p>

## Features

### 🏠 Today
- Mascot nudges with how much each card still needs this cycle
- Day streak, weekly flame strip and targets-hit trophy count
- Min-spend progress across all cards with a target
- Latest Wallet taps, with a "View all" list and inline editing

### 💳 Cards
- Minimum-spend goal per card, cycled from its statement day (1–31)
- Status filter chips and progress tiles; cards without a target listed separately
- Reward tracking (miles or cashback), including category and per-cycle caps
- Minimum-spend history grid: met / missed badges for the last 12 cycles

### 📊 Recap
- Day / Week / Month / Year and custom ranges, filtered by one or more cards
- Total spend with change versus the previous period, and rewards earned
- "Where it went" category breakdown and spending-over-time chart
- Map of where you spent, and a shareable recap image

### 👤 Me
- Profile stats, monthly activity calendar and badges
- Light / Dark / System appearance and mascot colour (with matching app icon)
- Spending categories (built-in plus your own), currencies and reminder lead time
- CSV import/export

### ⚡ Automation and more
- Apple Wallet taps logged automatically through a Shortcuts automation (App Intent)
- Category guessed from merchant history, an optional remote lookup, then keyword rules
- Multi-currency: amounts parsed from Wallet strings, rewards computed in your default currency
- Home-screen widget mirroring the min-spend card
- Local notifications before a statement date and when a reward cap is reached

### 📦 CSV Import/Export
- Header: `Merchant,Amount,Currency,Category,Card,Date,Note,Latitude,Longitude,PlaceName`
- Date format `yyyy-MM-dd HH:mm:ss`; `Amount` may carry a currency prefix such as `S$12.50`
- Export: choose a date range, preview, then save via the native file picker
- Import: preview before saving; quoted fields with commas are supported

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

### Category auto-tagging (optional)

When a Wallet transaction is logged, the app works out its spending category in three steps:
past transactions from the same merchant, then a remote lookup, then local keyword rules.

The remote lookup is served by the small Next.js API in [`backend/`](backend/README.md), which
asks [TypeSafe Jev](https://docs.typesafe.ai) to choose among *your* categories — custom ones
included. It lives on a server because the model API key must never ship inside an app binary.

**The app builds and runs without it.** With no configuration, step 2 is skipped and
categories come from history plus the keyword heuristic, exactly as before.

To enable it:

1. Deploy `backend/` (see its README) and note the host.
2. Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` and fill in:
   ```
   CATEGORY_API_BASE_URL = your-deployment.vercel.app
   CATEGORY_API_TOKEN = <same value as CATEGORIZE_API_TOKEN on the server>
   ```
   Use the **host only** — xcconfig treats `//` as a comment, so a full `https://` URL would be
   truncated. The app adds the scheme itself.
3. Rebuild.

`Config/Secrets.xcconfig` is gitignored and must never be committed. On Xcode Cloud it is
regenerated by `ci_scripts/ci_post_clone.sh` from the `CATEGORY_API_BASE_URL` and
`CATEGORY_API_TOKEN` environment variables.

## Design System

The look follows the "CardLah Fun" design: a cream background (navy in dark mode), white "chunky"
cards with a thick bottom edge, a blue `#2E6DFF` accent, Fredoka and Nunito fonts, and a card
mascot. All colours and fonts live in `CardPulse/Theme/` (`AppColors`, `AppTypography`,
`ViewModifiers`, `Mascot`).

## Future Enhancements

- Apple Watch companion app
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
