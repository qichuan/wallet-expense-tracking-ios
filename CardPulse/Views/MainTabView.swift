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
    @State private var selectedTab = 0
    @AppStorage("hasChosenDefaultCurrency") private var hasChosenDefaultCurrency = false
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()

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
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .accentColor(.teal)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: .constant(!hasChosenDefaultCurrency)) {
            CurrencyOnboardingView()
                .interactiveDismissDisabled(true)
        }
        .onAppear {
            writeWidgetData()
            CurrencyUtils.ensureDefaultCurrenciesEnabled()
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
