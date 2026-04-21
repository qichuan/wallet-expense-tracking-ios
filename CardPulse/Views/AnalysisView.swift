//
//  AnalysisView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData
import Charts

struct AnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var cards: [Card]
    @Query(sort: \SpendingCategory.sortOrder) private var categoryRecords: [SpendingCategory]

    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()

    private var cachedRates: [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: exchangeRatesData)) ?? [:]
    }

    private func amountInDefault(_ tx: Transaction) -> Double {
        let code = tx.resolvedCurrency
        let raw = Double(truncating: tx.amount as NSDecimalNumber)
        guard code != defaultCurrencyCode, let rate = cachedRates[code] else { return raw }
        return raw * rate
    }

    enum Granularity: String, CaseIterable, Hashable {
        case day, week, month, year
        var title: String {
            switch self {
            case .day: return "Day"
            case .week: return "Week"
            case .month: return "Month"
            case .year: return "Year"
            }
        }
    }

    @State private var selectedGranularity: Granularity = .month
    @State private var selectedDate: Date = Date()
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedTransaction: Transaction?

    // MARK: - Ranges

    private func currentRange(for date: Date, granularity: Granularity) -> (Date, Date) {
        let cal = Calendar.current
        switch granularity {
        case .day:
            let start = cal.startOfDay(for: date)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? date
            return (start, end)
        case .week:
            let interval = cal.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 24 * 3600)
            return (interval.start, interval.end)
        case .month:
            let interval = cal.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 30 * 24 * 3600)
            return (interval.start, interval.end)
        case .year:
            let interval = cal.dateInterval(of: .year, for: date) ?? DateInterval(start: date, duration: 365 * 24 * 3600)
            return (interval.start, interval.end)
        }
    }

    private var canGoForward: Bool {
        let (_, end) = currentRange(for: selectedDate, granularity: selectedGranularity)
        return end <= Date()
    }

    private func previousDate(from date: Date, granularity: Granularity) -> Date {
        let cal = Calendar.current
        switch granularity {
        case .day:   return cal.date(byAdding: .day, value: -1, to: date) ?? date
        case .week:  return cal.date(byAdding: .weekOfYear, value: -1, to: date) ?? date
        case .month: return cal.date(byAdding: .month, value: -1, to: date) ?? date
        case .year:  return cal.date(byAdding: .year, value: -1, to: date) ?? date
        }
    }

    private var currentTotal: Double {
        let (start, end) = currentRange(for: selectedDate, granularity: selectedGranularity)
        return transactions
            .filter { $0.date >= start && $0.date < end }
            .reduce(0.0) { $0 + amountInDefault($1) }
    }

    private var previousTotal: Double {
        let prevDate = previousDate(from: selectedDate, granularity: selectedGranularity)
        let (start, end) = currentRange(for: prevDate, granularity: selectedGranularity)
        return transactions
            .filter { $0.date >= start && $0.date < end }
            .reduce(0.0) { $0 + amountInDefault($1) }
    }

    private var previousPeriodLabel: String {
        let df = DateFormatter()
        let prevDate = previousDate(from: selectedDate, granularity: selectedGranularity)
        switch selectedGranularity {
        case .day:   df.dateFormat = "d MMM"
        case .week:  df.dateFormat = "d MMM"
        case .month: df.dateFormat = "MMMM"
        case .year:  df.dateFormat = "yyyy"
        }
        return df.string(from: prevDate)
    }

    private var filteredTransactions: [Transaction] {
        let (start, end) = currentRange(for: selectedDate, granularity: selectedGranularity)
        return transactions.filter { $0.date >= start && $0.date < end }
    }

    private var sortedFilteredTransactions: [Transaction] {
        filteredTransactions.sorted { $0.date > $1.date }
    }

    // MARK: - Donut data

    /// Category string as it should appear in analytics groupings:
    /// - matches a `SpendingCategory` record → use its stored name
    /// - no match and raw is empty/nil → "Other"
    /// - no match but raw is non-empty → raw (preserves legacy/orphan names)
    private func groupingCategory(for tx: Transaction) -> String {
        let raw = tx.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty { return "Other" }
        if let match = categoryRecords.first(where: { $0.name.caseInsensitiveCompare(raw) == .orderedSame }) {
            return match.name
        }
        return raw
    }

    private var donutSlices: [DonutSlice] {
        let grouped = Dictionary(grouping: filteredTransactions) { groupingCategory(for: $0) }
        return grouped.map { category, txns in
            let total = txns.reduce(0.0) { $0 + amountInDefault($1) }
            return DonutSlice(
                category: category,
                amount: Decimal(total),
                color: MerchantUtils.color(for: category, in: categoryRecords)
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    // MARK: - Stacked chart

    struct StackedItem: Identifiable {
        let id = UUID()
        let bucketLabel: String
        let category: String
        let amount: Double
    }

    private var stackedSeries: [StackedItem] {
        let cal = Calendar.current
        let (start, _) = currentRange(for: selectedDate, granularity: selectedGranularity)

        var bucketDates: [Date] = []
        switch selectedGranularity {
        case .day:
            if let dayStart = cal.dateInterval(of: .day, for: start)?.start {
                for h in 0..<24 {
                    if let d = cal.date(byAdding: .hour, value: h, to: dayStart) { bucketDates.append(d) }
                }
            }
        case .week:
            if let week = cal.dateInterval(of: .weekOfYear, for: start) {
                for d in 0..<7 {
                    if let date = cal.date(byAdding: .day, value: d, to: week.start) { bucketDates.append(date) }
                }
            }
        case .month:
            if let month = cal.dateInterval(of: .month, for: start) {
                for w in 0..<4 {
                    let weekStart = cal.date(byAdding: .weekOfYear, value: w, to: month.start) ?? month.start
                    bucketDates.append(weekStart)
                }
            }
        case .year:
            if let year = cal.dateInterval(of: .year, for: start) {
                for m in 0..<12 {
                    if let d = cal.date(byAdding: .month, value: m, to: year.start) { bucketDates.append(d) }
                }
            }
        }

        let formatter = DateFormatter()
        switch selectedGranularity {
        case .day: formatter.dateFormat = "HH"
        case .week: formatter.dateFormat = "EEE"
        case .month: formatter.dateFormat = "EEE"
        case .year: formatter.dateFormat = "MMM"
        }

        var result: [StackedItem] = []
        for (index, bucketStart) in bucketDates.enumerated() {
            let bucketEnd: Date
            switch selectedGranularity {
            case .day: bucketEnd = cal.date(byAdding: .hour, value: 1, to: bucketStart) ?? bucketStart
            case .week: bucketEnd = cal.date(byAdding: .day, value: 1, to: bucketStart) ?? bucketStart
            case .month: bucketEnd = cal.date(byAdding: .weekOfYear, value: 1, to: bucketStart) ?? bucketStart
            case .year: bucketEnd = cal.date(byAdding: .month, value: 1, to: bucketStart) ?? bucketStart
            }

            let label: String
            switch selectedGranularity {
            case .month: label = "W\(index + 1)"
            default: label = formatter.string(from: bucketStart)
            }

            let bucketTx = filteredTransactions.filter { $0.date >= bucketStart && $0.date < bucketEnd }
            let byCategory = Dictionary(grouping: bucketTx) { groupingCategory(for: $0) }

            let seriesCategories = categoryRecords.isEmpty
                ? MerchantUtils.defaultCategories
                : categoryRecords.map { $0.name }
            for cat in seriesCategories {
                let total = byCategory[cat]?.reduce(0.0) { $0 + amountInDefault($1) } ?? 0.0
                result.append(StackedItem(bucketLabel: label, category: cat, amount: total))
            }
        }
        return result
    }

    private var stackedXAxisValues: [String] {
        stackedSeries.map { $0.bucketLabel }.uniqued()
    }

    private var stackedTitle: String {
        switch selectedGranularity {
        case .day: return "By Hour"
        case .week: return "By Day"
        case .month: return "By Week"
        case .year: return "By Month"
        }
    }

    // MARK: - Step navigation

    private func step(_ delta: Int) {
        let cal = Calendar.current
        let candidate: Date = {
            switch selectedGranularity {
            case .day: return cal.date(byAdding: .day, value: delta, to: selectedDate) ?? selectedDate
            case .week: return cal.date(byAdding: .weekOfYear, value: delta, to: selectedDate) ?? selectedDate
            case .month: return cal.date(byAdding: .month, value: delta, to: selectedDate) ?? selectedDate
            case .year: return cal.date(byAdding: .year, value: delta, to: selectedDate) ?? selectedDate
            }
        }()
        selectedDate = candidate
    }

    private var centralDateLabel: String {
        let df = DateFormatter()
        switch selectedGranularity {
        case .day:
            df.dateFormat = "d MMMM yyyy"
        case .week:
            let (s, e) = currentRange(for: selectedDate, granularity: .week)
            let f = DateFormatter()
            f.dateFormat = "d MMM"
            let end = Calendar.current.date(byAdding: .day, value: -1, to: e) ?? e
            return "\(f.string(from: s)) – \(f.string(from: end))"
        case .month:
            df.dateFormat = "MMMM yyyy"
        case .year:
            df.dateFormat = "yyyy"
        }
        return df.string(from: selectedDate)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        BrandHeader(title: "Analysis")

                        SegmentedPillControl(
                            selection: $selectedGranularity,
                            options: Granularity.allCases,
                            title: { $0.title }
                        )
                        .padding(.horizontal, 20)

                        dateNavigator
                            .padding(.horizontal, 20)

                        totalSpendCard
                            .padding(.horizontal, 20)

                        donutCard
                            .padding(.horizontal, 20)

                        if selectedGranularity == .day {
                            dayTransactionsCard
                                .padding(.horizontal, 20)
                        } else {
                            stackedBarCard
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                let cal = Calendar.current
                if let latest = transactions.map({ cal.startOfDay(for: $0.date) }).max() {
                    selectedDate = latest
                }
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionFormView(transaction: transaction)
            }
        }
    }

    @ViewBuilder
    private var dateNavigator: some View {
        HStack(spacing: 12) {
            Button(action: { step(-1) }) {
                Image(systemName: "chevron.left")
                    .font(AppTypography.navChevron)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(centralDateLabel)
                .font(AppTypography.navLabel)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Button(action: { step(1) }) {
                Image(systemName: "chevron.right")
                    .font(AppTypography.navChevron)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1.0 : 0.3)
        }
    }

    @ViewBuilder
    private var totalSpendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Total Spend")
            Text("\(CurrencyUtils.symbol(for: defaultCurrencyCode))\(currentTotal, specifier: "%.2f")")
                .font(AppTypography.amountHero)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            SpendingDeltaLabel(current: currentTotal, previous: previousTotal, previousLabel: previousPeriodLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: 18)
    }

    @ViewBuilder
    private var donutCard: some View {
        if filteredTransactions.isEmpty {
            emptyCard(message: "No transactions in this range")
        } else {
            HStack(alignment: .center, spacing: 16) {
                DonutChartView(slices: donutSlices, lineWidth: 14)
                    .frame(width: 130, height: 130)

                VStack(spacing: 8) {
                    ForEach(donutSlices.prefix(6)) { slice in
                        categoryRow(slice)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .cardSurface(padding: 18)
        }
    }

    @ViewBuilder
    private func categoryRow(_ slice: DonutSlice) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(slice.color)
                .frame(width: 8, height: 8)
            Text(slice.category)
                .font(AppTypography.bannerBody)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Text("\(CurrencyUtils.symbol(for: defaultCurrencyCode))\(Double(truncating: slice.amount as NSDecimalNumber), specifier: "%.0f")")
                .font(AppTypography.bannerCTA)
                .foregroundColor(AppColors.textPrimary)
        }
    }

    @ViewBuilder
    private var stackedBarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: stackedTitle)
            if filteredTransactions.isEmpty {
                Text("No transactions in this range")
                    .font(AppTypography.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(stackedSeries) { item in
                    BarMark(
                        x: .value("Bucket", item.bucketLabel),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(MerchantUtils.color(for: item.category, in: categoryRecords))
                    .opacity(item.amount > 0 ? 1.0 : 0.0)
                }
                .chartLegend(.hidden)
                .frame(height: 170)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(AppColors.divider)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(CurrencyUtils.symbol(for: defaultCurrencyCode))\(Int(v))")
                            }
                        }
                        .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: stackedXAxisValues) { _ in
                        AxisValueLabel()
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
        }
        .cardSurface(padding: 18)
    }

    @ViewBuilder
    private var dayTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Transactions")
            if sortedFilteredTransactions.isEmpty {
                Text("No transactions in this range")
                    .font(AppTypography.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(sortedFilteredTransactions) { transaction in
                        Button(action: { selectedTransaction = transaction }) {
                            TransactionRow(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .cardSurface(padding: 18)
    }

    @ViewBuilder
    private func emptyCard(message: String) -> some View {
        VStack(spacing: 6) {
            Text(message)
                .font(AppTypography.footnote)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .cardSurface(padding: 18)
    }
}

#Preview {
    AnalysisView()
        .modelContainer(ModelContainer.createMockContainer())
}
