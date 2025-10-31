//
//  ImportPreviewView.swift
//  CardPulse
//

import SwiftUI
import SwiftData

struct ImportPreviewRow: Identifiable {
    let id = UUID()
    let merchant: String
    let amount: String
    let category: String
    let card: String
    let date: String
    let note: String
}

struct ImportPreviewView: View {
    let rows: [ImportPreviewRow]
    let missingCards: [String]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if !missingCards.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cards to be created")
                            .font(.headline)
                            .foregroundColor(.white)
                        ForEach(missingCards, id: \.self) { name in
                            Text(name)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                VStack(spacing: 0) {
                    Text("Transactions to import: \(rows.count)")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(rows.prefix(10)) { row in
                                TransactionRow(transaction: makePreviewTransaction(from: row))
                            }
                            if rows.count > 10 {
                                Text("... and \(rows.count - 10) more transactions")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.top, 8)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    
                }
                
                HStack {
                    Button("Cancel") { onCancel(); dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    Button("Import") { onConfirm(); dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview model factories
private extension ImportPreviewView {
    func makeTempCard(name: String) -> Card {
        Card(
            name: name,
            totalGoal: 0,
            rewardType: "miles",
            statementDay: 1
        )
    }
    
    func makePreviewTransaction(from row: ImportPreviewRow) -> Transaction {
        let amount = Decimal(string: row.amount) ?? 0
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = df.date(from: row.date) ?? Date()
        let card: Card? = row.card.isEmpty ? nil : makeTempCard(name: row.card)
        return Transaction(
            merchant: row.merchant,
            amount: amount,
            date: date,
            category: row.category.isEmpty ? nil : row.category,
            note: row.note.isEmpty ? nil : row.note,
            card: card
        )
    }
}


