//
//  AllTransactionsView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct AllTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    
    @State private var selectedTransaction: Transaction?
    @State private var searchText = ""
    @State private var selectedFilter = "Today"
    
    private let filterOptions = ["Today", "This Month", "Last 3 Months", "All"]
    
    private var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        let filtered = transactions.filter { transaction in
            if !searchText.isEmpty {
                return transaction.merchant.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
        
        switch selectedFilter {
        case "Today":
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
            return filtered.filter { $0.date >= startOfDay && $0.date < endOfDay }
        case "This Month":
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return filtered.filter { $0.date >= startOfMonth }
        case "Last 3 Months":
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return filtered.filter { $0.date >= threeMonthsAgo }
        default: // "All"
            return filtered
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search transactions...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(filterOptions, id: \.self) { option in
                                Button(action: { selectedFilter = option }) {
                                    Text(option)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedFilter == option ? .white : .gray)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(selectedFilter == option ? Color.teal : Color.gray.opacity(0.2))
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color(red: 0.05, green: 0.1, blue: 0.2))
                
                // Transactions List
                if filteredTransactions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No transactions found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Try adjusting your search or filter")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.05, green: 0.1, blue: 0.2))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredTransactions) { transaction in
                                Button(action: { selectedTransaction = transaction }) {
                                    TransactionRow(transaction: transaction)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                    .background(Color(red: 0.05, green: 0.1, blue: 0.2))
                }
            }
            .navigationTitle("All Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            EditTransactionView(transaction: transaction)
        }
    }
}


#Preview {
    AllTransactionsView()
        .modelContainer(ModelContainer.createMockContainer())
}
