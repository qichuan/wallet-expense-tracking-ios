//
//  DonutChartView.swift
//  CardPulse
//

import SwiftUI

struct DonutSlice: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let amount: Decimal
    let color: Color
}

struct DonutChartView: View {
    let slices: [DonutSlice]
    var lineWidth: CGFloat = 16

    private var total: Double {
        Double(truncating: slices.reduce(0) { $0 + $1.amount } as NSDecimalNumber)
    }

    private var segments: [(start: Double, end: Double, color: Color)] {
        guard total > 0 else { return [] }
        var cursor: Double = 0
        return slices.map { slice in
            let value = Double(truncating: slice.amount as NSDecimalNumber)
            let fraction = value / total
            let start = cursor
            cursor += fraction
            return (start, cursor, slice.color)
        }
    }

    var body: some View {
        ZStack {
            // Track circle
            Circle()
                .stroke(AppColors.backgroundCardSoft, lineWidth: lineWidth)

            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                Circle()
                    .trim(from: seg.start, to: seg.end)
                    .stroke(
                        seg.color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

#Preview {
    DonutChartView(slices: [
        DonutSlice(category: "Food", amount: 412, color: AppColors.categoryFoodDrinks),
        DonutSlice(category: "Shopping", amount: 310, color: AppColors.categoryShopping),
        DonutSlice(category: "Travel", amount: 232, color: AppColors.categoryTravel),
        DonutSlice(category: "Entertainment", amount: 155, color: AppColors.categoryEntertainment)
    ])
    .frame(width: 160, height: 160)
    .padding()
    .background(AppColors.backgroundCard)
}
