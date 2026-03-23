//
//  CardWidgetIntent.swift
//  CardPulseWidget
//

import AppIntents
import WidgetKit

// MARK: - Card entity (selectable in widget configuration)

struct CardEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Card"
    static var defaultQuery = CardEntityQuery()

    var id: String   // UUID string of the card
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

struct CardEntityQuery: EntityQuery, EnumerableEntityQuery {
    func allEntities() async throws -> [CardEntity] {
        eligibleCards()
    }

    func entities(for identifiers: [String]) async throws -> [CardEntity] {
        eligibleCards().filter { identifiers.contains($0.id) }
    }

    func suggestedResults() async throws -> [CardEntity] {
        eligibleCards()
    }

    /// Only cards that have a minimum-spending goal are eligible for the widget.
    private func eligibleCards() -> [CardEntity] {
        (WidgetDataWriter.read()?.cards ?? [])
            .filter { $0.hasMinimumSpending && $0.minimumSpending > 0 }
            .map { CardEntity(id: $0.id.uuidString, name: $0.name) }
    }
}

// MARK: - Widget configuration intent

struct CardWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Cards"
    static var description = IntentDescription("Choose up to 3 cards to display.")

    @Parameter(title: "Cards")
    var selectedCards: [CardEntity]?

    init() { selectedCards = nil }
    init(selectedCards: [CardEntity]?) { self.selectedCards = selectedCards }
}
