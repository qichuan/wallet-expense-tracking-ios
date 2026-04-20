# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CardPulse** is an iOS app (iOS 17.0+, Xcode 15.0+, Swift 5.9+) for tracking Apple Wallet transactions and monitoring credit card spending goals. The app is built with SwiftUI, SwiftData, App Intents, Firebase Analytics, and Apple Charts.

## Build & Development Commands

All development is done via Xcode. There is no CLI build system (no Makefile, SPM package, or fastlane).

```bash
# Build from command line (scheme name is "TapTrack")
xcodebuild -project CardPulse.xcodeproj -scheme TapTrack -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -project CardPulse.xcodeproj -scheme TapTrack -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test class
xcodebuild -project CardPulse.xcodeproj -scheme TapTrack -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CardPulseTests/MyTestClass test
```

For day-to-day development, open `CardPulse.xcodeproj` in Xcode and run/test from there.

## Architecture

### Data Layer
- **Models** (`CardPulse/Models/`): `Card` and `Transaction` are `@Model` classes for SwiftData. `Card` has a cascade-delete relationship to `Transaction` via `@Relationship`. `Transaction` now has a `currency: String` field (added in schema V2).
- **CardPulseMigration** (`Models/CardPulseMigration.swift`): `CardPulseMigrationPlan` defines the V1→V2 lightweight migration that backfills `currency` on existing transactions using the user's stored default currency. `SchemaV1` / `SchemaV2` are the versioned schema definitions.
- **CardUtils** (`Utils/CardUtils.swift`): `Card` extension with computed properties for billing cycle logic — `currentCycleStart`, `currentCycleEnd`, `monthlySpent`, `progressPercentage`, `daysRemaining`, `spendingPeriodDisplay`. Cycle boundaries are derived from `minimumSpendingByDayOfMonth` (statement day).
- **TransactionManager** (`TransactionManager.swift`): `@MainActor ObservableObject` wrapping `ModelContext` for CRUD operations and CSV import/export. Injected via SwiftUI environment.
- **MockData** (`Models/MockData.swift`): `ModelContainer.createMockContainer()` creates an in-memory container for SwiftUI `#Preview` blocks.

### App Entry Point
`CardPulseApp.swift` initializes `ModelContainer` using `CardPulseMigrationPlan` (V1→V2 migration), registers Firebase via `AppDelegate`, calls `CurrencyUtils.ensureDefaultCurrenciesEnabled()` on launch, and injects the container into `MainTabView`. On first launch (no default currency chosen), it presents `CurrencyOnboardingView` instead of `MainTabView`.

### Navigation
`MainTabView` hosts four tabs: **Home** (tag 0), **Analysis** (tag 1), **Cards** (tag 2), **Settings** (tag 3). The app always uses `.preferredColorScheme(.dark)`.

### Views Structure
```
Views/
  MainTabView.swift
  AnalysisView.swift        # Charts: donut by category, stacked bar over time
  Home/
    HomeView.swift          # Latest 10 transactions, shortcut banner
    NotificationBanner.swift
    ShortcutsBanner.swift
  Card/
    CardsView.swift
    CardFormView.swift
    CardRow.swift
    HowToAutoTrackingView.swift
  Transaction/
    AllTransactionsView.swift
    TransactionFormView.swift
    TransactionRow.swift    # Reusable row used app-wide
    FilterSheetView.swift
  CurrencyOnboardingView.swift  # First-launch currency picker; backfills existing transactions
  Settings/
    SettingsView.swift
  CSV/
    DocumentPickerView.swift
    ExportOptionsView.swift
    ImportPreviewView.swift
```

### App Intent (Wallet Automation)
`WalletTransactionIntent.swift` implements `AppIntent` for Shortcuts automation. When triggered from Apple Wallet, it creates a `Transaction` by opening its own `ModelContainer` (not the shared one), parses the amount string via `CurrencyUtils.parseCurrencyAndAmount(from:)` to extract currency and amount, guesses category via `NLEmbedding` (with keyword heuristic fallback), logs to Firebase Analytics (`add_wallet_transaction` with `currency` parameter), and fires a `UNUserNotificationCenter` notification.

### Utilities
- **MerchantUtils** (`Utils/MerchantUtils.swift`): Single source of truth for categories (7 canonical values), SF Symbol icons, and SwiftUI `Color` per category. Always use `MerchantUtils.normalizedCategory(for:)` when storing/displaying categories.
- **ImportExportUtils** (`Utils/ImportExportUtils.swift`): CSV parsing helpers (RFC 4180 compliant, handles quoted fields).
- **CurrencyUtils** (`Utils/CurrencyUtils.swift`): Multi-currency support. Holds the built-in currency list (`allCurrencies`, 15 currencies), user-defined custom currencies, enabled/default currency preferences (all in `UserDefaults`), and exchange-rate cache (via [Frankfurter API](https://www.frankfurter.app), 5-day TTL). Key methods: `parseCurrencyAndAmount(from:)` parses raw Wallet strings like `"S$12.50"` or `"MYR 8.00"`; `fetchRates(for:to:)` fetches and inverts rates; `rateToDefault(from:)` returns the cached conversion rate.

## Key Conventions

- **Categories**: The canonical list is defined in `MerchantUtils.defaultCategories`. Unknown categories normalize to `"Other"`. Do not hardcode category strings elsewhere.
- **Billing cycle**: A card's billing cycle runs from `(statement day of previous month + 1)` to `(statement day of current month)`. All cycle math lives in `CardUtils.swift`.
- **Currency**: Every `Transaction` stores a `currency` code (ISO 4217). Always use `CurrencyUtils.parseCurrencyAndAmount(from:)` to extract currency + amount from raw strings. For display, use `CurrencyUtils.symbol(for:)`. Never hardcode currency symbols.
- **CSV format**: `Merchant,Amount,Category,Card,Date,Note` with date format `yyyy-MM-dd HH:mm:ss`. The `Amount` field may include a currency prefix (e.g. `S$12.50`) — `ImportExportUtils` uses `CurrencyUtils.parseCurrencyAndAmount` to parse it.
- **Previews**: All SwiftUI `#Preview` blocks use `.modelContainer(ModelContainer.createMockContainer())` to get in-memory data.
- **Dark mode only**: The app forces dark mode via `MainTabView`'s `.preferredColorScheme(.dark)`.
- **Design tokens**: Primary teal accent (`Color.teal`), dark navy background (`#0D1A33`), gold (`#FFD700`).

## Firebase
`GoogleService-Info.plist` is present but excluded from version control. Analytics events are logged in `WalletTransactionIntent.perform()`. The app uses `FirebaseCore` + `FirebaseAnalytics` packages.
