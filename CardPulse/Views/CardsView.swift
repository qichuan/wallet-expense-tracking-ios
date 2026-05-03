//
//  CardsView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct CardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [Card]

    @State private var showingAddGoal = false
    @State private var selectedCard: Card?
    @State private var filter: Filter = .all

    /// Persisted card display order as a JSON array of UUID strings.
    /// Stored outside SwiftData so the data model stays untouched.
    @AppStorage("cardOrder") private var cardOrderRaw: String = "[]"

    enum Filter: String, CaseIterable {
        case all, hit, onTrack, behind

        var label: String {
            switch self {
            case .all:      return "All"
            case .hit:      return "Hit"
            case .onTrack:  return "On track"
            case .behind:   return "Behind"
            }
        }
    }

    private func status(for card: Card) -> CardStatus {
        CardStatus.derive(progress: card.progressPercentage, pacing: cyclePacing(for: card))
    }

    private func cyclePacing(for card: Card) -> Double? {
        let start = card.currentCycleStart
        let end = card.currentCycleEnd
        let totalSeconds = end.timeIntervalSince(start)
        guard totalSeconds > 0 else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let ratio = elapsed / totalSeconds
        return max(0, min(1, ratio))
    }

    private var goalCards: [Card] {
        cards.filter { $0.hasMinimumSpending && $0.minimumSpendingAmount > 0 }
    }

    private var counts: (all: Int, hit: Int, onTrack: Int, behind: Int) {
        var hit = 0, onTrack = 0, behind = 0
        for card in goalCards {
            switch status(for: card) {
            case .hit: hit += 1
            case .onTrack: onTrack += 1
            case .behind: behind += 1
            }
        }
        return (goalCards.count, hit, onTrack, behind)
    }

    /// `cards` sorted by the user's saved order. Cards missing from the saved
    /// order list (e.g. newly created) keep their `cards` relative position
    /// and land at the end.
    private var orderedCards: [Card] {
        let order = decodedOrder()
        let indexByID: [UUID: Int] = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return cards.sorted { lhs, rhs in
            switch (indexByID[lhs.id], indexByID[rhs.id]) {
            case let (l?, r?): return l < r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return false // stable — preserves @Query order
            }
        }
    }

    private var filteredCards: [Card] {
        switch filter {
        case .all:      return orderedCards
        case .hit:      return orderedCards.filter { goalCards.contains($0) && status(for: $0) == .hit }
        case .onTrack:  return orderedCards.filter { goalCards.contains($0) && status(for: $0) == .onTrack }
        case .behind:   return orderedCards.filter { goalCards.contains($0) && status(for: $0) == .behind }
        }
    }

    private func decodedOrder() -> [UUID] {
        guard let data = cardOrderRaw.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return strings.compactMap { UUID(uuidString: $0) }
    }

    private func saveOrder(_ ids: [UUID]) {
        let strings = ids.map { $0.uuidString }
        guard let data = try? JSONEncoder().encode(strings),
              let raw = String(data: data, encoding: .utf8) else { return }
        cardOrderRaw = raw
    }

    /// Applies a `List` move to `orderedCards` and persists the result.
    /// Only valid when the viewer is showing the unfiltered list — reorder
    /// in a filtered subset would produce ambiguous results.
    private func moveCards(from source: IndexSet, to destination: Int) {
        var working = orderedCards
        working.move(fromOffsets: source, toOffset: destination)
        saveOrder(working.map { $0.id })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    BrandHeader(title: "Cards") {
                        Button(action: { showingAddGoal = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(AppTypography.headerAction)
                                .foregroundColor(AppColors.accent)
                        }
                    }

                    if !goalCards.isEmpty {
                        filterBar
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }

                    if cards.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(filteredCards) { card in
                                Button(action: { selectedCard = card }) {
                                    CardRow(card: card, status: status(for: card))
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(AppColors.backgroundPrimary)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 7, leading: 20, bottom: 7, trailing: 20))
                            }
                            // Reorder is only meaningful when viewing the full
                            // list — applying a move to a filtered subset
                            // would produce ambiguous indices in `cards`.
                            .onMove { source, destination in
                                guard filter == .all else { return }
                                moveCards(from: source, to: destination)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(AppColors.backgroundPrimary)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAddGoal) {
            CardFormView()
        }
        .sheet(item: $selectedCard) { card in
            CardDetailView(card: card)
        }
        .onChange(of: cards) {
            if let sel = selectedCard, !cards.contains(where: { $0.id == sel.id }) {
                selectedCard = nil
            }
        }
    }

    @ViewBuilder
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: Filter.all.label,
                           count: counts.all,
                           selected: filter == .all) { filter = .all }
                FilterChip(label: Filter.hit.label,
                           count: counts.hit,
                           selected: filter == .hit) { filter = .hit }
                FilterChip(label: Filter.onTrack.label,
                           count: counts.onTrack,
                           selected: filter == .onTrack) { filter = .onTrack }
                FilterChip(label: Filter.behind.label,
                           count: counts.behind,
                           selected: filter == .behind) { filter = .behind }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No cards yet")
                .foregroundColor(AppColors.textPrimary)
                .font(AppTypography.headline)
            Text("Set up automation and see your first card here, or tap + to manually add one.")
                .foregroundColor(AppColors.textSecondary)
                .font(AppTypography.caption)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}


#Preview {
    CardsView()
        .modelContainer(ModelContainer.createMockContainer())
}
