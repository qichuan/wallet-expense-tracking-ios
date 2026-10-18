//
//  TransactionRow.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct TransactionRow: View {
    let transaction: Transaction
    /// Appends a short relative time ("Yest. 7:42 PM") to the card line.
    var showsTime: Bool = false
    /// Shows the blue "NEW" pill after the merchant name.
    var isNew: Bool = false

    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()
    @Query(sort: \SpendingCategory.sortOrder) private var categoryRecords: [SpendingCategory]

    private var merchantIcon: String {
        MerchantUtils.icon(for: transaction.category, in: categoryRecords)
    }

    private var iconColor: Color {
        MerchantUtils.color(for: transaction.category, in: categoryRecords)
    }

    private var cachedRates: [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: exchangeRatesData)) ?? [:]
    }

    private var convertedAmount: Double? {
        let code = transaction.resolvedCurrency
        guard code != defaultCurrencyCode, let rate = cachedRates[code] else { return nil }
        return Double(truncating: transaction.amount as NSDecimalNumber) * rate
    }

    private var primaryAmountText: String {
        let amountValue: Double
        let symbol: String
        if let converted = convertedAmount {
            amountValue = converted
            symbol = CurrencyUtils.symbol(for: defaultCurrencyCode)
        } else {
            amountValue = Double(truncating: transaction.amount as NSDecimalNumber)
            symbol = CurrencyUtils.symbol(for: transaction.resolvedCurrency)
        }
        return String(format: "-%@%.2f", symbol, amountValue)
    }

    private var secondaryAmountText: String? {
        if convertedAmount != nil {
            let raw = Double(truncating: transaction.amount as NSDecimalNumber)
            return String(format: "%@ %.2f", transaction.resolvedCurrency, raw)
        }
        if transaction.resolvedCurrency != defaultCurrencyCode {
            return transaction.resolvedCurrency
        }
        return nil
    }

    /// Earned reward for this transaction (formatted in the card's reward unit).
    /// `nil` if the card has no reward type or the rate evaluates to zero — we don't
    /// want to clutter the row with a "+0 miles" line.
    private var rewardText: String? {
        guard let card = transaction.card, card.rewardType != .none else { return nil }
        // Rewards are computed on the FX-converted amount, so cashback is denominated
        // in the default currency — unless no rate is cached, in which case the raw
        // amount was used and the transaction's own symbol is the honest label.
        guard let value = RewardCalculator.convertedReward(for: transaction),
              value > 0 else { return nil }
        let code = CurrencyUtils.rateToDefault(from: transaction.resolvedCurrency) != nil
            ? defaultCurrencyCode
            : transaction.resolvedCurrency
        let symbol = CurrencyUtils.symbol(for: code)
        return "+" + RewardFormatter.format(value, type: card.rewardType, currencySymbol: symbol)
    }

    private var rewardColor: Color {
        switch transaction.card?.rewardType ?? .none {
        case .miles: return AppColors.rewardMiles
        case .cashback: return AppColors.rewardCash
        case .none: return AppColors.textTertiary
        }
    }

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }()

    private static let weekdayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        return df
    }()

    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "d MMM"
        return df
    }()

    private var timeText: String {
        let calendar = Calendar.current
        let date = transaction.date
        let time = Self.timeFormatter.string(from: date)
        if calendar.isDateInToday(date) { return time }
        if calendar.isDateInYesterday(date) { return "Yest. \(time)" }
        if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day,
           days < 7 {
            return "\(Self.weekdayFormatter.string(from: date)) \(time)"
        }
        return Self.dayFormatter.string(from: date)
    }

    private var metaText: String? {
        let parts = [transaction.card?.name, showsTime ? timeText : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(iconColor)
                .frame(width: 42, height: 42)
                .overlay(
                    // Inset bottom shade from the design's "sticker" icons.
                    Circle()
                        .strokeBorder(AppColors.innerShade, lineWidth: 3)
                        .mask(Rectangle().padding(.top, 30))
                )
                .overlay(
                    Image(systemName: merchantIcon)
                        .font(AppTypography.iconLarge)
                        .foregroundColor(AppColors.onAccent)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(transaction.merchant)
                        .font(AppTypography.rowTitle)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    if isNew {
                        Text("NEW")
                            .font(AppTypography.badgeTiny)
                            .tracking(0.5)
                            .foregroundColor(AppColors.onAccent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.accent))
                            .fixedSize()
                    }
                    if transaction.isRecurring {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(AppTypography.chevronSmall)
                            .foregroundColor(AppColors.textSecondary)
                            .accessibilityLabel("Recurring monthly")
                    }
                }

                if let metaText {
                    Text(metaText)
                        .font(AppTypography.rowMeta)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(AppTypography.rowMeta)
                        .foregroundColor(AppColors.textTertiary)
                        .italic()
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(primaryAmountText)
                    .font(AppTypography.amountTransaction)
                    .foregroundColor(AppColors.textPrimary)
                if let secondary = secondaryAmountText {
                    Text(secondary)
                        .font(AppTypography.amountTransactionAlt)
                        .foregroundColor(AppColors.textTertiary)
                }
                if let reward = rewardText {
                    Text(reward)
                        .font(AppTypography.amountTransactionAlt)
                        .foregroundColor(rewardColor)
                }
            }
        }
        .chunkyRow()
    }
}

#Preview {
    let card = Card(
        name: "DBS Altitude",
        minimumSpendingAmount: 4000,
        hasMinimumSpending: true,
        rewardType: .miles,
        minimumSpendingByDayOfMonth: 15,
        baseRewardRate: 1.4,
        roundingBlock: 5
    )

    return VStack(spacing: 8) {
        TransactionRow(transaction: Transaction(
            merchant: "Apple Store",
            amount: 999.00,
            date: Date(),
            category: "Shopping",
            card: card
        ))

        TransactionRow(transaction: Transaction(
            merchant: "Tiong Bahru Bakery",
            amount: 12.80,
            date: Date(),
            category: "Food & Drinks",
            card: card
        ), showsTime: true, isNew: true)

        TransactionRow(transaction: Transaction(
            merchant: "Grab",
            amount: 14.20,
            date: Date(),
            category: "Travel",
            card: card
        ))
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}
