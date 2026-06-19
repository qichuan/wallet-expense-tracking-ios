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
                    CardMultiSelectList(cards: cards, selectedCardIDs: $selectedCardIDs)
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
