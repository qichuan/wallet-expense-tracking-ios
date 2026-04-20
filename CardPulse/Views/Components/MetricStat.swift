//
//  MetricStat.swift
//  CardPulse
//

import SwiftUI

struct MetricStat: View {
    let label: String
    let value: String
    let valueColor: Color

    init(label: String, value: String, valueColor: Color = AppColors.textPrimary) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.1)
                .foregroundColor(AppColors.textTertiary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HStack(spacing: 16) {
        MetricStat(label: "Cards Hit", value: "1/4")
        MetricStat(label: "Bonus Earned", value: "$1,240", valueColor: AppColors.brandGold)
        MetricStat(label: "Next Deadline", value: "3d", valueColor: AppColors.accent)
    }
    .padding()
    .background(AppColors.backgroundCard)
}
