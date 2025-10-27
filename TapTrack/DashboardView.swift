//
//  DashboardView.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [Card]
    @Query private var transactions: [Transaction]
    
    @State private var showingAddTransaction = false
    
    private var totalSpentThisMonth: Decimal {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        return transactions
            .filter { $0.date >= startOfMonth }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var totalSpentLastMonth: Decimal {
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let startOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? lastMonth
        let endOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.end ?? lastMonth
        
        return transactions
            .filter { $0.date >= startOfLastMonth && $0.date < endOfLastMonth }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var monthlyChange: Double {
        guard totalSpentLastMonth > 0 else { return 0 }
        let change = Double(truncating: (totalSpentThisMonth - totalSpentLastMonth) as NSDecimalNumber)
        let lastMonth = Double(truncating: totalSpentLastMonth as NSDecimalNumber)
        return (change / lastMonth) * 100
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .foregroundColor(.teal)
                                .font(.title2)
                                .frame(width: 32, height: 32)
                                .background(Color.teal.opacity(0.2))
                                .clipShape(Circle())
                            
                            Text("TapTrack")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "person.circle")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Total Spending Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Total Spending: October")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("$\(Double(truncating: totalSpentThisMonth as NSDecimalNumber), specifier: "%.2f")")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.yellow)
                                    
                                    HStack(spacing: 4) {
                                        Text("vs. Last Month")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        HStack(spacing: 2) {
                                            Image(systemName: monthlyChange >= 0 ? "arrow.up" : "arrow.down")
                                                .font(.caption)
                                            Text("\(abs(monthlyChange), specifier: "%.1f")%")
                                        }
                                        .foregroundColor(monthlyChange >= 0 ? .green : .red)
                                    }
                                }
                                
                                Spacer()
                            }
                            
                            // Spending Chart
                            WeeklySpendingChart(transactions: transactions)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    
                    // Credit Card Goals Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Credit Card Goals")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(cards) { card in
                                CardGoalRow(card: card)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Upcoming Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Upcoming")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            UpcomingItem(icon: "house.fill", title: "Rent", amount: "$2,200", dueDate: "Due Nov 1")
                            UpcomingItem(icon: "car.fill", title: "Car Payment", amount: "$450", dueDate: "Due Nov 5")
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 100)
            }
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingAddTransaction = true }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.yellow)
                                .clipShape(Circle())
                                .shadow(radius: 8)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            )
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView()
        }
    }
}

struct CardGoalRow: View {
    let card: Card
    
    var body: some View {
        HStack(spacing: 12) {
            // Bank Logo
            Circle()
                .fill(Color.white)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(card.bank.prefix(1))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(".... \(card.last4)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack {
                    ProgressView(value: card.progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: card.rewardType == "miles" ? .teal : .yellow))
                        .frame(height: 4)
                    
                    Text("$\(Double(truncating: card.currentSpent as NSDecimalNumber), specifier: "%.0f") / $\(Double(truncating: card.totalGoal as NSDecimalNumber), specifier: "%.0f")")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundColor(card.progressPercentage > 0.9 ? .yellow : .teal)
                    
                    Text(card.progressPercentage > 0.9 ? "▲ Nearing Limit" : "On Track")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct UpcomingItem: View {
    let icon: String
    let title: String
    let amount: String
    let dueDate: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.teal)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(amount)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.yellow)
            
            Text(dueDate)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct WeeklySpendingChart: View {
    let transactions: [Transaction]
    
    private var weeklyData: [WeeklyData] {
        let calendar = Calendar.current
        let now = Date()
        var data: [WeeklyData] = []
        
        for weekOffset in 0..<4 {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -3 + weekOffset, to: now) ?? now
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? now
            
            let weekSpending = transactions
                .filter { $0.date >= weekStart && $0.date <= weekEnd }
                .reduce(0) { $0 + $1.amount }
            
            data.append(WeeklyData(
                week: "W\(weekOffset + 1)",
                amount: Double(truncating: weekSpending as NSDecimalNumber)
            ))
        }
        
        return data
    }
    
    var body: some View {
        Chart(weeklyData) { data in
            AreaMark(
                x: .value("Week", data.week),
                y: .value("Amount", data.amount)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.yellow.opacity(0.3), .yellow.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            LineMark(
                x: .value("Week", data.week),
                y: .value("Amount", data.amount)
            )
            .foregroundStyle(.yellow)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .frame(height: 60)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: 1)) { _ in
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.caption)
            }
        }
    }
}

struct WeeklyData: Identifiable {
    let id = UUID()
    let week: String
    let amount: Double
}

#Preview {
    DashboardView()
        .modelContainer(ModelContainer.createMockContainer())
}
