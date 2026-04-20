//
//  StatusPill.swift
//  CardPulse
//

import SwiftUI

struct StatusPill: View {
    let status: CardStatus

    var body: some View {
        Text(status.label)
            .font(AppTypography.pill)
            .tracking(0.5)
            .foregroundColor(status.color)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        StatusPill(status: .hit)
        StatusPill(status: .onTrack)
        StatusPill(status: .behind)
    }
    .padding()
    .background(AppColors.backgroundCard)
}
