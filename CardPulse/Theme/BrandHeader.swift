//
//  BrandHeader.swift
//  CardPulse
//

import SwiftUI

/// Screen header: a Fredoka title with optional trailing actions.
struct BrandHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(title)
                .font(AppTypography.screenTitle)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

extension BrandHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// "CardLah!" wordmark with the accent exclamation mark.
struct Wordmark: View {
    var body: some View {
        (Text("CardLah").foregroundColor(AppColors.textPrimary)
            + Text("!").foregroundColor(AppColors.accent))
            .font(AppTypography.wordmark)
            .tracking(-0.3)
            .accessibilityLabel("CardLah!")
    }
}

/// Round accent "+" button used in screen headers.
struct HeaderAddButton: View {
    var accessibilityLabel: String = "Add"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(AppTypography.iconLarge)
                .foregroundColor(AppColors.onAccent)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(AppColors.accentEdge).offset(y: 3)
                )
                .background(Circle().fill(AppColors.accent))
                .padding(.bottom, 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    VStack(alignment: .leading) {
        HStack {
            Wordmark()
            Spacer()
            HeaderAddButton {}
        }
        .padding(.horizontal, 18)
        BrandHeader(title: "Card goals") {
            HeaderAddButton {}
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .screenBackground()
}
