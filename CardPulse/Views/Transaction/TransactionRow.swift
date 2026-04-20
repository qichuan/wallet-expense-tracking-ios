//
//  TransactionRow.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "d MMM"
        return df
    }()

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()

    private var merchantIcon: String {
        MerchantUtils.icon(for: transaction.category)
    }

    private var iconColor: Color {
        MerchantUtils.color(for: transaction.category)
    }

    private var cachedRates: [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: exchangeRatesData)) ?? [:]
    }

    private var convertedAmount: Double? {
        let code = transaction.resolvedCurrency
        guard code != defaultCurrencyCode, let rate = cachedRates[code] else { return nil }
        return Double(truncating: transaction.amount as NSDecimalNumber) * rate
    }

    private var subtitle: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let txDay = cal.startOfDay(for: transaction.date)
        let daysAgo = cal.dateComponents([.day], from: txDay, to: today).day ?? 0

        let dayLabel: String
        switch daysAgo {
        case 0: dayLabel = "Today"
        case 1: dayLabel = "Yesterday"
        default: dayLabel = Self.dateFormatter.string(from: transaction.date)
        }

        let time = Self.timeFormatter.string(from: transaction.date)
        let label = "\(dayLabel) \(time)"

        if let card = transaction.card {
            return "\(card.name)  ·  \(label)"
        }
        return label
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

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(iconColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: merchantIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchant)
                    .font(AppTypography.rowTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)

                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                        .italic()
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(primaryAmountText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                if let secondary = secondaryAmountText {
                    Text(secondary)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    let card = Card(
        name: "DBS Altitude",
        minimumSpendingAmount: 4000,
        hasMinimumSpending: true,
        rewardType: .miles,
        minimumSpendingByDayOfMonth: 15
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
        ))

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
