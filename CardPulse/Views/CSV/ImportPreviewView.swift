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
    let plan: ImportPlan
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard

                    if !plan.cardsToCreate.isEmpty {
                        section(title: "Cards to be created", icon: "creditcard.fill", color: AppColors.accent) {
                            ForEach(plan.cardsToCreate, id: \.self) { name in
                                row(name)
                            }
                        }
                    }

                    if !plan.categoriesToCreate.isEmpty {
                        section(title: "Categories to be created", icon: "tag.fill", color: AppColors.accent) {
                            ForEach(plan.categoriesToCreate, id: \.self) { name in
                                row(name)
                            }
                        }
                    }

                    if !plan.currenciesToEnable.isEmpty {
                        section(title: "Currencies to be enabled", icon: "dollarsign.circle.fill", color: AppColors.statusHit) {
                            HStack(spacing: 6) {
                                ForEach(plan.currenciesToEnable, id: \.self) { code in
                                    Text(code)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.onAccent)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(AppColors.accent)
                                        .clipShape(Capsule())
                                }
                            }
                            Text("Latest exchange rates will be fetched automatically.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    if !plan.transactionRows.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Transactions to import")
                                    .font(AppTypography.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Text("\(plan.transactionRows.count)")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            LazyVStack(spacing: 8) {
                                ForEach(plan.transactionRows.prefix(10)) { row in
                                    TransactionRow(transaction: makePreviewTransaction(from: row))
                                }
                                if plan.transactionRows.count > 10 {
                                    Text("... and \(plan.transactionRows.count - 10) more")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding()
                        .background(AppColors.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                }
                .padding()
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel(); dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") { onConfirm(); dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backup Summary")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)
            HStack(spacing: 16) {
                stat("Transactions", plan.transactionRows.count)
                stat("Cards", plan.cards.count)
                stat("Categories", plan.categories.count)
                stat("Currencies", plan.currencies.count)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func stat(_ label: String, _ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(count)")
                .font(AppTypography.amountTarget)
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(color)
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func row(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.subheadline)
            .foregroundColor(AppColors.textSecondary)
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
