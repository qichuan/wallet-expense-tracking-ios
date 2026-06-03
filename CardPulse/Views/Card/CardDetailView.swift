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
    // Observed so the converted total recomputes when FX rates are refreshed.
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()

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

    /// Formats an original-currency amount with its own symbol and 2 decimals,
    /// e.g. "RM 50.00", for the breakdown beneath the converted total.
    private func formattedOriginal(_ amount: Decimal, currency: String) -> String {
        let n = Double(truncating: amount as NSDecimalNumber)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        let value = f.string(from: NSNumber(value: n)) ?? "0.00"
        return "\(CurrencyUtils.symbol(for: currency))\(value)"
    }

    /// Per-currency cycle spend, only kept when it adds information beyond the
    /// converted total (mixed currencies, or a single foreign currency).
    private var originalBreakdown: [(currency: String, amount: Decimal)] {
        let breakdown = card.monthlySpentByCurrency
        let isSingleDefault = breakdown.count == 1 && breakdown.first?.currency == defaultCurrencyCode
        return isSingleDefault ? [] : breakdown
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
                        } else {
                            spentOnlyCard
                                .padding(.horizontal, 20)
                        }
                        if card.rewardType != .none {
                            rewardsCard
                                .padding(.horizontal, 20)
                            if card.hasMinimumSpending && card.minimumSpendingAmount > 0 && card.remainingAmount > 0 {
                                minSpendNotice
                                    .padding(.horizontal, 20)
                            }
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
            Text(card.spendingPeriodDisplay)
                .font(AppTypography.bannerBody)
                .foregroundColor(AppColors.textSecondary)
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

            originalAmountsRow

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

    /// Lists the original per-currency amounts beneath the converted total so the
    /// user can see what the converted figure is made of. Hidden when everything is
    /// already in the default currency.
    @ViewBuilder
    private var originalAmountsRow: some View {
        let breakdown = originalBreakdown
        if !breakdown.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("Original")
                    .font(AppTypography.rowMeta)
                    .foregroundColor(AppColors.textTertiary)
                Text(breakdown.map { formattedOriginal($0.amount, currency: $0.currency) }
                        .joined(separator: "  ·  "))
                    .font(AppTypography.rowValue)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var rewardsCard: some View {
        let earned = RewardCalculator.cycleReward(for: card)
        let formattedEarned = RewardFormatter.format(earned, type: card.rewardType, currencySymbol: currencySymbol)
        let bonusCount = card.rewardRules.count
        let cap = RewardCalculator.activeCap(for: card)
        let capReached = RewardCalculator.isCapReached(for: card)
        let remaining = RewardCalculator.remainingUntilCap(for: card)

        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "* Earned This Cycle")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formattedEarned.isEmpty ? "0" : formattedEarned)
                    .font(AppTypography.amount)
                    .foregroundColor(rewardColor)
                if cap > 0 {
                    Text("/ \(RewardFormatter.format(cap, type: card.rewardType, currencySymbol: currencySymbol)) cap")
                        .font(AppTypography.rowMeta)
                        .foregroundColor(AppColors.textSecondary)
                } else if card.baseRewardRate > 0 {
                    Text(rateSubtitle(bonusCount: bonusCount))
                        .font(AppTypography.rowMeta)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if cap > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.backgroundCardSoft)
                        let pct = cap > 0 ? CGFloat(Double(truncating: earned as NSDecimalNumber) / Double(truncating: cap as NSDecimalNumber)) : 0
                        Capsule()
                            .fill(capReached ? AppColors.statusBehind : rewardColor)
                            .frame(width: geo.size.width * min(1, pct))
                    }
                }
                .frame(height: 6)

                if capReached {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.statusBehind)
                        Text("Cap reached — no more \(disclaimerUnit) this cycle")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.statusBehind)
                    }
                } else if let remaining {
                    Text("\(RewardFormatter.format(remaining, type: card.rewardType, currencySymbol: currencySymbol)) remaining until cap")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Text("* For estimation only. Refer to your card statement for the final \(disclaimerUnit) earned.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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

    @ViewBuilder
    private var spentOnlyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(currencySymbol)\(formatted(card.monthlySpent))")
                    .font(AppTypography.amountHero)
                    .foregroundColor(AppColors.textPrimary)
                Text("spent")
                    .font(AppTypography.amountTarget)
                    .foregroundColor(AppColors.textSecondary)
            }

            originalAmountsRow

            HStack(alignment: .top) {
                Spacer()
                Text("\(card.daysRemaining)d left")
                    .font(AppTypography.rowMeta)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(20)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var minSpendNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(AppColors.accent)
            Text("Rewards are only available when minimum spending of \(currencySymbol)\(formatted(card.minimumSpendingAmount)) is met.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private func rateSubtitle(bonusCount: Int) -> String {
        let base = "at \(rateDisplay)"
        guard bonusCount > 0 else { return base }
        return "\(base) + \(bonusCount) bonus\(bonusCount == 1 ? "" : "es")"
    }

    private var disclaimerUnit: String {
        switch card.rewardType {
        case .cashback: return "cashback"
        case .miles:    return "miles"
        case .none:     return "rewards"
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
