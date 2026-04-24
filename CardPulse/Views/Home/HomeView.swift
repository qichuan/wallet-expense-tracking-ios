//
//  HomeView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var cards: [Card]

    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()

    @State private var showingAddTransaction = false
    @State private var showingAllTransactions = false
    @State private var selectedTransaction: Transaction?

    private var cachedRates: [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: exchangeRatesData)) ?? [:]
    }

    private func amountInDefault(_ tx: Transaction) -> Double {
        let code = tx.resolvedCurrency
        let raw = Double(truncating: tx.amount as NSDecimalNumber)
        guard code != defaultCurrencyCode, let rate = cachedRates[code] else { return raw }
        return raw * rate
    }

    // MARK: - Hero metrics

    private var cardsWithGoals: [Card] {
        cards.filter { $0.hasMinimumSpending && $0.minimumSpendingAmount > 0 }
    }

    private var totalMinSpend: Decimal {
        cardsWithGoals.reduce(0) { $0 + $1.minimumSpendingAmount }
    }

    private var cardsHitCount: Int {
        cardsWithGoals.filter { $0.progressPercentage >= 1.0 }.count
    }

    private var allGoalsMet: Bool {
        !cardsWithGoals.isEmpty && cardsHitCount == cardsWithGoals.count
    }

    private var nextDeadlineCard: Card? {
        cardsWithGoals.min { $0.daysRemaining < $1.daysRemaining }
    }

    private var nextDeadlineDisplay: String {
        guard let card = nextDeadlineCard else { return "—" }
        return "\(card.daysRemaining)d"
    }

    private var cappedSpentTowardGoals: Double {
        cardsWithGoals.reduce(0.0) { partial, card in
            let spent = Double(truncating: card.monthlySpent as NSDecimalNumber)
            let target = Double(truncating: card.minimumSpendingAmount as NSDecimalNumber)
            return partial + min(spent, target)
        }
    }

    private var heroDonutSlices: [DonutSlice] {
        let totalTarget = Double(truncating: totalMinSpend as NSDecimalNumber)
        let spentForProgress = min(cappedSpentTowardGoals, totalTarget)
        let remaining = max(0.0, totalTarget - spentForProgress)

        if allGoalsMet {
            return [DonutSlice(category: "Spent", amount: Decimal(spentForProgress), color: AppColors.statusHit)]
        }
        return [
            DonutSlice(category: "Spent", amount: Decimal(spentForProgress), color: AppColors.accent),
            DonutSlice(category: "Remaining", amount: Decimal(remaining), color: AppColors.backgroundCardSoft)
        ]
    }

    private var remainingToSpendAmount: Decimal {
        let totalTarget = Double(truncating: totalMinSpend as NSDecimalNumber)
        return Decimal(max(0.0, totalTarget - cappedSpentTowardGoals))
    }

    private var remainingToSpendText: String {
        let symbol = CurrencyUtils.symbol(for: defaultCurrencyCode)
        return "\(symbol)\(formatted(remainingToSpendAmount))"
    }

    private var periodLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MMMM"
        return "MIN-SPEND TARGET · \(df.string(from: Date()).uppercased())"
    }

    private var formattedTotalMinSpend: String {
        let symbol = CurrencyUtils.symbol(for: defaultCurrencyCode)
        return "\(symbol)\(formatted(totalMinSpend))"
    }

    private func formatted(_ amount: Decimal) -> String {
        let number = Double(truncating: amount as NSDecimalNumber)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: number)) ?? "0"
    }

    private var latestTransactions: [Transaction] {
        Array(transactions.prefix(10))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        BrandHeader(title: "Home") {
                            Button(action: { showingAddTransaction = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(AppTypography.headerAction)
                                    .foregroundColor(AppColors.accent)
                            }
                        }

                        if !cardsWithGoals.isEmpty {
                            SummaryHeroCard(
                                periodLabel: periodLabel,
                                totalAmount: formattedTotalMinSpend,
                                cardsHit: "\(cardsHitCount)/\(cardsWithGoals.count)",
                                nextDeadline: nextDeadlineDisplay,
                                donutSlices: heroDonutSlices,
                                donutCenterLabel: remainingToSpendText,
                                remainingAmountText: remainingToSpendText,
                                allGoalsMet: allGoalsMet
                            )
                            .padding(.horizontal, 20)
                        }

                        if transactions.isEmpty {
                            emptyState
                        } else {
                            latestActivitySection
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
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
            TransactionFormView(transaction: tx)
        }
    }

    @ViewBuilder
    private var latestActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "Recent Transactions")
                Spacer()
                Button(action: { showingAllTransactions = true }) {
                    HStack(spacing: 4) {
                        Text("View all")
                            .font(AppTypography.bannerCTA)
                        Image(systemName: "chevron.right")
                            .font(AppTypography.chevronSmall)
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 8) {
                ForEach(latestTransactions) { tx in
                    Button(action: { selectedTransaction = tx }) {
                        TransactionRow(transaction: tx)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No transactions yet")
                .foregroundColor(AppColors.textPrimary)
                .font(AppTypography.headline)
            Text("Set up automation and see your first transaction here, or tap + to manually add one.")
                .foregroundColor(AppColors.textSecondary)
                .font(AppTypography.caption)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 40)
    }
}


#Preview {
    HomeView()
        .modelContainer(ModelContainer.createMockContainer())
}
