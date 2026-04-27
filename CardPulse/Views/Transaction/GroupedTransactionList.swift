//
//  GroupedTransactionList.swift
//  CardPulse
//

import SwiftUI

struct GroupedTransactionList: View {
    let transactions: [Transaction]
    let onTap: (Transaction) -> Void

    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()

    private var cachedRates: [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: exchangeRatesData)) ?? [:]
    }

    private var grouped: [(date: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
        return dict.keys
            .sorted(by: >)
            .map { date in (date: date, transactions: dict[date]!.sorted { $0.date > $1.date }) }
    }

    private static let headerDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM d"
        return df
    }()

    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return Self.headerDateFormatter.string(from: date)
    }

    private func dayTotal(for txs: [Transaction]) -> String {
        let total = txs.reduce(0.0) { sum, tx in
            let code = tx.resolvedCurrency
            let raw = Double(truncating: tx.amount as NSDecimalNumber)
            guard code != defaultCurrencyCode, let rate = cachedRates[code] else { return sum + raw }
            return sum + raw * rate
        }
        let symbol = CurrencyUtils.symbol(for: defaultCurrencyCode)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let number = formatter.string(from: NSNumber(value: total)) ?? String(format: "%.2f", total)
        return "\(symbol)\(number)"
    }

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(grouped, id: \.date) { group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(dayLabel(for: group.date))
                            .font(AppTypography.sectionLabel)
                            .foregroundColor(AppColors.textTertiary)
                        Spacer()
                        Text(dayTotal(for: group.transactions))
                            .font(AppTypography.sectionLabel)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 8) {
                        ForEach(group.transactions) { tx in
                            Button(action: { onTap(tx) }) {
                                TransactionRow(transaction: tx)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
