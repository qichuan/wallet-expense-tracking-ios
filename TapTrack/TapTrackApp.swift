//
//  TapTrackApp.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

@main
struct TapTrackApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Card.self,
            Transaction.self,
        ])
        
        // Create a more robust configuration
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("SwiftData container created successfully")
            return container
        } catch {
            print("SwiftData initialization error: \(error)")
            print("Error details: \(error.localizedDescription)")
            
            // Try with a simpler configuration as fallback
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                let fallbackContainer = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                print("Fallback SwiftData container created successfully")
                return fallbackContainer
            } catch {
                print("Fallback SwiftData initialization also failed: \(error)")
                print("Fallback error details: \(error.localizedDescription)")
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
