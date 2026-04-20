//
//  RewardTypePill.swift
//  CardPulse
//

import SwiftUI

struct RewardTypePill: View {
    let rewardType: RewardType

    private var color: Color {
        switch rewardType {
        case .miles:    return AppColors.rewardMiles
        case .cashback: return AppColors.rewardCash
        case .none:     return .clear
        }
    }

    private var label: String {
        switch rewardType {
        case .miles:    return "MILES"
        case .cashback: return "CASH"
        case .none:     return ""
        }
    }

    var body: some View {
        if rewardType != .none {
            Text(label)
                .font(AppTypography.pill)
                .tracking(0.8)
                .foregroundColor(AppColors.onAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(color)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    HStack {
        RewardTypePill(rewardType: .miles)
        RewardTypePill(rewardType: .cashback)
    }
    .padding()
    .background(AppColors.backgroundCard)
}
