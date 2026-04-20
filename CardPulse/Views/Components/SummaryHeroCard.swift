//
//  SummaryHeroCard.swift
//  CardPulse
//

import SwiftUI

struct SummaryHeroCard: View {
    let periodLabel: String       // e.g. "TOTAL MIN-SPEND · NOVEMBER"
    let totalAmount: String       // formatted, e.g. "$11,020"
    let cardsHit: String          // e.g. "1/4"
    let bonusEarned: String       // e.g. "$1,240"
    let nextDeadline: String      // e.g. "3d"
    let donutSlices: [DonutSlice]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: periodLabel)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(totalAmount)
                        .font(AppTypography.amountLarge)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(alignment: .top, spacing: 8) {
                        MetricStat(label: "Cards Hit", value: cardsHit)
                        MetricStat(label: "Bonus Earned", value: bonusEarned, valueColor: AppColors.brandGold)
                        MetricStat(label: "Next Deadline", value: nextDeadline, valueColor: AppColors.accent)
                    }
                }

                if !donutSlices.isEmpty {
                    DonutChartView(slices: donutSlices, lineWidth: 14)
                        .frame(width: 96, height: 96)
                }
            }
        }
        .cardSurface(padding: 18)
    }
}

#Preview {
    SummaryHeroCard(
        periodLabel: "TOTAL MIN-SPEND · NOVEMBER",
        totalAmount: "$11,020",
        cardsHit: "1/4",
        bonusEarned: "$1,240",
        nextDeadline: "3d",
        donutSlices: [
            DonutSlice(category: "A", amount: 700, color: AppColors.accent),
            DonutSlice(category: "B", amount: 300, color: AppColors.brandGold)
        ]
    )
    .padding()
    .background(AppColors.backgroundPrimary)
}
