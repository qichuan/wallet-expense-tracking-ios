//
//  SummaryHeroCard.swift
//  CardPulse
//

import SwiftUI

struct SummaryHeroCard: View {
    let periodLabel: String
    let totalAmount: String
    let cardsHit: String
    let nextDeadline: String
    let donutSlices: [DonutSlice]
    let donutCenterLabel: String
    let remainingAmountText: String
    let allGoalsMet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: periodLabel)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(totalAmount)
                        .font(AppTypography.amountHero)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(alignment: .top, spacing: 8) {
                        MetricStat(label: "Cards Hit", value: cardsHit)
                        MetricStat(label: "Next Deadline", value: nextDeadline, valueColor: AppColors.accent)
                    }

                    if allGoalsMet {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.statusHit)
                            Text("All spending goals met!")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.statusHit)
                        }
                    } else {
                        Text("\(remainingAmountText) left to hit target")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                if !donutSlices.isEmpty {
                    ZStack {
                        DonutChartView(slices: donutSlices, lineWidth: 14)
                        if allGoalsMet {
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(AppColors.statusHit)
                        } else {
                            Text(donutCenterLabel)
                                .font(AppTypography.amountTarget)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 18)
                        }
                    }
                    .frame(width: 96, height: 96)
                }
            }
        }
        .cardSurface(padding: 18)
    }
}

#Preview {
    VStack(spacing: 20) {
        SummaryHeroCard(
            periodLabel: "MIN-SPEND TARGET · NOVEMBER",
            totalAmount: "$11,020",
            cardsHit: "1/4",
            nextDeadline: "3d",
            donutSlices: [
                DonutSlice(category: "Spent", amount: 700, color: AppColors.accent),
                DonutSlice(category: "Remaining", amount: 300, color: AppColors.backgroundCardSoft)
            ],
            donutCenterLabel: "$2,300",
            remainingAmountText: "$2,300",
            allGoalsMet: false
        )

        SummaryHeroCard(
            periodLabel: "MIN-SPEND TARGET · NOVEMBER",
            totalAmount: "$11,020",
            cardsHit: "4/4",
            nextDeadline: "3d",
            donutSlices: [
                DonutSlice(category: "Spent", amount: 1000, color: AppColors.statusHit)
            ],
            donutCenterLabel: "",
            remainingAmountText: "",
            allGoalsMet: true
        )
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}
