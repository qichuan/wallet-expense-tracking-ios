//
//  CardDetailView.swift
//  CardPulse
//

import SwiftUI
import SwiftData

struct CardDetailView: View {
    let card: Card

    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"

    @State private var showingEdit = false
    @State private var selectedTransaction: Transaction?

    private var currencySymbol: String {
        CurrencyUtils.symbol(for: defaultCurrencyCode)
    }

    private var cardStatus: CardStatus {
        CardStatus.derive(progress: card.progressPercentage, pacing: cyclePacing)
    }

    private var cyclePacing: Double? {
        let start = card.currentCycleStart
        let end = card.currentCycleEnd
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return nil }
        return max(0, min(1, Date().timeIntervalSince(start) / total))
    }

    private var cycleTransactions: [Transaction] {
        card.transactions
            .filter { $0.date >= card.currentCycleStart && $0.date < card.currentCycleEnd }
            .sorted { $0.date > $1.date }
    }

    private func formatted(_ amount: Decimal) -> String {
        let n = Double(truncating: amount as NSDecimalNumber)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: n)) ?? "0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        if card.hasMinimumSpending && card.minimumSpendingAmount > 0 {
                            spendingCard
                                .padding(.horizontal, 20)
                        }
                        if card.rewardType != .none {
                            rewardsCard
                                .padding(.horizontal, 20)
                        }
                        cycleSection
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { showingEdit = true }
                        .font(AppTypography.navButton)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingEdit) {
            CardFormView(card: card)
        }
        .sheet(item: $selectedTransaction) { tx in
            TransactionDetailView(transaction: tx)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(card.name)
                    .font(AppTypography.screenTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                RewardTypePill(rewardType: card.rewardType)
                    .padding(.top, 6)
            }
            if card.hasMinimumSpending && card.minimumSpendingAmount > 0 {
                Text(card.spendingPeriodDisplay)
                    .font(AppTypography.bannerBody)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var spendingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Amounts
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(currencySymbol)\(formatted(card.monthlySpent))")
                    .font(AppTypography.amountHero)
                    .foregroundColor(AppColors.textPrimary)
                Text("/ \(currencySymbol)\(formatted(card.minimumSpendingAmount))")
                    .font(AppTypography.amountTarget)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.backgroundCardSoft)
                    Capsule()
                        .fill(cardStatus.color)
                        .frame(width: geo.size.width * CGFloat(card.progressPercentage))
                }
            }
            .frame(height: 8)

            // Status row
            HStack(alignment: .top) {
                StatusPill(status: cardStatus)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(card.daysRemaining)d left")
                        .font(AppTypography.rowMeta)
                        .foregroundColor(AppColors.textTertiary)
                    if card.remainingAmount > 0 {
                        Text("\(currencySymbol)\(formatted(card.remainingAmount)) to go")
                            .font(AppTypography.rowMeta)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(20)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var rewardsCard: some View {
        let earned = RewardCalculator.cycleReward(for: card)
        let formatted = RewardFormatter.format(earned, type: card.rewardType, currencySymbol: currencySymbol)
        let bonusCount = card.rewardRules.count

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Earned This Cycle")
                Spacer()
                if bonusCount > 0 {
                    Text("\(bonusCount) bonus\(bonusCount == 1 ? "" : "es")")
                        .font(AppTypography.rowMeta)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatted.isEmpty ? "0" : formatted)
                    .font(AppTypography.amount)
                    .foregroundColor(rewardColor)
                if card.baseRewardRate > 0 {
                    Text("at \(rateDisplay)")
                        .font(AppTypography.rowMeta)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var rewardColor: Color {
        switch card.rewardType {
        case .miles: return AppColors.rewardMiles
        case .cashback: return AppColors.rewardCash
        case .none: return AppColors.textPrimary
        }
    }

    private var rateDisplay: String {
        let n = Double(truncating: card.baseRewardRate as NSDecimalNumber)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        let value = formatter.string(from: NSNumber(value: n)) ?? "0"
        switch card.rewardType {
        case .cashback: return "\(value)%"
        case .miles: return "\(value) mpd"
        case .none: return ""
        }
    }

    @ViewBuilder
    private var cycleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "This Cycle")
                .padding(.horizontal, 20)

            if cycleTransactions.isEmpty {
                Text("No transactions this cycle")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            } else {
                GroupedTransactionList(
                    transactions: cycleTransactions,
                    onTap: { selectedTransaction = $0 }
                )
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    let container = ModelContainer.createMockContainer()
    let card = Card(
        name: "DBS Altitude Visa",
        minimumSpendingAmount: 5000,
        hasMinimumSpending: true,
        rewardType: .miles,
        minimumSpendingByDayOfMonth: 15
    )
    return CardDetailView(card: card)
        .modelContainer(container)
}
