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
        VStack(spacing: 12) {
            // Search and Filter Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textTertiary)

                TextField("Search transactions…", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(AppColors.textPrimary)

                Button(action: { showingFilterSheet = true }) {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .foregroundColor(hasActiveFilters ? AppColors.accent : AppColors.textTertiary)
                        .font(AppTypography.iconLarge)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppColors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Transactions List
            if filteredTransactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "creditcard")
                        .font(AppTypography.iconXXLarge)
                        .foregroundColor(AppColors.textTertiary)
                    Text("No transactions found")
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.textSecondary)
                    Text("Try adjusting your search or filter")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(AppColors.backgroundPrimary)
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
