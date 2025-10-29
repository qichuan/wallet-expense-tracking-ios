//
//  DashboardView.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    
    @State private var showingAddTransaction = false
    @State private var showingAllTransactions = false
    @State private var selectedTransaction: Transaction?
    
    
    private var recentTransactions: [Transaction] {
        transactions
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Latest Transactions Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Latest Transactions")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: { showingAllTransactions = true }) {
                                Text("View All")
                                    .font(.subheadline)
                                    .foregroundColor(.teal)
                            }
                        }
                        
                        if transactions.isEmpty {
                            Text("No transactions yet.")
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(recentTransactions) { transaction in
                                    Button(action: { selectedTransaction = transaction }) {
                                        TransactionRow(transaction: transaction)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
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
        .sheet(isPresented: $showingAllTransactions) {
            AllTransactionsView()
        }
        .sheet(item: $selectedTransaction) { transaction in
            EditTransactionView(transaction: transaction)
        }
    }
}


#Preview {
    HomeView()
        .modelContainer(ModelContainer.createMockContainer())
}
