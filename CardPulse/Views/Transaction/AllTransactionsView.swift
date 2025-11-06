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
    
    @State private var selectedTransaction: Transaction?
    @State private var searchText = ""
    
    private var filteredTransactions: [Transaction] {
        let filtered = transactions.filter { transaction in
            if !searchText.isEmpty {
                return transaction.merchant.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
        return filtered
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
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionFormView(transaction: transaction)
        }
    }
}


#Preview {
    AllTransactionsView()
        .modelContainer(ModelContainer.createMockContainer())
}
