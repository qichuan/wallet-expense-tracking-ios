//
//  CardPulseWidgetBundle.swift
//  CardPulseWidget
//
//  Created by Zhang Qichuan on 22/3/26.
//

import WidgetKit
import SwiftUI

// MARK: - Widget definition

struct CardSpendWidget: Widget {
    let kind = "CardSpendWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: CardWidgetIntent.self, provider: CardWidgetProvider()) { entry in
            CardSpendWidgetEntryView(entry: entry)
                .containerBackground(Color(red: 0.05, green: 0.10, blue: 0.20), for: .widget)
        }
        .configurationDisplayName("Card Spending")
        .description("Choose up to 3 cards to track minimum-spending progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

// MARK: - Entry view (routes to the correct layout by family)

struct CardSpendWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: CardWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallCardWidgetView(entry: entry)
        case .systemMedium:
            MediumCardWidgetView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularWidgetView(entry: entry)
        default:
            SmallCardWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget bundle entry point

@main
struct CardPulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        CardSpendWidget()
    }
}
