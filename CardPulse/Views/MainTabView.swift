//
//  MainTabView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData
import WidgetKit

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var cards: [Card]
    @State private var selectedTab = 0

    private func writeWidgetData() {
        let spendData = cards.map { card in
            CardSpendData(
                id: card.id,
                name: card.name,
                monthlySpent: Double(truncating: card.monthlySpent as NSDecimalNumber),
                minimumSpending: Double(truncating: card.minimumSpendingAmount as NSDecimalNumber),
                hasMinimumSpending: card.hasMinimumSpending,
                daysRemaining: card.daysRemaining,
                rewardType: card.rewardType.rawValue,
                spendingPeriodDisplay: card.spendingPeriodDisplay
            )
        }
        WidgetDataWriter.write(spendData: spendData)
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
        .onAppear { writeWidgetData() }
        .onChange(of: cards.count) { writeWidgetData() }
        .onChange(of: scenePhase) {
            if scenePhase == .active { writeWidgetData() }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(ModelContainer.createMockContainer())
}
