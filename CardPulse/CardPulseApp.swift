//
//  CardPulseApp.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    #if !DEBUG
    FirebaseApp.configure()
    #endif
    return true
  }
}

@main
struct CardPulseApp: App {
    
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Card.self,
            Transaction.self,
            SpendingCategory.self,
            CardRewardRule.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, allowsSave: true)

        do {
            let container = try ModelContainer(for: schema, migrationPlan: CardPulseMigrationPlan.self, configurations: [modelConfiguration])
            // Safety seed: fresh installs on V3 don't run the V2→V3 stage, so seed here.
            try CategorySeeding.seedBuiltInsIfNeeded(in: container.mainContext)
            RecurringMaterializer.materialize(in: container.mainContext)
            WidgetDataWriter.refresh(using: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    #if DEBUG
    @AppStorage("debugAlwaysShowOnboarding") private var debugAlwaysShowOnboarding = false
    #endif

    private var shouldShowOnboarding: Bool {
        #if DEBUG
        if debugAlwaysShowOnboarding { return false }
        #endif
        return !hasCompletedOnboarding
    }

    var body: some View {
        Group {
            if shouldShowOnboarding {
                OnboardingFlow()
                    .preferredColorScheme(.dark)
            } else {
                MainTabView()
            }
        }
    }
}
