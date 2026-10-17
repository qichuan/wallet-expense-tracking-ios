//
//  SpendingDeltaLabel.swift
//  CardPulse
//

import SwiftUI

struct SpendingDeltaLabel: View {
    let current: Double
    let previous: Double
    let previousLabel: String

    private var delta: Double? {
        guard previous > 0 else { return nil }
        return (current - previous) / previous
    }

    private var color: Color {
        guard let d = delta else { return AppColors.textSecondary }
        // "Spent less" is green (good), "spent more" is amber (careful).
        if d < 0 { return AppColors.statusHitText }
        if d > 0 { return AppColors.statusBehindText }
        return AppColors.textSecondary
    }

    private var icon: String? {
        guard let d = delta else { return nil }
        if d < 0 { return "arrow.down" }
        if d > 0 { return "arrow.up" }
        return nil
    }

    private var text: String {
        guard let d = delta else {
            return previousLabel.isEmpty ? "" : "No data for \(previousLabel)"
        }
        let pct = Int((abs(d) * 100).rounded())
        if pct == 0 { return "Same as \(previousLabel)" }
        return "\(pct)% \(d < 0 ? "less" : "more") than \(previousLabel)"
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(AppTypography.deltaIcon)
            }
            Text(text)
                .font(AppTypography.deltaText)
        }
        .foregroundColor(color)
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(Capsule().fill(AppColors.backgroundCard))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        SpendingDeltaLabel(current: 880, previous: 1000, previousLabel: "October")
        SpendingDeltaLabel(current: 1200, previous: 1000, previousLabel: "October")
        SpendingDeltaLabel(current: 1000, previous: 0, previousLabel: "October")
    }
    .padding()
    .background(AppColors.accent)
}
