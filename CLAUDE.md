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
- **Models** (`CardPulse/Models/`): `Card` and `Transaction` are `@Model` classes for SwiftData. `Card` has a cascade-delete relationship to `Transaction` via `@Relationship`.
- **CardUtils** (`Utils/CardUtils.swift`): `Card` extension with computed properties for billing cycle logic — `currentCycleStart`, `currentCycleEnd`, `monthlySpent`, `progressPercentage`, `daysRemaining`, `spendingPeriodDisplay`. Cycle boundaries are derived from `minimumSpendingByDayOfMonth` (statement day).
- **TransactionManager** (`TransactionManager.swift`): `@MainActor ObservableObject` wrapping `ModelContext` for CRUD operations and CSV import/export. Injected via SwiftUI environment.
- **MockData** (`Models/MockData.swift`): `ModelContainer.createMockContainer()` creates an in-memory container for SwiftUI `#Preview` blocks.

### App Entry Point
`CardPulseApp.swift` initializes `ModelContainer` with `Card` and `Transaction`, registers Firebase via `AppDelegate`, and injects the container into `MainTabView`.

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
  Settings/
    SettingsView.swift
  CSV/
    DocumentPickerView.swift
    ExportOptionsView.swift
    ImportPreviewView.swift
```

### App Intent (Wallet Automation)
`WalletTransactionIntent.swift` implements `AppIntent` for Shortcuts automation. When triggered from Apple Wallet, it creates a `Transaction` by opening its own `ModelContainer` (not the shared one), guesses category via `NLEmbedding` (with keyword heuristic fallback), logs to Firebase Analytics (`add_wallet_transaction`), and fires a `UNUserNotificationCenter` notification.

### Utilities
- **MerchantUtils** (`Utils/MerchantUtils.swift`): Single source of truth for categories (7 canonical values), SF Symbol icons, and SwiftUI `Color` per category. Always use `MerchantUtils.normalizedCategory(for:)` when storing/displaying categories.
- **ImportExportUtils** (`Utils/ImportExportUtils.swift`): CSV parsing helpers (RFC 4180 compliant, handles quoted fields).

## Key Conventions

- **Categories**: The canonical list is defined in `MerchantUtils.defaultCategories`. Unknown categories normalize to `"Other"`. Do not hardcode category strings elsewhere.
- **Billing cycle**: A card's billing cycle runs from `(statement day of previous month + 1)` to `(statement day of current month)`. All cycle math lives in `CardUtils.swift`.
- **CSV format**: `Merchant,Amount,Category,Card,Date,Note` with date format `yyyy-MM-dd HH:mm:ss`.
- **Previews**: All SwiftUI `#Preview` blocks use `.modelContainer(ModelContainer.createMockContainer())` to get in-memory data.
- **Dark mode only**: The app forces dark mode via `MainTabView`'s `.preferredColorScheme(.dark)`.
- **Design tokens**: Primary teal accent (`Color.teal`), dark navy background (`#0D1A33`), gold (`#FFD700`).

## Firebase
`GoogleService-Info.plist` is present but excluded from version control. Analytics events are logged in `WalletTransactionIntent.perform()`. The app uses `FirebaseCore` + `FirebaseAnalytics` packages.
