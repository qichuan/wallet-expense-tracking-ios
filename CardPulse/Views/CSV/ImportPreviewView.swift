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
    let currency: String
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
                    .background(AppColors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        .background(AppColors.backgroundCard)
                        .foregroundColor(AppColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button("Import") { onConfirm(); dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding()
            .background(AppColors.backgroundPrimary)
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
            minimumSpendingAmount: 0,
            hasMinimumSpending: false,
            rewardType: .none,
            minimumSpendingByDayOfMonth: 1
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
            card: card,
            currency: row.currency
        )
    }
}


