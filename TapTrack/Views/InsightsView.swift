//
//  InsightsView.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var cards: [Card]
    
    private enum Granularity: Int, CaseIterable { case day, week, month, year }
    @State private var selectedGranularity: Granularity = .day
    @State private var selectedDate: Date = Date()
    
    private var filteredTransactions: [Transaction] {
        let (start, end) = currentRange()
        return transactions.filter { $0.date >= start && $0.date < end }
    }
    
    private var spendingByCategory: [CategorySpending] {
        let categories = Dictionary(grouping: filteredTransactions) { transaction in
            MerchantUtils.normalizedCategory(for: transaction.category)
        }
        
        return categories.map { category, transactions in
            CategorySpending(
                category: category,
                amount: transactions.reduce(0) { $0 + $1.amount },
                color: MerchantUtils.color(for: category)
            )
        }.sorted { $0.amount > $1.amount }
    }
    
    // MARK: - Period Helpers
    private func title(for g: Granularity) -> String {
        switch g {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
    
    private func currentRange() -> (Date, Date) {
        let cal = Calendar.current
        switch selectedGranularity {
        case .day:
            let start = cal.startOfDay(for: selectedDate)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? selectedDate
            return (start, end)
        case .week:
            let interval = cal.dateInterval(of: .weekOfYear, for: selectedDate) ?? DateInterval(start: selectedDate, duration: 7 * 24 * 3600)
            return (interval.start, interval.end)
        case .month:
            let interval = cal.dateInterval(of: .month, for: selectedDate) ?? DateInterval(start: selectedDate, duration: 30 * 24 * 3600)
            return (interval.start, interval.end)
        case .year:
            let interval = cal.dateInterval(of: .year, for: selectedDate) ?? DateInterval(start: selectedDate, duration: 365 * 24 * 3600)
            return (interval.start, interval.end)
        }
    }
    
    private func step(_ delta: Int) {
        let cal = Calendar.current
        let availableDates = Set(transactions.map { cal.startOfDay(for: $0.date) })
        
        var candidate: Date
        switch selectedGranularity {
        case .day:
            candidate = cal.date(byAdding: .day, value: delta, to: selectedDate) ?? selectedDate
        case .week:
            candidate = cal.date(byAdding: .weekOfYear, value: delta, to: selectedDate) ?? selectedDate
        case .month:
            candidate = cal.date(byAdding: .month, value: delta, to: selectedDate) ?? selectedDate
        case .year:
            candidate = cal.date(byAdding: .year, value: delta, to: selectedDate) ?? selectedDate
        }
        
        // Find the next available date with data
        let searchDirection = delta > 0 ? 1 : -1
        var current = candidate
        let maxAttempts = 100 // Prevent infinite loops
        var attempts = 0
        
        while !availableDates.contains(cal.startOfDay(for: current)) && attempts < maxAttempts {
            current = cal.date(byAdding: .day, value: searchDirection, to: current) ?? current
            attempts += 1
        }
        
        if availableDates.contains(cal.startOfDay(for: current)) {
            selectedDate = current
        }
    }
    
    // MARK: - Stacked Series
    struct StackedItem: Identifiable {
        let id = UUID()
        let bucketLabel: String
        let category: String
        let amount: Double
    }
    
    private var xAxisTitle: String {
        switch selectedGranularity { case .day: return "Hour"; case .week: return "Day"; case .month: return "Day"; case .year: return "Month" }
    }
    
    private var stackedXAxisValues: [String] {
        stackedSeries.map { $0.bucketLabel }.uniqued()
    }
    
    private var stackedSeries: [StackedItem] {
        let cal = Calendar.current
        let (start, end) = currentRange()
        
        // Define buckets based on granularity
        var bucketDates: [Date] = []
        switch selectedGranularity {
        case .day:
            if let dayStart = cal.dateInterval(of: .day, for: start)?.start {
                for h in 0..<24 { bucketDates.append(cal.date(byAdding: .hour, value: h, to: dayStart)!) }
            }
        case .week:
            if let week = cal.dateInterval(of: .weekOfYear, for: start) {
                for d in 0..<7 { bucketDates.append(cal.date(byAdding: .day, value: d, to: week.start)!) }
            }
        case .month:
            if let month = cal.dateInterval(of: .month, for: start) {
                let days = cal.range(of: .day, in: .month, for: start)?.count ?? 30
                for d in 0..<days { bucketDates.append(cal.date(byAdding: .day, value: d, to: month.start)!) }
            }
        case .year:
            if let year = cal.dateInterval(of: .year, for: start) {
                for m in 0..<12 { bucketDates.append(cal.date(byAdding: .month, value: m, to: year.start)!) }
            }
        }
        
        let formatter = DateFormatter()
        switch selectedGranularity {
        case .day: formatter.dateFormat = "HH" // 00-23
        case .week: formatter.dateFormat = "EEE" // Mon-Sun
        case .month: formatter.dateFormat = "d" // 1-31
        case .year: formatter.dateFormat = "MMM" // Jan-Dec
        }
        
        // Aggregate amounts per bucket per category
        var result: [StackedItem] = []
        for bucketStart in bucketDates {
            let bucketEnd: Date
            switch selectedGranularity {
            case .day: bucketEnd = cal.date(byAdding: .hour, value: 1, to: bucketStart) ?? bucketStart
            case .week: bucketEnd = cal.date(byAdding: .day, value: 1, to: bucketStart) ?? bucketStart
            case .month: bucketEnd = cal.date(byAdding: .day, value: 1, to: bucketStart) ?? bucketStart
            case .year: bucketEnd = cal.date(byAdding: .month, value: 1, to: bucketStart) ?? bucketStart
            }
            let label = formatter.string(from: bucketStart)
            let bucketTx = filteredTransactions.filter { $0.date >= bucketStart && $0.date < bucketEnd }
            let byCategory = Dictionary(grouping: bucketTx) { MerchantUtils.normalizedCategory(for: $0.category) }
            for cat in MerchantUtils.defaultCategories {
                let total = byCategory[cat]?.reduce(Decimal(0)) { $0 + $1.amount } ?? 0
                let amount = Double(truncating: total as NSDecimalNumber)
                guard amount > 0 else { continue }
                result.append(StackedItem(bucketLabel: label, category: cat, amount: amount))
            }
        }
        return result
    }

    // For UI: adjust series/x-axis for current granularity
    private var stackedSeriesForCurrentGranularity: [StackedItem] {
        if selectedGranularity == .day {
            // Collapse to a single bucket (the selected date) with stacked categories
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            let label = df.string(from: Calendar.current.startOfDay(for: selectedDate))
            let byCategory = Dictionary(grouping: filteredTransactions) { MerchantUtils.normalizedCategory(for: $0.category) }
            return MerchantUtils.defaultCategories.compactMap { cat in
                let total = byCategory[cat]?.reduce(Decimal(0)) { $0 + $1.amount } ?? 0
                let amount = Double(truncating: total as NSDecimalNumber)
                return amount > 0 ? StackedItem(bucketLabel: label, category: cat, amount: amount) : nil
            }
        }
        return stackedSeries
    }

    private var stackedXAxisValuesForCurrentGranularity: [String] {
        if selectedGranularity == .day {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            let label = df.string(from: Calendar.current.startOfDay(for: selectedDate))
            return [label]
        }
        return stackedXAxisValues
    }

    // Limit selectable dates to those with data
    private func availableDateRange() -> ClosedRange<Date> {
        let dates = transactions.map { Calendar.current.startOfDay(for: $0.date) }
        guard let min = dates.min(), let max = dates.max() else {
            let today = Calendar.current.startOfDay(for: Date())
            return today...today
        }
        return min...max
    }
    
    private var monthlyTrends: [MonthlyTrend] {
        let calendar = Calendar.current
        let now = Date()
        var trends: [MonthlyTrend] = []
        
        for monthOffset in 0..<3 {
            let month = calendar.date(byAdding: .month, value: -2 + monthOffset, to: now) ?? now
            let monthName = DateFormatter().monthSymbols[calendar.component(.month, from: month) - 1].prefix(3).uppercased()
            
            let monthSpending = filteredTransactions
                .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
                .reduce(0) { $0 + $1.amount }
            
            trends.append(MonthlyTrend(
                month: String(monthName),
                amount: Double(truncating: monthSpending as NSDecimalNumber)
            ))
        }
        
        return trends
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        
                        Text("Spending Analysis")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Period Tabs + Navigation
                    VStack(spacing: 12) {
                        HStack(spacing: 0) {
                            ForEach(Granularity.allCases, id: \.self) { g in
                                Button(action: { selectedGranularity = g }) {
                                    Text(title(for: g))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(selectedGranularity == g ? .white : .white.opacity(0.7))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedGranularity == g ? Color.teal : Color.clear)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            Button(action: { step(-1) }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.white)
                            }
                            
                            DatePicker("", selection: $selectedDate, in: availableDateRange(), displayedComponents: .date)
                                .labelsHidden()
                                .colorScheme(.dark)
                            
                            Button(action: { step(1) }) {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Spending Breakdown Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Spending Breakdown")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            // Donut Chart
                            ZStack {
                                DonutChart(data: spendingByCategory)
                                    .frame(height: 240) // Bigger circle
                                
                                VStack(spacing: 4) {
                                    Text("Total Spent")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text("$\(Double(truncating: filteredTransactions.reduce(0) { $0 + $1.amount } as NSDecimalNumber), specifier: "%.2f")")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Category List
                            LazyVStack(spacing: 8) {
                                ForEach(spendingByCategory) { category in
                                    CategoryRow(category: category)
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Stacked Bar Chart for Selected Period
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Spending Over Time")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            Chart(stackedSeriesForCurrentGranularity) { item in
                                BarMark(
                                    x: .value(xAxisTitle, item.bucketLabel),
                                    y: .value("Amount", item.amount)
                                )
                                .foregroundStyle(MerchantUtils.color(for: item.category))
                            }
                            .chartLegend(.hidden)
                            .frame(height: 180)
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine()
                                    AxisValueLabel() { if let v = value.as(Double.self) { Text("$\(v, specifier: "%.0f")") } }
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: stackedXAxisValuesForCurrentGranularity) { val in
                                    AxisValueLabel()
                                        .foregroundStyle(.white.opacity(0.7))
                                        .font(.caption)
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100)
            }
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            .onAppear {
                let cal = Calendar.current
                if let latest = transactions.map({ cal.startOfDay(for: $0.date) }).max() {
                    selectedDate = latest
                }
            }
        }
    }
}

struct CategorySpending: Identifiable {
    let id = UUID()
    let category: String
    let amount: Decimal
    let color: Color
}

struct MonthlyTrend: Identifiable {
    let id = UUID()
    let month: String
    let amount: Double
}

struct DonutChart: View {
    let data: [CategorySpending]
    
    private var totalAmount: Double {
        Double(truncating: data.reduce(0) { $0 + $1.amount } as NSDecimalNumber)
    }
    
    private var segments: [(start: Double, end: Double, color: Color)] {
        guard totalAmount > 0 else { return [] }
        var cumulative: Double = 0
        return data.map { item in
            let value = Double(truncating: item.amount as NSDecimalNumber)
            let fraction = value / totalAmount
            let start = cumulative
            let end = cumulative + fraction
            cumulative = end
            return (start: start, end: end, color: item.color)
        }
    }
    
    var body: some View {
        ZStack {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                Circle()
                    .trim(from: seg.start, to: seg.end)
                    .stroke(seg.color, style: StrokeStyle(lineWidth: 12, lineCap: .butt, lineJoin: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

struct CategoryRow: View {
    let category: CategorySpending
    
    private var categoryIcon: String {
        MerchantUtils.icon(for: category.category)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(category.color)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: categoryIcon)
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            Text(category.category)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Text("$\(Double(truncating: category.amount as NSDecimalNumber), specifier: "%.2f")")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    InsightsView()
        .modelContainer(ModelContainer.createMockContainer())
}

