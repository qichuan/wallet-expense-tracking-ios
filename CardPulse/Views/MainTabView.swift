//
//  MainTabView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var cards: [Card]
    @State private var selectedTab = MainTabView.initialTab
    @State private var transactionFromNotification: Transaction?
    @ObservedObject private var notificationRouter = NotificationRouter.shared
    @AppStorage("hasChosenDefaultCurrency") private var hasChosenDefaultCurrency = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()

    /// Tab tags, in the order they appear in the bottom bar.
    enum Tab: Int, CaseIterable {
        case today = 0, cards, recap, me

        var label: String {
            switch self {
            case .today: return "Today"
            case .cards: return "Cards"
            case .recap: return "Recap"
            case .me:    return "Me"
            }
        }

        var symbol: String {
            switch self {
            case .today: return "house.fill"
            case .cards: return "creditcard.fill"
            case .recap: return "chart.bar.fill"
            case .me:    return "person.fill"
            }
        }

        /// Screen names kept from the old tab layout so analytics stay comparable.
        var analyticsName: String {
            switch self {
            case .today: return "home"
            case .cards: return "cards"
            case .recap: return "analytics"
            case .me:    return "settings"
            }
        }
    }

    /// Demo launches (`-StoreDemo -StoreTab 2`) can open on any tab for screenshot capture.
    private static var initialTab: Int {
        #if DEBUG
        if StoreDemo.isEnabled, let tab = Tab(rawValue: UserDefaults.standard.integer(forKey: "StoreTab")) {
            return tab.rawValue
        }
        #endif
        return Tab.today.rawValue
    }

    private func writeWidgetData() {
        #if DEBUG
        // Keep demo numbers out of the real widget.
        if StoreDemo.isEnabled { return }
        #endif
        WidgetDataWriter.refresh(using: modelContext)
    }

    private func refreshExchangeRatesIfNeeded() {
        guard hasChosenDefaultCurrency, CurrencyUtils.ratesNeedRefresh else { return }
        Task {
            let codes = CurrencyUtils.enabledCurrencyCodes
            let base = CurrencyUtils.defaultCurrencyCode
            guard let fetched = await CurrencyUtils.fetchRates(for: codes, to: base) else { return }
            CurrencyUtils.saveRates(fetched, baseCurrency: base)
            if let data = try? JSONEncoder().encode(fetched) {
                exchangeRatesData = data
            }
        }
    }

    private func scheduleCycleNudges() {
        guard hasCompletedOnboarding else { return }
        #if DEBUG
        if StoreDemo.isEnabled { return }
        #endif
        let cards = self.cards
        Task { await CycleNudgeScheduler.evaluate(cards: cards) }
    }

    private func consumePendingNotificationTransaction() {
        guard let id = notificationRouter.pendingTransactionId else { return }
        var descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let tx = try? modelContext.fetch(descriptor).first {
            selectedTab = Tab.today.rawValue
            transactionFromNotification = tx
        }
        notificationRouter.pendingTransactionId = nil
    }

    var body: some View {
        // The bar sits below the TabView rather than in a safe-area inset: pages are
        // hosted in their own controllers and don't reliably pick up an inset, so
        // giving the TabView a frame that ends above the bar is the only way to
        // guarantee scroll content stops there.
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                HomeView(selectedTab: $selectedTab)
                    .toolbar(.hidden, for: .tabBar)
                    .tag(Tab.today.rawValue)

                CardsView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(Tab.cards.rawValue)

                AnalysisView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(Tab.recap.rawValue)

                SettingsView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(Tab.me.rawValue)
            }
            ChunkyTabBar(selection: $selectedTab)
        }
        .tint(AppColors.accent)
        .onAppear {
            writeWidgetData()
            CurrencyUtils.ensureDefaultCurrenciesEnabled()
            // Returning users (pre-onboarding-flow) who already chose a currency
            // should not be pushed through onboarding again.
            if hasChosenDefaultCurrency && !hasCompletedOnboarding {
                hasCompletedOnboarding = true
            }
            refreshExchangeRatesIfNeeded()
            consumePendingNotificationTransaction()
            // Cold launch from a nudge tap: surface the Cards tab so CardsView presents it.
            if notificationRouter.pendingCardId != nil { selectedTab = Tab.cards.rawValue }
            scheduleCycleNudges()
        }
        .onChange(of: cards.count) { writeWidgetData() }
        .onChange(of: selectedTab) { _, newTab in
            if let tab = Tab(rawValue: newTab) {
                AnalyticsTracker.view(tab.analyticsName)
            }
        }
        .onChange(of: notificationRouter.pendingTransactionId) {
            consumePendingNotificationTransaction()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                writeWidgetData()
                refreshExchangeRatesIfNeeded()
                scheduleCycleNudges()
            }
        }
        .onChange(of: notificationRouter.pendingCardId) {
            // Switch to the Cards tab so CardsView can present the tapped card.
            if notificationRouter.pendingCardId != nil { selectedTab = Tab.cards.rawValue }
        }
        .sheet(item: $transactionFromNotification) { tx in
            TransactionDetailView(transaction: tx)
        }
    }
}

/// Bottom bar from the design: each tab is an icon in a rounded pill that
/// fills accent-soft when selected, with a Fredoka label underneath.
private struct ChunkyTabBar: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTabView.Tab.allCases, id: \.self) { tab in
                let selected = selection == tab.rawValue
                Button {
                    selection = tab.rawValue
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(AppTypography.iconLarge)
                            .frame(width: 54, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selected ? AppColors.accentSoft : AppColors.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(selected ? AppColors.accentSoftBorder : AppColors.clear, lineWidth: 2)
                            )
                        Text(tab.label)
                            .font(AppTypography.tabLabel)
                    }
                    .foregroundColor(selected ? AppColors.accent : AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(
            AppColors.backgroundCard
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle().fill(AppColors.border).frame(height: 2)
                }
        )
    }
}

#Preview {
    MainTabView()
        .modelContainer(ModelContainer.createMockContainer())
}
