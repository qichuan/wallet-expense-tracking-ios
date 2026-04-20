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
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
            OnboardingFlow()
                .interactiveDismissDisabled(true)
        }
        .onAppear {
            writeWidgetData()
            CurrencyUtils.ensureDefaultCurrenciesEnabled()
            // Returning users (pre-onboarding-flow) who already chose a currency
            // should not be pushed through onboarding again.
            if hasChosenDefaultCurrency && !hasCompletedOnboarding {
                hasCompletedOnboarding = true
            }
            refreshExchangeRatesIfNeeded()
        }
        .onChange(of: cards.count) { writeWidgetData() }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                writeWidgetData()
                refreshExchangeRatesIfNeeded()
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(ModelContainer.createMockContainer())
}
