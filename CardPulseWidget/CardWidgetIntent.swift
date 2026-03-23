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

    /// Sentinel ID used to represent "no card selected" in the picker.
    static let noneID = "none"
    static let none = CardEntity(id: noneID, name: "None")

    var id: String   // UUID string of the card, or "none"
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

struct CardEntityQuery: EntityQuery, EnumerableEntityQuery {
    func allEntities() async throws -> [CardEntity] {
        [.none] + eligibleCards()
    }

    func entities(for identifiers: [String]) async throws -> [CardEntity] {
        ([.none] + eligibleCards()).filter { identifiers.contains($0.id) }
    }

    func suggestedResults() async throws -> [CardEntity] {
        [.none] + eligibleCards()
    }

    /// Only cards that have a minimum-spending goal are eligible for the widget.
    private func eligibleCards() -> [CardEntity] {
        (WidgetDataWriter.read()?.cards ?? [])
            .filter { $0.hasMinimumSpending && $0.minimumSpending > 0 }
            .map { CardEntity(id: $0.id.uuidString, name: $0.name) }
    }
}

// MARK: - Medium widget intent (up to 3 cards)

struct CardWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Cards"
    static var description = IntentDescription("Choose up to 3 cards to display.")

    @Parameter(title: "Card 1")
    var card1: CardEntity?

    @Parameter(title: "Card 2")
    var card2: CardEntity?

    @Parameter(title: "Card 3")
    var card3: CardEntity?

    init() {}
}
