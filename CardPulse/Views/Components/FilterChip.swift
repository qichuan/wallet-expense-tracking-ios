//
//  FilterChip.swift
//  CardPulse
//

import SwiftUI

struct FilterChip: View {
    let label: String
    let count: Int?
    let selected: Bool
    let action: () -> Void

    init(label: String, count: Int? = nil, selected: Bool, action: @escaping () -> Void) {
        self.label = label
        self.count = count
        self.selected = selected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(AppTypography.filterChip)
                if let count = count {
                    Text("\(count)")
                        .font(AppTypography.filterChip)
                        .foregroundColor(selected ? AppColors.backgroundPrimary.opacity(0.7) : AppColors.textSecondary)
                }
            }
            .foregroundColor(selected ? AppColors.backgroundPrimary : AppColors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? AppColors.surfaceHigh : AppColors.backgroundCard)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        FilterChip(label: "All", count: 5, selected: true) {}
        FilterChip(label: "Hit", count: 1, selected: false) {}
        FilterChip(label: "Behind", count: 2, selected: false) {}
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}
