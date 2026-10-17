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

    // MARK: - Bar chart

    /// One bar of the "By week / By day …" chart, colored like the design: the
    /// bucket containing today in accent, earlier buckets soft blue, the cheapest
    /// earlier bucket green ("THRIFTY!"), later buckets as empty track.
    struct BucketBar: Identifiable {
        enum Role { case past, current, thrifty, future }

        let id: Int
        let label: String
        let amount: Double
        let role: Role
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

    private var bucketBars: [BucketBar] {
        let now = Date()
        let defs = bucketDefinitions()
        let totals = defs.map { def in
            filteredTransactions
                .filter { $0.date >= def.start && $0.date < def.end }
                .reduce(0.0) { $0 + amountInDefault($1) }
        }
        let currentIndex = defs.firstIndex { $0.start <= now && now < $0.end }
        // Buckets before today (or every bucket, for a range entirely in the past).
        let pastIndices = defs.indices.filter { defs[$0].end <= now }
        let pastNonZero = pastIndices.filter { totals[$0] > 0 }
        let thriftyIndex = pastNonZero.count >= 2 ? pastNonZero.min { totals[$0] < totals[$1] } : nil

        return defs.indices.map { i in
            let role: BucketBar.Role
            if i == currentIndex {
                role = .current
            } else if i == thriftyIndex {
                role = .thrifty
            } else if defs[i].start > now {
                role = .future
            } else {
                role = .past
            }
            return BucketBar(id: i, label: defs[i].label, amount: totals[i], role: role)
        }
    }

    private func barColor(_ role: BucketBar.Role) -> Color {
        switch role {
        case .current: return AppColors.accent
        case .thrifty: return AppColors.statusHit
        case .past:    return AppColors.accentSoftBorder
        case .future:  return AppColors.track
        }
    }

    /// Mascot line for the selected period, from the same totals as the delta pill.
    private var recapLine: MascotCopy.Line {
        MascotCopy.recap(
            current: Decimal(currentTotal),
            previous: Decimal(previousTotal),
            previousLabel: selectedGranularity == .custom ? "the previous period" : previousPeriodLabel
        )
    }

    private var stackedTitle: String {
        switch selectedGranularity {
        case .day: return "By hour"
        case .week: return "By day"
        case .month: return "By week"
        case .year: return "By month"
        case .custom: return "Over time"
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
                    VStack(alignment: .leading, spacing: 16) {
                        BrandHeader(title: "Recap") {
                            if canShareRecap {
                                Button(action: { showingRecap = true }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(AppTypography.iconLarge)
                                        .foregroundColor(AppColors.accent)
                                        .frame(width: 38, height: 38)
                                        .background(Circle().fill(AppColors.accentSoft))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Share spending recap")
                            }
                        }

                        Group {
                            SegmentedPillControl(
                                selection: $selectedGranularity,
                                options: Granularity.allCases,
                                title: { $0.title }
                            )

                            dateNavigator

                            cardFilterBar

                            MascotSays(mood: recapLine.mood, mascotSize: 84,
                                       motion: recapLine.mood == .excited ? .jump : .bob) {
                                Text(recapLine.text)
                            }

                            totalSpendCard

                            if rewardSummary.miles > 0 || rewardSummary.cashback > 0 {
                                rewardsCard
                            }

                            donutCard

                            if selectedGranularity == .day {
                                dayTransactionsCard
                            } else {
                                stackedBarCard

                                if !mapPoints.isEmpty {
                                    TransactionLocationMapCard(
                                        points: mapPoints,
                                        currencySymbol: CurrencyUtils.symbol(for: defaultCurrencyCode)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                    .padding(.bottom, 28)
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
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: 2)
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
                .chunkyRow(padding: 10)
            }
            .buttonStyle(.plain)
        }
    }

    private var totalSpendLabel: String {
        selectedGranularity == .custom ? "Total spend" : "Total spend · \(centralDateLabel)"
    }

    @ViewBuilder
    private var totalSpendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(totalSpendLabel.uppercased())
                .font(AppTypography.sectionLabel)
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(CurrencyUtils.display(Decimal(currentTotal), code: defaultCurrencyCode, fractionDigits: 2))
                .font(AppTypography.amountHero)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if previousTotal > 0 {
                SpendingDeltaLabel(current: currentTotal, previous: previousTotal, previousLabel: previousPeriodLabel)
            }
        }
        .foregroundColor(AppColors.onAccent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chunkyFill(AppColors.accent, edge: AppColors.accentEdge)
    }

    @ViewBuilder
    private var rewardsCard: some View {
        let summary = rewardSummary
        let symbol = CurrencyUtils.symbol(for: defaultCurrencyCode)
        VStack(alignment: .leading, spacing: 12) {
            Text("Rewards earned")
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColors.textPrimary)
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
        .cardSurface()
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
            let maxAmount = donutSlices.map { Double(truncating: $0.amount as NSDecimalNumber) }.max() ?? 0
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 16) {
                    Text("Where it went")
                        .font(AppTypography.sectionTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    DonutChartView(slices: donutSlices, lineWidth: 10)
                        .frame(width: 64, height: 64)
                }
                ForEach(donutSlices.prefix(6)) { slice in
                    categoryRow(slice, maxAmount: maxAmount)
                }
            }
            .cardSurface()
        }
    }

    @ViewBuilder
    private func categoryRow(_ slice: DonutSlice, maxAmount: Double) -> some View {
        let amount = Double(truncating: slice.amount as NSDecimalNumber)
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(slice.color)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: MerchantUtils.icon(for: slice.category, in: categoryRecords))
                        .font(AppTypography.iconMedium)
                        .foregroundColor(AppColors.onAccent)
                )
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(slice.category)
                    Spacer(minLength: 8)
                    Text(CurrencyUtils.display(slice.amount, code: defaultCurrencyCode))
                }
                .font(AppTypography.rowValue)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                ChunkyProgressBar(progress: maxAmount > 0 ? amount / maxAmount : 0, color: slice.color)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var stackedBarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(stackedTitle)
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColors.textPrimary)
            if filteredTransactions.isEmpty {
                Text("No transactions in this range")
                    .font(AppTypography.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
            } else {
                let bars = bucketBars
                let symbol = CurrencyUtils.symbol(for: defaultCurrencyCode)
                Chart(bars) { bar in
                    BarMark(
                        x: .value("Bucket", bar.label),
                        y: .value("Amount", bar.amount),
                        width: .ratio(0.7)
                    )
                    .foregroundStyle(barColor(bar.role))
                    .cornerRadius(bars.count > 12 ? 3 : 8, style: .continuous)
                    .annotation(position: .top, spacing: 4) {
                        if bar.role == .thrifty {
                            Text("THRIFTY!")
                                .font(AppTypography.badgeTiny)
                                .foregroundColor(AppColors.statusHitText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.statusHitSoft))
                                .fixedSize()
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 190)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(AppColors.divider)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(symbol)\(Int(v))")
                                    .font(AppTypography.caption2)
                            }
                        }
                        .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: bars.map(\.label).uniqued()) { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(AppTypography.caption)
                                    .foregroundColor(bars.first { $0.label == label }?.role == .current
                                                     ? AppColors.accent : AppColors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .cardSurface()
    }

    @ViewBuilder
    private var dayTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Transactions")
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColors.textPrimary)
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

#Preview("Light") {
    AnalysisView()
        .modelContainer(ModelContainer.createMockContainer())
}

#Preview("Dark") {
    AnalysisView()
        .modelContainer(ModelContainer.createMockContainer())
        .preferredColorScheme(.dark)
}
