//
//  TransactionDetailView.swift
//  CardPulse
//

import SwiftUI
import SwiftData

/// Read-only details for a single `Transaction`. Renders metadata plus a step-by-step
/// breakdown of how the reward (miles or cashback) was calculated, with an Edit
/// toolbar button that opens the existing form sheet.
struct TransactionDetailView: View {
    let transaction: Transaction

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SpendingCategory.sortOrder) private var categoryRecords: [SpendingCategory]
    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"

    @State private var showingEdit = false

    private var currencySymbol: String {
        CurrencyUtils.symbol(for: transaction.resolvedCurrency)
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE, d MMM yyyy"
        return df
    }()

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()

    private var amountText: String {
        let value = Double(truncating: transaction.amount as NSDecimalNumber)
        return String(format: "%@%.2f", currencySymbol, value)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        amountHero
                        detailsSection
                        if let note = transaction.note, !note.isEmpty {
                            noteSection(note)
                        }
                        if let breakdown = RewardCalculator.breakdown(for: transaction) {
                            rewardSection(breakdown)
                        }
                    }
                    .padding(.top, 18)
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
            TransactionFormView(transaction: transaction)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var amountHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Circle()
                    .fill(MerchantUtils.color(for: transaction.category, in: categoryRecords))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: MerchantUtils.icon(for: transaction.category, in: categoryRecords))
                            .font(AppTypography.iconMedium)
                            .foregroundColor(AppColors.onAccent)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.merchant)
                        .font(AppTypography.cardTitle)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    if let category = transaction.category, !category.isEmpty {
                        Text(category)
                            .font(AppTypography.rowMeta)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            Text(amountText)
                .font(AppTypography.amountHero)
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, 6)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var detailsSection: some View {
        FormSection("Details") {
            detailRow(label: "Date", value: Self.dateFormatter.string(from: transaction.date))
            FormDivider()
            detailRow(label: "Time", value: Self.timeFormatter.string(from: transaction.date))
            if let card = transaction.card {
                FormDivider()
                detailRow(label: "Card", value: card.name)
            }
            if !transaction.resolvedCurrency.isEmpty {
                FormDivider()
                detailRow(label: "Currency", value: transaction.resolvedCurrency)
            }
            if transaction.isRecurring {
                FormDivider()
                detailRow(label: "Repeats", value: "Monthly")
            }
        }
    }

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(value)
                .font(AppTypography.rowValue)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func noteSection(_ note: String) -> some View {
        FormSection("Note") {
            Text(note)
                .font(AppTypography.rowValue)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
    }

    // MARK: - Reward breakdown

    @ViewBuilder
    private func rewardSection(_ breakdown: RewardCalculator.Breakdown) -> some View {
        let earnedText = RewardFormatter.format(breakdown.reward, type: breakdown.rewardType, currencySymbol: currencySymbol)
        let earnedColor: Color = {
            switch breakdown.rewardType {
            case .miles:    return AppColors.rewardMiles
            case .cashback: return AppColors.rewardCash
            case .none:     return AppColors.textPrimary
            }
        }()

        FormSection("Reward Calculation") {
            calcRow(label: "Transaction amount",
                    value: format(amount: breakdown.amount))

            FormDivider()
            calcRow(label: roundingLabel(block: breakdown.roundingBlock),
                    value: format(amount: breakdown.rounded))

            FormDivider()
            calcRow(label: "Base rate",
                    value: format(rate: breakdown.effectiveRate, type: breakdown.rewardType))

            FormDivider()
            HStack(spacing: 12) {
                Text("Earned")
                    .font(AppTypography.rowTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(earnedText.isEmpty ? "0" : earnedText)
                    .font(AppTypography.amount)
                    .foregroundColor(earnedColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Text(formulaCaption(for: breakdown))
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private func calcRow(label: String, value: String, valueColor: Color = AppColors.textSecondary) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2)
            Spacer()
            Text(value)
                .font(AppTypography.rowValue)
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func roundingLabel(block: Decimal) -> String {
        let n = Double(truncating: block as NSDecimalNumber)
        if n <= 1 { return "Eligible amount" }
        return "Rounded down to $\(String(format: "%.0f", n)) block"
    }

    private func format(amount: Decimal) -> String {
        let value = Double(truncating: amount as NSDecimalNumber)
        return String(format: "%@%.2f", currencySymbol, value)
    }

    private func format(rate: Decimal, type: RewardType) -> String {
        let value = Double(truncating: rate as NSDecimalNumber)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 4
        f.minimumFractionDigits = 0
        let formatted = f.string(from: NSNumber(value: value)) ?? "0"
        switch type {
        case .cashback: return "\(formatted)%"
        case .miles:    return "\(formatted) mpd"
        case .none:     return formatted
        }
    }

    private func formulaCaption(for breakdown: RewardCalculator.Breakdown) -> String {
        switch breakdown.rewardType {
        case .cashback:
            return "Cashback = eligible amount × rate."
        case .miles:
            let blockValue = Double(truncating: breakdown.roundingBlock as NSDecimalNumber)
            if blockValue > 1 {
                return "Miles are calculated on the rounded-down amount, then multiplied by the rate."
            }
            return "Miles = transaction amount × rate."
        case .none:
            return ""
        }
    }
}

#Preview {
    let container = ModelContainer.createMockContainer()
    let card = Card(
        name: "DBS Altitude",
        minimumSpendingAmount: 5000,
        hasMinimumSpending: true,
        rewardType: .miles,
        minimumSpendingByDayOfMonth: 15,
        baseRewardRate: 1.4,
        roundingBlock: 5
    )
    let tx = Transaction(
        merchant: "Tiong Bahru Bakery",
        amount: 36.35,
        date: Date(),
        category: "Food & Drinks",
        note: "Saturday breakfast",
        card: card
    )
    return TransactionDetailView(transaction: tx)
        .modelContainer(container)
}
