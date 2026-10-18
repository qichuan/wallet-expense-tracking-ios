//
//  HomeView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selectedTab: Int

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var cards: [Card]

    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"
    // Observed so goal progress recomputes when FX rates are refreshed.
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()

    @State private var showingAddTransaction = false
    @State private var showingAllTransactions = false
    @State private var selectedTransaction: Transaction?

    private static let recentLimit = 5

    // MARK: - Derived state

    private var cardsWithGoals: [Card] {
        cards.filter(\.hasSpendGoal).sorted { $0.name < $1.name }
    }

    private var cardsHitCount: Int {
        cardsWithGoals.filter { $0.progressPercentage >= 1.0 }.count
    }

    private var goals: [MascotCopy.Goal] {
        cardsWithGoals.map {
            MascotCopy.Goal(name: $0.name, remaining: $0.remainingAmount,
                            daysRemaining: $0.daysRemaining, status: $0.cycleStatus)
        }
    }

    private var streak: ActivityStreak {
        ActivityStreak(dates: transactions.map(\.date))
    }

    /// Nearest statement among cards still short of their target (or any goal card when all have hit).
    private var daysLeft: Int? {
        let open = cardsWithGoals.filter { $0.progressPercentage < 1.0 }
        return (open.isEmpty ? cardsWithGoals : open).map(\.daysRemaining).min()
    }

    private var remainingToSpend: Decimal {
        cardsWithGoals.reduce(Decimal(0)) { $0 + $1.remainingAmount }
    }

    private func money(_ amount: Decimal) -> String {
        CurrencyUtils.display(amount, code: defaultCurrencyCode)
    }

    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(Self.recentLimit))
    }

    private func isNew(_ tx: Transaction) -> Bool {
        Date().timeIntervalSince(tx.date) < 24 * 60 * 60
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    heroCard
                    if !cardsWithGoals.isEmpty {
                        minSpendCard
                    }
                    if transactions.isEmpty {
                        emptyState
                    } else {
                        recentSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .screenBackground()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAddTransaction) {
            TransactionFormView()
        }
        .sheet(isPresented: $showingAllTransactions) {
            NavigationStack {
                AllTransactionsView()
                    .screenBackground()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showingAllTransactions = false }
                                .foregroundColor(AppColors.accent)
                        }
                    }
            }
        }
        .sheet(item: $selectedTransaction) { tx in
            TransactionDetailView(transaction: tx)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Wordmark()
            Spacer(minLength: 4)
            ChunkyPill {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(AppTypography.iconMedium)
                    Text("\(streak.currentStreak)")
                        .font(AppTypography.streakBig)
                }
                .foregroundColor(AppColors.streak)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak.currentStreak) day streak")
            if !cardsWithGoals.isEmpty {
                ChunkyPill {
                    HStack(spacing: 5) {
                        Image(systemName: "trophy")
                            .font(AppTypography.iconMedium)
                        Text("\(cardsHitCount)/\(cardsWithGoals.count)")
                            .font(AppTypography.streakBig)
                    }
                    .foregroundColor(AppColors.goldEdge)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(cardsHitCount) of \(cardsWithGoals.count) targets hit")
            }
            HeaderAddButton(accessibilityLabel: "Add transaction") {
                showingAddTransaction = true
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        let line = MascotCopy.today(goals: goals, money: money)
        return VStack(alignment: .leading, spacing: 16) {
            MascotSays(mood: line.mood, mascotSize: 112,
                       motion: line.mood == .excited ? .jump : .bob,
                       bubbleFill: AppColors.backgroundPrimary) {
                bubbleText(line)
            }
            WeekFlameStrip(days: streak.weekStrip)
        }
        .cardSurface()
    }

    private func bubbleText(_ line: MascotCopy.Line) -> Text {
        guard let emphasis = line.emphasis else { return Text(line.text) }
        return Text(emphasis).font(AppTypography.bubbleEmphasis).foregroundColor(AppColors.streak)
            + Text(line.text)
    }

    // MARK: - Min-spend

    private var minSpendCard: some View {
        Button {
            selectedTab = MainTabView.Tab.cards.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Min-spend")
                        .font(AppTypography.sectionTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    if let daysLeft {
                        Text(MascotCopy.daysLeftText(daysLeft).uppercased())
                            .font(AppTypography.pill)
                            .foregroundColor(AppColors.statusBehindText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppColors.statusBehindSoft))
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(money(remainingToSpend))
                        .font(AppTypography.amountLarge)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(cardsWithGoals.count == 1 ? "to go on 1 card" : "to go across \(cardsWithGoals.count) cards")
                        .font(AppTypography.amountTarget)
                        .foregroundColor(AppColors.textSecondary)
                }
                ForEach(cardsWithGoals) { card in
                    goalRow(card)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    private func goalRow(_ card: Card) -> some View {
        let status = card.cycleStatus
        return HStack(spacing: 10) {
            CardArt(card: card)
            Text(card.name)
                .font(AppTypography.rowValue)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)
            ChunkyProgressBar(progress: card.progressPercentage, color: status.color)
            Image(systemName: status.icon)
                .font(AppTypography.iconSmall)
                .foregroundColor(status.color)
                .frame(width: 22, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.name), \(Int(card.progressPercentage * 100)) percent, \(status.label)")
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent taps")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("View all") { showingAllTransactions = true }
                    .font(AppTypography.bannerCTA)
                    .foregroundColor(AppColors.accent)
            }
            .padding(.horizontal, 4)

            ForEach(recentTransactions) { tx in
                Button { selectedTransaction = tx } label: {
                    TransactionRow(transaction: tx, showsTime: true, isNew: isNew(tx))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No transactions yet")
                .foregroundColor(AppColors.textPrimary)
                .font(AppTypography.headline)
            Text("Set up automation and see your first transaction here, or tap + to manually add one.")
                .foregroundColor(AppColors.textSecondary)
                .font(AppTypography.footnote)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}

/// Mon–Sun row of flame circles: filled for days with a tap, dashed for today
/// before the first tap, outlined for missed days and blank for the future.
struct WeekFlameStrip: View {
    let days: [ActivityStreak.WeekDay]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days) { day in
                VStack(spacing: 5) {
                    Text(day.label)
                        .font(AppTypography.caption)
                        .foregroundColor(day.isToday ? AppColors.streak : AppColors.textTertiary)
                    circle(for: day.state)
                        .frame(width: 34, height: 34)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days.filter { $0.state == .done }.count) of 7 days logged this week")
    }

    @ViewBuilder
    private func circle(for state: ActivityStreak.DayState) -> some View {
        switch state {
        case .done:
            Circle()
                .fill(AppColors.streak)
                .overlay(Circle().strokeBorder(AppColors.streakEdge, lineWidth: 2))
                .overlay(flame(filled: true).foregroundColor(AppColors.onAccent))
        case .pendingToday:
            Circle()
                .fill(AppColors.backgroundCard)
                .overlay(Circle().strokeBorder(AppColors.streak, style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
                .overlay(flame(filled: false).foregroundColor(AppColors.streak))
        case .missed:
            Circle()
                .fill(AppColors.backgroundCard)
                .overlay(Circle().strokeBorder(AppColors.track, lineWidth: 2))
                .overlay(flame(filled: false).foregroundColor(AppColors.textTertiary))
        case .future:
            Circle().fill(AppColors.track)
        }
    }

    private func flame(filled: Bool) -> some View {
        Image(systemName: filled ? "flame.fill" : "flame")
            .font(AppTypography.iconSmall)
    }
}

#Preview("Light") {
    HomeView(selectedTab: .constant(0))
        .modelContainer(ModelContainer.createMockContainer())
}

#Preview("Dark") {
    HomeView(selectedTab: .constant(0))
        .modelContainer(ModelContainer.createMockContainer())
        .preferredColorScheme(.dark)
}
