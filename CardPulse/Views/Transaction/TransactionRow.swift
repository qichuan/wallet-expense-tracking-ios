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
        df.dateFormat = "d MMM yyyy"
        return df
    }()

    private var merchantIcon: String {
        MerchantUtils.icon(for: transaction.category)
    }

    private var iconColor: Color {
        MerchantUtils.color(for: transaction.category)
    }

    private var dateDisplayString: String {
        let calendar = Calendar.current
        let now = Date()
        let transactionStartOfDay = calendar.startOfDay(for: transaction.date)
        let todayStartOfDay = calendar.startOfDay(for: now)
        let yesterdayStartOfDay = calendar.date(byAdding: .day, value: -1, to: todayStartOfDay) ?? todayStartOfDay

        if transactionStartOfDay == todayStartOfDay {
            return "Today"
        } else if transactionStartOfDay == yesterdayStartOfDay {
            return "Yesterday"
        } else {
            return Self.dateFormatter.string(from: transaction.date)
        }
    }

    private var cachedRates: [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: exchangeRatesData)) ?? [:]
    }

    /// Converted amount in the default currency, or nil if same currency / no rate cached.
    private var convertedAmount: Double? {
        let code = transaction.resolvedCurrency
        guard code != defaultCurrencyCode, let rate = cachedRates[code] else { return nil }
        return Double(truncating: transaction.amount as NSDecimalNumber) * rate
    }

    var body: some View {
        HStack(spacing: 12) {
            // Merchant Icon
            Circle()
                .fill(iconColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: merchantIcon)
                        .font(.headline)
                        .foregroundColor(.white)
                )

            // Transaction Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant)
                    .font(.headline)
                    .foregroundColor(.white)

                if let card = transaction.card {
                    Label(card.name, systemImage: "creditcard")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                HStack(spacing: 8) {
                    Text(dateDisplayString)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Text(transaction.date, style: .time)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .italic()
                        .lineLimit(2)
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                if let converted = convertedAmount {
                    Text("-\(CurrencyUtils.symbol(for: defaultCurrencyCode))\(converted, specifier: "%.2f")")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("\(transaction.resolvedCurrency) \(Double(truncating: transaction.amount as NSDecimalNumber), specifier: "%.2f")")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Text("-\(CurrencyUtils.symbol(for: transaction.resolvedCurrency))\(Double(truncating: transaction.amount as NSDecimalNumber), specifier: "%.2f")")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    if transaction.resolvedCurrency != defaultCurrencyCode {
                        Text(transaction.resolvedCurrency)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    let card = Card(
        name: "Chase Sapphire Preferred",
        minimumSpendingAmount: 4000,
        hasMinimumSpending: true,
        rewardType: .miles,
        minimumSpendingByDayOfMonth: 15
    )

    VStack {
        TransactionRow(transaction: Transaction(
            merchant: "Apple Store",
            amount: 999.00,
            date: Date(),
            category: "Shopping",
            card: card
        ))

        TransactionRow(transaction: Transaction(
            merchant: "Mr. DIY",
            amount: 9.00,
            date: Date(),
            category: "Other",
            card: card,
            currency: "MYR"
        ))

        TransactionRow(transaction: Transaction(
            merchant: "Netflix",
            amount: 9.00,
            date: Date(),
            category: "Entertainment",
            card: card
        ))
    }.background(Color(red: 0.05, green: 0.1, blue: 0.2)).padding()
}
