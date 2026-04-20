//
//  SegmentedPillControl.swift
//  CardPulse
//

import SwiftUI

struct SegmentedPillControl<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                segmentButton(for: option)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.backgroundCard)
        )
    }

    @ViewBuilder
    private func segmentButton(for option: Option) -> some View {
        let isSelected = (selection == option)
        Button {
            selection = option
        } label: {
            Text(title(option))
                .font(AppTypography.filterChip)
                .foregroundColor(isSelected ? AppColors.onAccent : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? AppColors.accent : AppColors.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var selected = "Month"
        var body: some View {
            SegmentedPillControl(
                selection: $selected,
                options: ["Day", "Week", "Month", "Year"],
                title: { $0 }
            )
            .padding()
            .background(AppColors.backgroundPrimary)
        }
    }
    return PreviewWrapper()
}
