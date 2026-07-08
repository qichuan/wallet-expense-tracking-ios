//
//  AnalysisView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData
import Charts
import StoreKit

struct AnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Query private var transactions: [Transaction]
    @Query private var cards: [Card]
    @Query(sort: \SpendingCategory.sortOrder) private var categoryRecords: [SpendingCategory]

    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()
    /// Set once we've asked for an App Store review so we never re-prompt.
    /// (iOS itself rate-limits to 3 prompts / 365 days, but we want to ask
    /// at most once from this trigger.)
    @AppStorage("hasRequestedReview") private var hasRequestedReview = false

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
        case day, week, month, year, custom
        var title: String {
            switch self {
            case .day: return "Day"
            case .week: return "Week"
            case .month: return "Month"
            case .year: return "Year"
            case .custom: return "Custom"
            }
        }
    }

    @State private var selectedGranularity: Granularity = .month
    @State private var selectedDate: Date = Date()
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedTransaction: Transaction?
    @State private var showingRecap = false
    @State private var showingCardFilter = false
    /// Custom-range bounds, used only when `selectedGranularity == .custom`.
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    /// Cards included in the analysis. Empty means "all cards".
    @State private var selectedCardIDs: Set<UUID> = []

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
        case .custom:
            // Inclusive of both picked days; normalised so an inverted pick still works.
            let lower = min(customStartDate, customEndDate)
            let upper = max(customStartDate, customEndDate)
            let start = cal.startOfDay(for: lower)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: upper)) ?? upper
            return (start, end)
        }
    }

    private var canGoForward: Bool {
        let (_, end) = currentRange(for: selectedDate, granularity: selectedGranularity)
        return end <= Date()
    }

    private func previousDate(from date: Date, granularity: Granularity) -> Date {
        let cal = Calendar.current
        switch granularity {
        case .day:    return cal.date(byAdding: .day, value: -1, to: date) ?? date
        case .week:   return cal.date(byAdding: .weekOfYear, value: -1, to: date) ?? date
        case .month:  return cal.date(byAdding: .month, value: -1, to: date) ?? date
        case .year:   return cal.date(byAdding: .year, value: -1, to: date) ?? date
        case .custom: return date // unused; custom uses `previousRange` directly
        }
    }

    /// The equal-length window immediately preceding the current one, for the delta.
    private var previousRange: (Date, Date) {
        let (start, end) = currentRange(for: selectedDate, granularity: selectedGranularity)
        if selectedGranularity == .custom {
            let duration = end.timeIntervalSince(start)
            return (start.addingTimeInterval(-duration), start)
        }
        let prevDate = previousDate(from: selectedDate, granularity: selectedGranularity)
        return currentRange(for: prevDate, granularity: selectedGranularity)
    }

    /// True when `tx` belongs to the active card filter (empty selection = all cards).
    private func matchesCardFilter(_ tx: Transaction) -> Bool {
        guard !selectedCardIDs.isEmpty else { return true }
        guard let id = tx.card?.id else { return false }
        return selectedCardIDs.contains(id)
    }

    private var currentTotal: Double {
        filteredTransactions.reduce(0.0) { $0 + amountInDefault($1) }
    }

    private var previousTotal: Double {
        let (start, end) = previousRange
        return transactions
            .filter { $0.date >= start && $0.date < end && matchesCardFilter($0) }
            .reduce(0.0) { $0 + amountInDefault($1) }
    }

    private var previousPeriodLabel: String {
        if selectedGranularity == .custom { return "previous period" }
        let df = DateFormatter()
        let prevDate = previousDate(from: selectedDate, granularity: selectedGranularity)
        switch selectedGranularity {
        case .day:    df.dateFormat = "d MMM"
        case .week:   df.dateFormat = "d MMM"
        case .month:  df.dateFormat = "MMMM"
        case .year:   df.dateFormat = "yyyy"
        case .custom: return "previous period" // unreachable
        }
        return df.string(from: prevDate)
    }

    private var filteredTransactions: [Transaction] {
        let (start, end) = currentRange(for: selectedDate, granularity: selectedGranularity)
        return transactions.filter { $0.date >= start && $0.date < end && matchesCardFilter($0) }
    }

    private var sortedFilteredTransactions: [Transaction] {
        filteredTransactions.sorted { $0.date > $1.date }
    }

    /// Located transactions in the selected range, each converted to the default
    /// currency, for the embedded map. Empty when nothing in range has a coordinate
    /// (the map card is hidden in that case).
    private var mapPoints: [MapTransactionPoint] {
        filteredTransactions.compactMap { tx in
            guard let coordinate = tx.coordinate else { return nil }
            return MapTransactionPoint(coordinate: coordinate, amount: amountInDefault(tx))
        }
    }

    // MARK: - Recap

    /// The shareable recap is offered for month and year views with at least one
    /// transaction — week/day periods aren't "wrapped"-worthy.
    private var canShareRecap: Bool {
        (selectedGranularity == .month || selectedGranularity == .year) && !filteredTransactions.isEmpty
    }

    private var recapPeriodTitle: String {
        let df = DateFormatter()
        df.dateFormat = selectedGranularity == .year ? "yyyy" : "MMMM yyyy"
        return df.string(from: selectedDate)
    }

    private var recapTopMerchant: SpendingRecap.Merchant? {
        Dictionary(grouping: filteredTransactions) { $0.merchant }
            .map { SpendingRecap.Merchant(name: $0.key, amount: $0.value.reduce(0) { $0 + amountInDefault($1) }) }
            .max { $0.amount < $1.amount }
    }

    private var spendingRecap: SpendingRecap {
        let rewards = rewardSummary
        return SpendingRecap(
            periodTitle: recapPeriodTitle,
            totalSpend: currentTotal,
            currencySymbol: CurrencyUtils.symbol(for: defaultCurrencyCode),
            miles: rewards.miles,
            cashback: rewards.cashback,
            topCategories: donutSlices.prefix(3).map {
                SpendingRecap.Category(
                    name: $0.category,
                    amount: Double(truncating: $0.amount as NSDecimalNumber),
                    color: $0.color
                )
            },
            topMerchant: recapTopMerchant,
            transactionCount: filteredTransactions.count,
            placesCount: TransactionMapClustering.clusters(for: mapPoints).count,
            mapPoints: mapPoints
        )
    }

    // MARK: - Rewards summary

    /// Aggregate miles + cashback earned in the selected range, both computed on
    /// amounts FX-converted to the default currency and honouring per-category monthly
    /// caps (see `RewardCalculator.aggregate`).
    /// Recomputed on rate changes via the `exchangeRatesData` @AppStorage observation.
    private var rewardSummary: (miles: Decimal, cashback: Decimal) {
        RewardCalculator.aggregate(filteredTransactions)
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

    /// Time buckets for the stacked bar, as `(start, end, label)`. The aggregation loop
    /// is shared across granularities; only the bucketing differs.
    private func bucketDefinitions() -> [(start: Date, end: Date, label: String)] {
        let cal = Calendar.current
        let (rangeStart, rangeEnd) = currentRange(for: selectedDate, granularity: selectedGranularity)
        let formatter = DateFormatter()
        var defs: [(start: Date, end: Date, label: String)] = []

        switch selectedGranularity {
        case .day:
            formatter.dateFormat = "HH"
            let dayStart = cal.dateInterval(of: .day, for: rangeStart)?.start ?? rangeStart
            for h in 0..<24 {
                guard let s = cal.date(byAdding: .hour, value: h, to: dayStart) else { continue }
                let e = cal.date(byAdding: .hour, value: 1, to: s) ?? s
                defs.append((s, e, formatter.string(from: s)))
            }
        case .week:
            formatter.dateFormat = "EEE"
            let weekStart = cal.dateInterval(of: .weekOfYear, for: rangeStart)?.start ?? rangeStart
            for d in 0..<7 {
                guard let s = cal.date(byAdding: .day, value: d, to: weekStart) else { continue }
                let e = cal.date(byAdding: .day, value: 1, to: s) ?? s
                defs.append((s, e, formatter.string(from: s)))
            }
        case .month:
            let monthStart = cal.dateInterval(of: .month, for: rangeStart)?.start ?? rangeStart
            for w in 0..<4 {
                let s = cal.date(byAdding: .weekOfYear, value: w, to: monthStart) ?? monthStart
                let e = cal.date(byAdding: .weekOfYear, value: 1, to: s) ?? s
                defs.append((s, e, "W\(w + 1)"))
            }
        case .year:
            formatter.dateFormat = "MMM"
            let yearStart = cal.dateInterval(of: .year, for: rangeStart)?.start ?? rangeStart
            for m in 0..<12 {
                guard let s = cal.date(byAdding: .month, value: m, to: yearStart) else { continue }
                let e = cal.date(byAdding: .month, value: 1, to: s) ?? s
                defs.append((s, e, formatter.string(from: s)))
            }
        case .custom:
            defs = customBucketDefinitions(start: rangeStart, end: rangeEnd, calendar: cal)
        }
        return defs
    }

    /// Buckets a custom range into day/week/month bars depending on its span, so the bar
    /// count stays readable.
    private func customBucketDefinitions(start: Date, end: Date, calendar cal: Calendar) -> [(start: Date, end: Date, label: String)] {
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        let formatter = DateFormatter()
        let step: Calendar.Component
        let stepValue: Int
        if days <= 14 {
            formatter.dateFormat = "d MMM"; step = .day; stepValue = 1
        } else if days <= 92 {
            formatter.dateFormat = "d MMM"; step = .day; stepValue = 7
        } else {
            formatter.dateFormat = "MMM yy"; step = .month; stepValue = 1
        }

        var defs: [(start: Date, end: Date, label: String)] = []
        var s = cal.startOfDay(for: start)
        while s < end {
            let next = cal.date(byAdding: step, value: stepValue, to: s) ?? end
            defs.append((s, min(next, end), formatter.string(from: s)))
            s = next
        }
        return defs
    }

    private var stackedSeries: [StackedItem] {
        let seriesCategories = categoryRecords.isEmpty
            ? MerchantUtils.defaultCategories
            : categoryRecords.map { $0.name }

        var result: [StackedItem] = []
        for def in bucketDefinitions() {
            let bucketTx = filteredTransactions.filter { $0.date >= def.start && $0.date < def.end }
            let byCategory = Dictionary(grouping: bucketTx) { groupingCategory(for: $0) }
            for cat in seriesCategories {
                let total = byCategory[cat]?.reduce(0.0) { $0 + amountInDefault($1) } ?? 0.0
                result.append(StackedItem(bucketLabel: def.label, category: cat, amount: total))
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
        case .custom: return "Over Time"
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
            case .custom: return selectedDate // custom mode doesn't use prev/next
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
        case .custom:
            return "" // custom mode shows date pickers instead of this label
        }
        return df.string(from: selectedDate)
    }

    // MARK: - Review prompt

    /// Trigger the system review prompt the first time the user lands on
    /// Analysis with at least 10 logged transactions — by that point they've
    /// gotten enough value out of the app for the ask to feel earned.
    private func maybeRequestReview() {
        guard !hasRequestedReview, transactions.count >= 10 else { return }
        hasRequestedReview = true
        // Defer slightly so the prompt doesn't cover the just-rendered chart.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            requestReview()
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        BrandHeader(title: "Analysis") {
                            if canShareRecap {
                                Button(action: { showingRecap = true }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(AppTypography.iconLarge)
                                        .foregroundColor(AppColors.accent)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Share spending recap")
                            }
                        }

                        SegmentedPillControl(
                            selection: $selectedGranularity,
                            options: Granularity.allCases,
                            title: { $0.title }
                        )
                        .padding(.horizontal, 20)

                        dateNavigator
                            .padding(.horizontal, 20)

                        cardFilterBar

                        totalSpendCard
                            .padding(.horizontal, 20)

                        if rewardSummary.miles > 0 || rewardSummary.cashback > 0 {
                            rewardsCard
                                .padding(.horizontal, 20)
                        }

                        donutCard
                            .padding(.horizontal, 20)

                        if selectedGranularity == .day {
                            dayTransactionsCard
                                .padding(.horizontal, 20)
                        } else {
                            stackedBarCard
                                .padding(.horizontal, 20)

                            if !mapPoints.isEmpty {
                                TransactionLocationMapCard(
                                    points: mapPoints,
                                    currencySymbol: CurrencyUtils.symbol(for: defaultCurrencyCode)
                                )
                                .padding(.horizontal, 20)
                            }
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
                maybeRequestReview()
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
            }
            .sheet(isPresented: $showingRecap) {
                SpendingRecapView(recap: spendingRecap)
            }
            .sheet(isPresented: $showingCardFilter) {
                CardFilterSheet(cards: cards, selectedCardIDs: $selectedCardIDs)
            }
            .onChange(of: cards.map { $0.id }) {
                // Drop any filter selection whose card was deleted.
                selectedCardIDs = selectedCardIDs.intersection(Set(cards.map { $0.id }))
            }
        }
    }

    @ViewBuilder
    private var dateNavigator: some View {
        if selectedGranularity == .custom {
            customDateNavigator
        } else {
            presetDateNavigator
        }
    }

    @ViewBuilder
    private var presetDateNavigator: some View {
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
    private var customDateNavigator: some View {
        HStack(spacing: 10) {
            customDatePill(selection: $customStartDate)
            Text("–")
                .font(AppTypography.navLabel)
                .foregroundColor(AppColors.textSecondary)
            customDatePill(selection: $customEndDate)
        }
    }

    @ViewBuilder
    private func customDatePill(selection: Binding<Date>) -> some View {
        // Capped at today (no lower bound, so the range can't invert); an inverted
        // start/end pick is normalised in `currentRange`.
        DatePicker("", selection: selection, in: ...Date(), displayedComponents: .date)
            .labelsHidden()
            .tint(AppColors.accent)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.backgroundCard)
            )
    }

    /// Compact summary of the active card filter for the filter button.
    private var cardFilterSummary: String {
        if selectedCardIDs.isEmpty { return "All cards" }
        if selectedCardIDs.count == 1, let card = cards.first(where: { selectedCardIDs.contains($0.id) }) {
            return card.name
        }
        return "\(selectedCardIDs.count) cards"
    }

    @ViewBuilder
    private var cardFilterBar: some View {
        if cards.count >= 2 {
            Button(action: { showingCardFilter = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "creditcard")
                        .font(AppTypography.iconMedium)
                        .foregroundColor(AppColors.accent)
                    Text(cardFilterSummary)
                        .font(AppTypography.filterChip)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(AppTypography.chevronSmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.backgroundCard)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
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
    private var rewardsCard: some View {
        let summary = rewardSummary
        let symbol = CurrencyUtils.symbol(for: defaultCurrencyCode)
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Rewards Earned")
            HStack(spacing: 16) {
                if summary.miles > 0 {
                    rewardTile(
                        label: "Miles",
                        value: RewardFormatter.format(summary.miles, type: .miles, currencySymbol: symbol),
                        color: AppColors.rewardMiles
                    )
                }
                if summary.cashback > 0 {
                    rewardTile(
                        label: "Cashback",
                        value: RewardFormatter.format(summary.cashback, type: .cashback, currencySymbol: symbol),
                        color: AppColors.rewardCash
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: 18)
    }

    @ViewBuilder
    private func rewardTile(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTypography.metricLabel)
                .foregroundColor(AppColors.textTertiary)
                .tracking(1.0)
            Text(value)
                .font(AppTypography.metricValue)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
