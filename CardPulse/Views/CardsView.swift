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
    @State private var layoutWidth: LayoutWidth = .compact
    @ObservedObject private var notificationRouter = NotificationRouter.shared

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

    @State private var cardForGoal: Card?
    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"

    private func status(for card: Card) -> CardStatus {
        card.cycleStatus
    }

    private var goalCards: [Card] {
        cards.filter(\.hasSpendGoal)
    }

    private var noGoalCards: [Card] {
        orderedCards.filter { !$0.hasSpendGoal }
    }

    private var bubble: MascotCopy.Line {
        let goals = goalCards.map {
            MascotCopy.Goal(name: $0.name, remaining: $0.remainingAmount,
                            daysRemaining: $0.daysRemaining, status: status(for: $0))
        }
        return MascotCopy.cards(goals: goals) { CurrencyUtils.display($0, code: defaultCurrencyCode) }
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

    /// Goal cards matching the selected filter, in the saved order.
    private var filteredCards: [Card] {
        switch filter {
        case .all:      return orderedCards.filter(\.hasSpendGoal)
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

    /// Applies a `List` move within one section (`subset` is that section's cards in
    /// display order) and persists the result. Goal cards are saved ahead of cards
    /// without a goal, matching how the sections are shown. Only valid when the
    /// viewer is showing the unfiltered list — reorder in a filtered subset would
    /// produce ambiguous results.
    private func moveCards(in subset: [Card], from source: IndexSet, to destination: Int) {
        var moved = subset
        moved.move(fromOffsets: source, toOffset: destination)
        let movedIDs = Set(moved.map(\.id))
        let goals = moved.first?.hasSpendGoal == true ? moved : orderedCards.filter { $0.hasSpendGoal && !movedIDs.contains($0.id) }
        let others = moved.first?.hasSpendGoal == true ? orderedCards.filter { !$0.hasSpendGoal } : moved
        saveOrder((goals + others).map(\.id))
    }

    /// List and detail side by side when there's room for both (iPhone Duo's
    /// inner display); a list with a detail sheet otherwise.
    private var showsDetailPane: Bool {
        layoutWidth == .expanded && !cards.isEmpty
    }

    /// Card shown in the detail pane: the one tapped, else the first in the list.
    private var paneCard: Card? {
        selectedCard ?? filteredCards.first ?? orderedCards.first
    }

    /// Drives the detail sheet only in the compact layout. A card picked in the
    /// pane stays selected through a fold, so it reopens as a sheet on the outer
    /// display; the sheet closing because the device unfolded doesn't clear it.
    private var detailSheetCard: Binding<Card?> {
        Binding(
            get: { showsDetailPane ? nil : selectedCard },
            set: { newValue in
                if newValue != nil || !showsDetailPane { selectedCard = newValue }
            }
        )
    }

    private static let listColumnWidth: CGFloat = 320

    var body: some View {
        // AnyLayout keeps the list's identity, so its scroll position survives a fold.
        let layout = showsDetailPane ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(ZStackLayout())
        layout {
            NavigationStack {
                Group {
                    if cards.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            titleRow
                            emptyState
                        }
                    } else {
                        cardList
                    }
                }
                .screenBackground()
                .navigationBarHidden(true)
            }
            .frame(width: showsDetailPane ? Self.listColumnWidth : nil)

            if showsDetailPane {
                Rectangle()
                    .fill(AppColors.border)
                    .frame(width: 2)
                    .ignoresSafeArea(edges: .vertical)
                detailPane
                    .frame(maxWidth: .infinity)
            }
        }
        .readLayoutWidth($layoutWidth)
        .sheet(isPresented: $showingAddGoal) {
            CardFormView()
        }
        .sheet(item: detailSheetCard) { card in
            CardDetailView(card: card)
        }
        .sheet(item: $cardForGoal) { card in
            CardFormView(card: card)
        }
        .onChange(of: cards) {
            if let sel = selectedCard, !cards.contains(where: { $0.id == sel.id }) {
                selectedCard = nil
            }
        }
        .onAppear { consumePendingNotificationCard() }
        .onChange(of: notificationRouter.pendingCardId) { consumePendingNotificationCard() }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let card = paneCard {
            CardDetailView(card: card, isEmbedded: true)
                .id(card.id)
        } else {
            VStack(spacing: 8) {
                Mascot(mood: .normal, size: 90)
                Text("Pick a card to see its cycle")
                    .font(AppTypography.footnote)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .screenBackground()
        }
    }

    /// Outlines the card showing in the detail pane.
    private func isShowingInPane(_ card: Card) -> Bool {
        showsDetailPane && paneCard?.id == card.id
    }

    private var titleRow: some View {
        BrandHeader(title: "Card goals") {
            HeaderAddButton(accessibilityLabel: "Add card") { showingAddGoal = true }
        }
    }

    private var cardList: some View {
        List {
            Group {
                titleRow
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                MascotSays(mood: bubble.mood, mascotSize: 76) {
                    Text(bubble.text)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 8, trailing: 18))

                if !goalCards.isEmpty {
                    filterBar
                        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 8, trailing: 0))
                }
            }
            .moveDisabled(true)
            .plainListRow()

            ForEach(filteredCards) { card in
                Button(action: { selectedCard = card }) {
                    CardRow(card: card, status: status(for: card))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(isShowingInPane(card) ? AppColors.accent : AppColors.clear, lineWidth: 2.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isShowingInPane(card) ? .isSelected : [])
                .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                .plainListRow()
            }
            .onMove { source, destination in
                guard filter == .all else { return }
                moveCards(in: filteredCards, from: source, to: destination)
            }

            if filter == .all && !noGoalCards.isEmpty {
                SectionLabel(text: "No target set")
                    .padding(.horizontal, 4)
                    .listRowInsets(EdgeInsets(top: 14, leading: 18, bottom: 2, trailing: 18))
                    .moveDisabled(true)
                    .plainListRow()

                ForEach(noGoalCards) { card in
                    Button(action: { selectedCard = card }) {
                        noGoalRow(card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(isShowingInPane(card) ? AppColors.accent : AppColors.clear, lineWidth: 2.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isShowingInPane(card) ? .isSelected : [])
                    .listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18))
                    .plainListRow()
                }
                .onMove { source, destination in
                    moveCards(in: noGoalCards, from: source, to: destination)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 24, for: .scrollContent)
    }

    private func noGoalRow(_ card: Card) -> some View {
        HStack(spacing: 12) {
            CardArt(card: card, width: 34)
            Text(card.name)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Set goal") { cardForGoal = card }
                .font(AppTypography.pillBold)
                .foregroundColor(AppColors.accent)
                .buttonStyle(.borderless)
        }
        .chunkyRow()
    }

    /// Opens the card referenced by a tapped cycle-nudge notification.
    private func consumePendingNotificationCard() {
        guard let id = notificationRouter.pendingCardId else { return }
        if let card = cards.first(where: { $0.id == id }) {
            selectedCard = card
        }
        notificationRouter.pendingCardId = nil
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
            .padding(.trailing, 18)
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Mascot(mood: .normal, size: 110)
                .padding(.bottom, 8)
            Text("No cards yet")
                .foregroundColor(AppColors.textPrimary)
                .font(AppTypography.headline)
            Text("Set up automation and see your first card here, or tap + to manually add one.")
                .foregroundColor(AppColors.textSecondary)
                .font(AppTypography.footnote)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}


#Preview("Light") {
    CardsView()
        .modelContainer(ModelContainer.createMockContainer())
}

#Preview("Dark") {
    CardsView()
        .modelContainer(ModelContainer.createMockContainer())
        .preferredColorScheme(.dark)
}

#Preview("Expanded", traits: .fixedLayout(width: 863, height: 669)) {
    CardsView()
        .modelContainer(ModelContainer.createMockContainer())
}
