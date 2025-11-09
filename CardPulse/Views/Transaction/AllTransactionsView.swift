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
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var cards: [Card]
    
    @State private var selectedTransaction: Transaction?
    @State private var searchText = ""
    @State private var selectedCard: Card?
    @State private var showingFilterSheet = false
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var useDateRange = false
    
    private var filteredTransactions: [Transaction] {
        let filtered = transactions.filter { transaction in
            // Filter by search text
            if !searchText.isEmpty {
                if !transaction.merchant.localizedCaseInsensitiveContains(searchText) {
                    return false
                }
            }
            
            // Filter by selected card
            if let selectedCard = selectedCard {
                if transaction.card?.id != selectedCard.id {
                    return false
                }
            }
            
            // Filter by date range
            if useDateRange {
                let calendar = Calendar.current
                let transactionDate = transaction.date
                
                // Check start date - transaction must be on or after start date
                if let startDate = startDate {
                    let startOfDay = calendar.startOfDay(for: startDate)
                    if transactionDate < startOfDay {
                        return false
                    }
                }
                
                // Check end date - transaction must be on or before end date (inclusive)
                // Use the same pattern as ExportOptionsView: endOfDay is start of next day, use < comparison
                if let endDate = endDate {
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
                    if transactionDate >= endOfDay {
                        return false
                    }
                }
            }
            
            return true
        }
        return filtered
    }
    
    private var hasActiveFilters: Bool {
        selectedCard != nil || useDateRange
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search transactions...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                // Filter Icon Button
                Button(action: { showingFilterSheet = true }) {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .foregroundColor(hasActiveFilters ? .teal : .gray)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
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
                    .padding(.vertical)
                }
                .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            }
        }
        .padding()
        .sheet(item: $selectedTransaction) { transaction in
            TransactionFormView(transaction: transaction)
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheetView(
                cards: cards,
                selectedCard: $selectedCard,
                useDateRange: $useDateRange,
                startDate: $startDate,
                endDate: $endDate
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}


#Preview {
    AllTransactionsView()
        .modelContainer(ModelContainer.createMockContainer())
}
