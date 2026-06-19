# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CardPulse** is an iOS app (iOS 17.0+, Xcode 15.0+, Swift 5.9+) for tracking Apple Wallet transactions and monitoring credit card spending goals. The app is built with SwiftUI, SwiftData, App Intents, Firebase Analytics, and Apple Charts.

## Build & Development Commands

All development is done via Xcode. There is no CLI build system (no Makefile, SPM package, or fastlane).

```bash
# Build and run on the connected iPhone 12 device (scheme name is "TapTrack")
xcodebuild -project CardPulse.xcodeproj -scheme TapTrack -destination 'platform=iOS,name=iPhone 12' build

# Run tests on the iPhone 12 device
xcodebuild -project CardPulse.xcodeproj -scheme TapTrack -destination 'platform=iOS,name=iPhone 12' test

# Run a single test class
xcodebuild -project CardPulse.xcodeproj -scheme TapTrack -destination 'platform=iOS,name=iPhone 12' -only-testing:CardPulseTests/MyTestClass test
```

For day-to-day development, open `CardPulse.xcodeproj` in Xcode and run/test from there.

## Architecture

### Data Layer
- **Models** (`CardPulse/Models/`): `Card`, `Transaction`, and `SpendingCategory` are `@Model` classes for SwiftData. `Card` has a cascade-delete relationship to `Transaction` via `@Relationship`. `Transaction` has a `currency: String` field (added in schema V2).
- **SpendingCategory** (`Models/SpendingCategory.swift`): `@Model` class storing category name, SF Symbol icon, hex color, `isBuiltIn` flag, and `sortOrder`. Built-in categories are seeded on first launch and cannot be deleted.
- **CardPulseMigration** (`Models/CardPulseMigration.swift`): `CardPulseMigrationPlan` defines V1→V2→V3 migrations. V1→V2 backfills `currency` on existing transactions. V2→V3 seeds the 7 built-in `SpendingCategory` records via `CategorySeeding.seedBuiltInsIfNeeded`. `CategorySeeding` is also called at app launch as a safety seed for users who install on V3 directly.
- **CardUtils** (`Utils/CardUtils.swift`): `Card` extension with computed properties for billing cycle logic — `currentCycleStart`, `currentCycleEnd`, `monthlySpent`, `progressPercentage`, `daysRemaining`, `spendingPeriodDisplay`. Cycle boundaries are derived from `minimumSpendingByDayOfMonth` (statement day).
- **TransactionManager** (`TransactionManager.swift`): `@MainActor ObservableObject` wrapping `ModelContext` for CRUD operations and CSV import/export. Injected via SwiftUI environment.
- **MockData** (`Models/MockData.swift`): `ModelContainer.createMockContainer()` creates an in-memory container for SwiftUI `#Preview` blocks.

### App Entry Point
`CardPulseApp.swift` initializes `ModelContainer` (schema: `Card`, `Transaction`, `SpendingCategory`) using `CardPulseMigrationPlan` (V1→V2→V3 migration), calls `CategorySeeding.seedBuiltInsIfNeeded` on launch, and registers Firebase via `AppDelegate`. `RootView` reads `@AppStorage("hasCompletedOnboarding")` — if false, it shows `OnboardingFlow`; otherwise `MainTabView`.

### Onboarding
`OnboardingFlow` (`Views/Onboarding/`) is a multi-step flow shown to first-time users. Steps:
1. **Welcome** (`WelcomeStepView`) — splash with app intro
2. **Currency** (`CurrencyStepView`) — pick default currency, backfills existing transactions
3. **Categories** (`CategoriesStepView`) — preview built-in categories
4. **Notifications** (`NotificationsStepView`) — request notification permission
5. **Automation** (`AutomationStepView`) — guide to set up Apple Shortcuts with PiP video (`PiPPlayerView`)

Completion sets `hasCompletedOnboarding = true` and logs `AnalyticsTracker.Event.onboardingCompleted`. The automation step has a "Skip for now" fallback.

### Navigation
`MainTabView` hosts four tabs: **Home** (tag 0), **Analysis** (tag 1), **Cards** (tag 2), **Settings** (tag 3). The app always uses `.preferredColorScheme(.dark)`.

### Views Structure
```
Views/
  MainTabView.swift
  AnalysisView.swift           # Donut + stacked bar; Day/Week/Month/Year + Custom range; multi-card filter; location map; shareable recap
  CardFilterSheet.swift        # Sheet wrapper around CardMultiSelectList (Analysis card filter)
  CardMultiSelectList.swift    # Reusable card multi-select checklist (Analysis + transactions filter)
  Home/
    HomeView.swift             # Latest 10 transactions, shortcut banner
    NotificationBanner.swift
    ShortcutsBanner.swift
  Card/
    CardsView.swift
    CardFormView.swift
    CardRow.swift
  Transaction/
    AllTransactionsView.swift
    TransactionFormView.swift
    TransactionRow.swift       # Reusable row used app-wide
    FilterSheetView.swift
  Settings/
    SettingsView.swift
    CategoryManagementView.swift  # Add/edit/delete SpendingCategory records
    HowToAutoTrackingView.swift
  Onboarding/
    OnboardingFlow.swift
    OnboardingScaffold.swift
    WelcomeStepView.swift
    CurrencyStepView.swift
    CategoriesStepView.swift
    NotificationsStepView.swift
    AutomationStepView.swift
  Recap/
    SpendingRecapView.swift       # Shareable recap sheet (renders to image + share CTA)
    SpendingRecapCard.swift       # Recap card UI + SpendingRecap model
  Components/                  # Reusable UI components
    ActivityShareSheet.swift      # UIActivityViewController wrapper (image + link share)
    DonutChartView.swift
    FilterChip.swift
    FormComponents.swift
    MetricStat.swift
    PiPPlayerView.swift
    RewardTypePill.swift
    SegmentedPillControl.swift
    SpendingDeltaLabel.swift
    StatusPill.swift
    SummaryHeroCard.swift
    TransactionLocationMapCard.swift  # Embedded clustering map for Analysis
  CSV/
    DocumentPickerView.swift
    ExportOptionsView.swift
    ImportPreviewView.swift
```

### Theme System
The `Theme/` folder is the single source of truth for all visual tokens:
- **AppColors** (`Theme/AppColors.swift`): All colors as static constants. Primary accent is `#2E6DFF` (blue), background is `#0A1428`. Never use `Color.teal` or raw hex strings in views — always reference `AppColors.*`.
- **AppTypography** (`Theme/AppTypography.swift`): All fonts as static constants. UI files **must** use `AppTypography` tokens — never declare `.font(...)` inline.
- **BrandHeader / BrandMark** (`Theme/BrandHeader.swift`, `Theme/BrandMark.swift`): Reusable brand chrome.
- **CardStatus / ViewModifiers** (`Theme/CardStatus.swift`, `Theme/ViewModifiers.swift`): Status enum and shared SwiftUI view modifiers.

### Analytics
`AnalyticsTracker` (`Utils/AnalyticsTracker.swift`) is the single entry point for all Firebase Analytics calls. Use `AnalyticsTracker.log(_:_:)` for events, `.view(_:_:)` for screen views, and `.edit(_:_:)` for data edits. Event name constants live in `AnalyticsTracker.Event`. Do not call `Analytics.logEvent` directly.

### Widget Support
`WidgetDataWriter` (`Utils/WidgetDataWriter.swift`) shares spending data with the widget extension via App Group `group.com.zqc.TapTrack`. `CardSpendData` and `WidgetSnapshot` are `Codable` structs compiled into both the app and widget targets. `WidgetDataWriter.write(spendData:)` encodes the snapshot to shared `UserDefaults` and calls `WidgetCenter.shared.reloadAllTimelines()`. The widget reads via `WidgetDataWriter.read()`. Widget views live in `CardPulseWidget/CardWidgetViews.swift`.

### App Intent (Wallet Automation)
`WalletTransactionIntent.swift` implements `AppIntent` for Shortcuts automation. When triggered from Apple Wallet, it creates a `Transaction` by opening its own `ModelContainer` (not the shared one), parses the amount string via `CurrencyUtils.parseCurrencyAndAmount(from:)` to extract currency and amount, guesses category via `NLEmbedding` (with keyword heuristic fallback), logs to Firebase Analytics via `AnalyticsTracker`, and fires a `UNUserNotificationCenter` notification.

### Notifications & Nudges
`NotificationRouter` (`Utils/NotificationRouter.swift`) is the `UNUserNotificationCenter` delegate set at launch; it publishes `pendingTransactionId` (transaction-added taps) and `pendingCardId` (cycle-nudge taps), which `MainTabView`/`CardsView` consume to present the right screen. `CycleNudgeScheduler` (`Utils/CycleNudgeScheduler.swift`), run on app foreground from `MainTabView`, schedules proactive local notifications from the cycle/cap math: a min-spend reminder a configurable number of days before the statement (`cycleNudgeLeadDays` in Settings, default 3) and a once-per-cycle cap-reached alert. It only schedules when notification permission is already authorized.

### Utilities
- **MerchantUtils** (`Utils/MerchantUtils.swift`): Single source of truth for categories (7 canonical values), SF Symbol icons, and color hex values per category. Used by `CategorySeeding` to seed `SpendingCategory` records. Always use `MerchantUtils.normalizedCategory(for:)` when storing/displaying categories.
- **ImportExportUtils** (`Utils/ImportExportUtils.swift`): CSV parsing helpers (RFC 4180 compliant, handles quoted fields).
- **RewardCalculator** (`Utils/RewardCalculator.swift`): Computes miles/cashback as `floor(amount / roundingBlock) × roundingBlock × rate`. `convertedReward(for:)` is the canonical per-transaction reward (FX-converts to the default currency first); `aggregate(_:)` and `cycleRewardStatus(for:)` build on it. `breakdown(for:)` feeds the transaction detail's explanation table. The raw-amount primitive `reward(amount:category:card:)` exists for previews/tests only.
- **TransactionMapClustering** (`Utils/TransactionMapClustering.swift`): Pure geometry for the Analysis location map — greedy distance-based clustering of located transactions and a bounding `MKCoordinateRegion`. Unit-tested; used by `TransactionLocationMapCard` and the recap map.
- **MapSnapshotRenderer** (`Utils/MapSnapshotRenderer.swift`): Renders a static `MKMapSnapshotter` image with cluster dots for the recap (since `ImageRenderer` can't capture a live `Map`).
- **CycleNudgeScheduler** (`Utils/CycleNudgeScheduler.swift`): Schedules min-spend and reward-cap local notifications (see Notifications & Nudges). Pure helpers (`resolvedLeadDays`, `reminderFireComponents`, `shouldFireCapNudge`) are unit-tested.
- **AppLinks** (`Utils/AppLinks.swift`): Centralised external links (e.g. the App Store URL used in the recap share CTA).
- **CurrencyUtils** (`Utils/CurrencyUtils.swift`): Multi-currency support. Holds the built-in currency list (`allCurrencies`, 15 currencies), user-defined custom currencies, enabled/default currency preferences (all in `UserDefaults`), and exchange-rate cache (via [Frankfurter API](https://www.frankfurter.app), 5-day TTL). Key methods: `parseCurrencyAndAmount(from:)` parses raw Wallet strings like `"S$12.50"` or `"MYR 8.00"`; `fetchRates(for:to:)` fetches and inverts rates; `rateToDefault(from:)` returns the cached conversion rate.

## Key Conventions

- **Categories**: Canonical built-in categories are defined in `MerchantUtils.defaultCategories` and persisted as `SpendingCategory` records (seeded on first launch). Unknown categories normalize to `"Other"`. Use `MerchantUtils.normalizedCategory(for:)` when storing/displaying; do not hardcode category strings.
- **Billing cycle**: A card's billing cycle runs from `(statement day of previous month + 1)` to `(statement day of current month)`. All cycle math lives in `CardUtils.swift`.
- **Currency**: Every `Transaction` stores a `currency` code (ISO 4217). Always use `CurrencyUtils.parseCurrencyAndAmount(from:)` to extract currency + amount from raw strings. For display, use `CurrencyUtils.symbol(for:)`. Never hardcode currency symbols.
- **Rewards**: Miles and cashback are always calculated on the amount converted to the default currency — convert, then block-round, then apply the rate. Use `RewardCalculator.convertedReward(for:)` / `aggregate(_:)`; never apply a reward rate to a raw foreign-currency amount. When no FX rate is cached, the raw amount is used and UI keeps the transaction's own currency label.
- **CSV format**: `Merchant,Amount,Currency,Category,Card,Date,Note,Latitude,Longitude,PlaceName` with date format `yyyy-MM-dd HH:mm:ss`. The `Amount` field may include a currency prefix (e.g. `S$12.50`) — `ImportExportUtils` uses `CurrencyUtils.parseCurrencyAndAmount` to parse it.
- **Previews**: All SwiftUI `#Preview` blocks use `.modelContainer(ModelContainer.createMockContainer())` to get in-memory data.
- **Dark mode only**: The app forces dark mode (set in `OnboardingFlow` and `MainTabView` via `.preferredColorScheme(.dark)`).
- **Design tokens**: Always use `AppColors.*` for colors and `AppTypography.*` for fonts. Never inline colors or fonts in views.

## Firebase
`GoogleService-Info.plist` is present but excluded from version control. All Analytics events go through `AnalyticsTracker`. The app uses `FirebaseCore` + `FirebaseAnalytics` packages.
