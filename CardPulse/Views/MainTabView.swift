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

    private func writeWidgetData() {
        WidgetDataWriter.refresh(using: modelContext)
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
