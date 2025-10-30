//
//  ExportOptionsView.swift
//  CardPulse
//

import SwiftUI
import SwiftData

struct ExportOptionsView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onExport: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Date Range Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Date Range")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Start Date")
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("End Date")
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            DatePicker("", selection: $endDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                }
                
                // Export Button
                Button(action: { onExport() }) {
                    Text("Export CSV")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .cornerRadius(12)
                }
                .disabled(startDate > endDate)
                
                // Transactions Preview Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Transactions to Export")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(transactions.count) transactions")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading transactions...")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else if transactions.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.5))
                            Text("No transactions found in selected date range")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(transactions.prefix(10)) { transaction in
                                    TransactionRow(transaction: transaction)
                                }
                                if transactions.count > 10 {
                                    Text("... and \(transactions.count - 10) more transactions")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.top, 8)
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
            }
            .padding()
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { loadTransactions() }
        .onChange(of: startDate) { _, _ in loadTransactions() }
        .onChange(of: endDate) { _, _ in loadTransactions() }
    }
    
    private func loadTransactions() {
        isLoading = true
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        let request = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.date >= startOfDay && transaction.date < endOfDay
            }
        )
        do {
            transactions = try modelContext.fetch(request)
            isLoading = false
        } catch {
            print("Error loading transactions: \(error)")
            transactions = []
            isLoading = false
        }
    }
}


