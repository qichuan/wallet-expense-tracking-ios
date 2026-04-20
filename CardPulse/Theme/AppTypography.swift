//
//  AppTypography.swift
//  CardPulse
//

import SwiftUI

enum AppTypography {
    static let screenTitle    = Font.system(size: 34, weight: .heavy, design: .rounded)
    static let cardTitle      = Font.system(size: 20, weight: .bold, design: .rounded)
    static let amount         = Font.system(size: 28, weight: .heavy, design: .rounded)
    static let amountLarge    = Font.system(size: 40, weight: .heavy, design: .rounded)
    static let rowTitle       = Font.system(.body, design: .default).weight(.semibold)
    static let rowSubtitle    = Font.system(.footnote)
    static let pill           = Font.system(size: 11, weight: .bold, design: .rounded)
    static let filterChip     = Font.system(size: 14, weight: .semibold, design: .rounded)
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .tracking(1.4)
            .foregroundColor(AppColors.textTertiary)
    }
}
