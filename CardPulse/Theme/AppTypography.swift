//
//  AppTypography.swift
//  CardPulse
//
//  Single source of truth for every font used in the app.
//  UI files MUST use these tokens — never declare `.font(...)` inline.
//

import SwiftUI

enum AppTypography {

    // MARK: - Screen / hero

    static let screenTitle      = Font.system(size: 34, weight: .heavy,    design: .default)

    // MARK: - Amounts

    static let amountHero       = Font.system(size: 40, weight: .heavy,    design: .default)
    static let amount           = Font.system(size: 28, weight: .heavy,    design: .default)
    static let amountTransaction    = Font.system(size: 15, weight: .bold,    design: .default)
    static let amountTransactionAlt = Font.system(size: 11, weight: .regular, design: .default)
    static let amountTarget         = Font.system(size: 14, weight: .semibold, design: .default)

    // MARK: - Card / list rows

    static let cardTitle        = Font.system(size: 20, weight: .bold,     design: .default)
    static let rowTitle         = Font.system(.body, design: .default).weight(.semibold)
    static let rowValue         = Font.system(size: 14, weight: .regular,  design: .default)
    static let rowMeta          = Font.system(size: 12, weight: .regular,  design: .default)

    // MARK: - Metrics

    static let metricLabel      = Font.system(size: 10, weight: .semibold, design: .default)
    static let metricValue      = Font.system(size: 16, weight: .bold,     design: .default)

    // MARK: - Pills / chips

    static let pill             = Font.system(size: 11, weight: .bold,     design: .default)
    static let pillBold         = Font.system(size: 13, weight: .bold,     design: .default)
    static let filterChip       = Font.system(size: 14, weight: .semibold, design: .default)

    // MARK: - Banners

    static let bannerIcon       = Font.system(size: 18, weight: .semibold, design: .default)
    static let bannerTitle      = Font.system(size: 15, weight: .semibold, design: .default)
    static let bannerBody       = Font.system(size: 13, weight: .regular,  design: .default)
    static let bannerCTA        = Font.system(size: 13, weight: .semibold, design: .default)
    static let bannerClose      = Font.system(size: 12, weight: .bold,     design: .default)

    // MARK: - Navigation / actions

    static let navButton        = Font.system(size: 16, weight: .semibold, design: .default)
    static let navChevron       = Font.system(size: 15, weight: .semibold, design: .default)
    static let navLabel         = Font.system(size: 15, weight: .semibold, design: .default)
    static let headerAction     = Font.system(size: 26, weight: .regular,  design: .default)

    // MARK: - Chevrons

    static let chevron          = Font.system(size: 12, weight: .semibold, design: .default)
    static let chevronSmall     = Font.system(size: 11, weight: .semibold, design: .default)
    static let chevronTiny      = Font.system(size: 10, weight: .semibold, design: .default)
    static let chevronTinyBold  = Font.system(size: 10, weight: .bold,     design: .default)

    // MARK: - Icon fonts (for SF Symbols inline)

    static let iconMedium       = Font.system(size: 16, weight: .semibold, design: .default)
    static let iconLarge        = Font.system(size: 20, weight: .regular,  design: .default)
    static let iconXLarge       = Font.system(size: 32, weight: .regular,  design: .default)
    static let iconXXLarge      = Font.system(size: 40, weight: .regular,  design: .default)
    static let iconRadio        = Font.title3

    // MARK: - Delta / trend label

    static let deltaIcon        = Font.system(size: 11, weight: .bold,     design: .default)
    static let deltaText        = Font.system(size: 13, weight: .semibold, design: .default)

    // MARK: - Section label (uppercase, tracked)

    static let sectionLabel     = Font.system(size: 12, weight: .semibold, design: .default)

    // MARK: - System style aliases (for dialogs, empty states, secondary copy)

    static let headline         = Font.headline
    static let subheadline      = Font.subheadline
    static let footnote         = Font.footnote
    static let caption          = Font.caption
    static let caption2         = Font.caption2
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(AppTypography.sectionLabel)
            .tracking(1.4)
            .foregroundColor(AppColors.textTertiary)
    }
}
