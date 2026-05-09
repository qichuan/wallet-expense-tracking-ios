//
//  MainTabView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData
import UIKit

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var cards: [Card]
    @State private var selectedTab = 0
    @State private var transactionFromNotification: Transaction?
    @ObservedObject private var notificationRouter = NotificationRouter.shared
    @AppStorage("hasChosenDefaultCurrency") private var hasChosenDefaultCurrency = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()

    init() {
        configureTabBarAppearance()
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.backgroundPrimary)
        appearance.shadowColor = UIColor(AppColors.divider)

        let unselected = UIColor(AppColors.textTertiary)
        appearance.stackedLayoutAppearance.normal.iconColor = unselected
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]
        appearance.inlineLayoutAppearance.normal.iconColor = unselected
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]
        appearance.compactInlineLayoutAppearance.normal.iconColor = unselected
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private func writeWidgetData() {
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

    private func consumePendingNotificationTransaction() {
        guard let id = notificationRouter.pendingTransactionId else { return }
        var descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let tx = try? modelContext.fetch(descriptor).first {
            selectedTab = 0
            transactionFromNotification = tx
        }
        notificationRouter.pendingTransactionId = nil
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            AnalysisView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Analysis")
                }
                .tag(1)
            
            CardsView()
                .tabItem {
                    Image(systemName: "creditcard.fill")
                    Text("Cards")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "record.circle")
                    Text("Settings")
                }
                .tag(3)
        }
        .tint(AppColors.accent)
        .preferredColorScheme(.dark)
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
        }
        .onChange(of: cards.count) { writeWidgetData() }
        .onChange(of: selectedTab) { _, newTab in
            switch newTab {
            case 0: AnalyticsTracker.view("home")
            case 1: AnalyticsTracker.view("analytics")
            case 2: AnalyticsTracker.view("cards")
            case 3: AnalyticsTracker.view("settings")
            default: break
            }
        }
        .onChange(of: notificationRouter.pendingTransactionId) {
            consumePendingNotificationTransaction()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                writeWidgetData()
                refreshExchangeRatesIfNeeded()
            }
        }
        .sheet(item: $transactionFromNotification) { tx in
            TransactionDetailView(transaction: tx)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(ModelContainer.createMockContainer())
}
