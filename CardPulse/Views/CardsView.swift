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
        let cal = Calendar.current
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

    private var filteredCards: [Card] {
        switch filter {
        case .all:      return cards
        case .hit:      return goalCards.filter { status(for: $0) == .hit }
        case .onTrack:  return goalCards.filter { status(for: $0) == .onTrack }
        case .behind:   return goalCards.filter { status(for: $0) == .behind }
        }
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
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredCards) { card in
                                    Button(action: { selectedCard = card }) {
                                        CardRow(card: card, status: status(for: card))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAddGoal) {
            CardFormView()
        }
        .sheet(item: $selectedCard) { card in
            CardFormView(card: card)
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
            Text("Tap + to add your first card")
                .foregroundColor(AppColors.textSecondary)
                .font(AppTypography.caption)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


#Preview {
    CardsView()
        .modelContainer(ModelContainer.createMockContainer())
}
