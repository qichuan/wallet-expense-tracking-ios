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
    
    @State private var selectedPeriod = 0
    
    private let periods = ["This Month", "Last 3 Months", "This Year"]
    
    private var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case 0: // This Month
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return transactions.filter { $0.date >= startOfMonth }
        case 1: // Last 3 Months
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return transactions.filter { $0.date >= threeMonthsAgo }
        case 2: // This Year
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return transactions.filter { $0.date >= startOfYear }
        default:
            return transactions
        }
    }
    
    private var spendingByCategory: [CategorySpending] {
        let categories = Dictionary(grouping: filteredTransactions) { transaction in
            transaction.category ?? "Other"
        }
        
        return categories.map { category, transactions in
            CategorySpending(
                category: category,
                amount: transactions.reduce(0) { $0 + $1.amount },
                color: categoryColor(for: category)
            )
        }.sorted { $0.amount > $1.amount }
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
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Text("Spending Analysis")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Goal Milestone Notification
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "person.badge.shield.checkmark")
                                .font(.title2)
                                .foregroundColor(.yellow)
                                .frame(width: 32, height: 32)
                                .background(Color.yellow.opacity(0.2))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Goal Milestone Reached!")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("You've reached 80% of your 'Dining Out' goal for June!")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Time Period Selection
                    HStack(spacing: 0) {
                        ForEach(0..<periods.count, id: \.self) { index in
                            Button(action: { selectedPeriod = index }) {
                                Text(periods[index])
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(selectedPeriod == index ? .white : .white.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedPeriod == index ? Color.teal : Color.clear)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                    
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
                                    .frame(height: 200)
                                
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
                    
                    // Monthly Trends Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Monthly Trends")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            Chart(monthlyTrends) { trend in
                                BarMark(
                                    x: .value("Month", trend.month),
                                    y: .value("Amount", trend.amount)
                                )
                                .foregroundStyle(.teal)
                                .cornerRadius(4)
                            }
                            .frame(height: 120)
                            .chartYAxis(.hidden)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: 1)) { _ in
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
        }
    }
    
    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "groceries":
            return .yellow
        case "dining out":
            return .teal
        case "transport":
            return .blue
        case "entertainment":
            return .purple
        default:
            return .gray
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
    
    private var totalAmount: Decimal {
        data.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        ZStack {
            ForEach(Array(data.enumerated()), id: \.offset) { index, category in
                let startAngle = Angle.degrees(calculateStartAngle(for: index))
                let endAngle = Angle.degrees(calculateEndAngle(for: index))
                
                SectorShape(startAngle: startAngle, endAngle: endAngle)
                    .fill(category.color)
                    .frame(width: 150, height: 150)
            }
        }
    }
    
    private func calculateStartAngle(for index: Int) -> Double {
        let previousAmount = data.prefix(index).reduce(0) { $0 + $1.amount }
        let percentage = Double(truncating: previousAmount as NSDecimalNumber) / Double(truncating: totalAmount as NSDecimalNumber)
        return percentage * 360 - 90
    }
    
    private func calculateEndAngle(for index: Int) -> Double {
        let currentAmount = data.prefix(index + 1).reduce(0) { $0 + $1.amount }
        let percentage = Double(truncating: currentAmount as NSDecimalNumber) / Double(truncating: totalAmount as NSDecimalNumber)
        return percentage * 360 - 90
    }
}

struct SectorShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        
        // Inner circle
        let innerRadius = radius * 0.6
        path.move(to: center)
        path.addArc(center: center, radius: innerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        path.closeSubpath()
        
        return path
    }
}

struct CategoryRow: View {
    let category: CategorySpending
    
    private var categoryIcon: String {
        switch category.category.lowercased() {
        case "groceries":
            return "cart"
        case "dining out":
            return "fork.knife"
        case "transport":
            return "tram"
        case "entertainment":
            return "ticket"
        default:
            return "tag"
        }
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
