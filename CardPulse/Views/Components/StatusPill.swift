//
//  StatusPill.swift
//  CardPulse
//

import SwiftUI

struct StatusPill: View {
    let status: CardStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(AppTypography.chevronSmall)
            Text(status.label.uppercased())
                .font(AppTypography.pill)
        }
        .foregroundColor(status.textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(status.softColor))
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
