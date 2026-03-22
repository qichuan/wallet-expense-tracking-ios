//
//  CardWidgetEntry.swift
//  CardPulseWidget
//

import Foundation
import WidgetKit

struct CardWidgetEntry: TimelineEntry {
    let date: Date
    let cards: [CardSpendData]
    let lastUpdated: Date
}
