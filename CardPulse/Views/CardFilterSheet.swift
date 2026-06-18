//
//  CardFilterSheet.swift
//  CardPulse
//

import SwiftUI

/// Vertical multi-select checklist for filtering the Analysis tab by card. Scales to
/// many cards and long names without horizontal scrolling. An empty `selectedCardIDs`
/// means "all cards".
struct CardFilterSheet: View {
    let cards: [Card]
    @Binding var selectedCardIDs: Set<UUID>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 8) {
                        filterRow(title: "All cards", isSelected: selectedCardIDs.isEmpty) {
                            selectedCardIDs = []
                        }

                        Divider()
                            .background(AppColors.divider)
                            .padding(.vertical, 4)

                        ForEach(cards) { card in
                            filterRow(title: card.name, isSelected: selectedCardIDs.contains(card.id)) {
                                toggle(card.id)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Filter cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func filterRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(AppTypography.rowTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 12)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(AppTypography.iconMedium)
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.backgroundCard)
            )
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ id: UUID) {
        if selectedCardIDs.contains(id) {
            selectedCardIDs.remove(id)
        } else {
            selectedCardIDs.insert(id)
        }
    }
}

#Preview {
    CardFilterSheet(
        cards: [
            Card(name: "Amex KrisFlyer Ascend", minimumSpendingAmount: 0),
            Card(name: "Citi PremierMiles World", minimumSpendingAmount: 0),
            Card(name: "UOB One Card", minimumSpendingAmount: 0)
        ],
        selectedCardIDs: .constant([])
    )
}
