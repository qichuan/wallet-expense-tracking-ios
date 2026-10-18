//
//  AppTypography.swift
//  CardPulse
//
//  Single source of truth for every font used in the app.
//  UI files MUST use these tokens — never declare `.font(...)` inline.
//
//  Headings and amounts use Fredoka, everything else Nunito. Both are bundled
//  in `Resources/Fonts` and registered via `UIAppFonts`. Every token is
//  `relativeTo:` a text style so it scales with Dynamic Type.
//

import SwiftUI

enum AppTypography {

    /// PostScript names of the bundled static font instances.
    private enum Face {
        static let fredokaMedium   = "FredokaLight-Medium"
        static let fredokaSemiBold = "FredokaLight-SemiBold"
        static let fredokaBold     = "FredokaLight-Bold"
        static let nunitoSemiBold  = "NunitoExtraLight-SemiBold"
        static let nunitoBold      = "NunitoExtraLight-Bold"
        static let nunitoExtraBold = "NunitoExtraLight-ExtraBold"
        static let nunitoBlack     = "NunitoExtraLight-Black"
    }

    private static func font(_ face: String, _ size: CGFloat, _ style: Font.TextStyle) -> Font {
        .custom(face, size: size, relativeTo: style)
    }

    // MARK: - Screen / hero

    static let screenTitle      = font(Face.fredokaBold, 30, .largeTitle)
    static let wordmark         = font(Face.fredokaBold, 27, .largeTitle)
    static let sectionTitle     = font(Face.fredokaSemiBold, 20, .title3)
    static let profileName      = font(Face.fredokaBold, 26, .title)
    static let welcomeTitle     = font(Face.fredokaBold, 44, .largeTitle)
    static let welcomeHeadline  = font(Face.fredokaBold, 28, .title)

    // MARK: - Amounts

    static let amountHero       = font(Face.fredokaBold, 40, .largeTitle)
    static let amount           = font(Face.fredokaBold, 30, .title)
    static let amountLarge      = font(Face.fredokaBold, 34, .largeTitle)
    static let amountTransaction    = font(Face.fredokaSemiBold, 17, .body)
    static let amountTransactionAlt = font(Face.nunitoSemiBold, 11, .caption2)
    static let amountTarget         = font(Face.nunitoExtraBold, 15, .subheadline)
    static let statValue        = font(Face.fredokaBold, 22, .title2)
    static let streakBig        = font(Face.fredokaBold, 17, .headline)

    // MARK: - Card / list rows

    static let cardTitle        = font(Face.fredokaSemiBold, 18, .headline)
    static let rowTitle         = font(Face.nunitoBlack, 15, .body)
    static let rowValue         = font(Face.nunitoExtraBold, 14, .subheadline)
    static let rowMeta          = font(Face.nunitoBold, 13, .footnote)

    // MARK: - Speech bubble

    static let bubble           = font(Face.nunitoBold, 15, .body)
    static let bubbleEmphasis   = font(Face.nunitoBlack, 15, .body)

    // MARK: - Metrics

    static let metricLabel      = font(Face.nunitoExtraBold, 12, .caption)
    static let metricValue      = font(Face.fredokaSemiBold, 17, .headline)

    // MARK: - Pills / chips

    static let pill             = font(Face.nunitoBlack, 12, .caption)
    static let pillBold         = font(Face.nunitoBlack, 13, .footnote)
    static let badgeTiny        = font(Face.nunitoBlack, 10, .caption2)
    static let filterChip       = font(Face.nunitoBlack, 14, .subheadline)
    static let tabLabel         = font(Face.fredokaSemiBold, 12, .caption)

    // MARK: - Banners

    static let bannerIcon       = font(Face.nunitoBold, 18, .headline)
    static let bannerTitle      = font(Face.nunitoBlack, 15, .subheadline)
    static let bannerBody       = font(Face.nunitoBold, 13, .footnote)
    static let bannerCTA        = font(Face.nunitoExtraBold, 14, .footnote)
    static let bannerClose      = font(Face.nunitoBlack, 12, .caption)

    // MARK: - Navigation / actions

    static let navButton        = font(Face.nunitoBlack, 16, .body)
    static let navChevron       = font(Face.nunitoExtraBold, 15, .body)
    static let navLabel         = font(Face.nunitoExtraBold, 15, .body)
    static let headerAction     = Font.system(size: 26, weight: .regular, design: .rounded)

    // MARK: - Chevrons

    static let chevron          = Font.system(size: 12, weight: .bold, design: .rounded)
    static let chevronSmall     = Font.system(size: 11, weight: .bold, design: .rounded)
    static let chevronTiny      = Font.system(size: 10, weight: .bold, design: .rounded)
    static let chevronTinyBold  = Font.system(size: 10, weight: .heavy, design: .rounded)

    // MARK: - Icon fonts (for SF Symbols inline)

    static let iconSmall        = Font.system(size: 14, weight: .bold, design: .rounded)
    static let iconMedium       = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let iconLarge        = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let iconXLarge       = Font.system(size: 32, weight: .regular, design: .rounded)
    static let iconXXLarge      = Font.system(size: 40, weight: .regular, design: .rounded)
    static let iconRadio        = Font.title3

    // MARK: - Delta / trend label

    static let deltaIcon        = Font.system(size: 12, weight: .heavy, design: .rounded)
    static let deltaText        = font(Face.nunitoBlack, 13, .footnote)

    // MARK: - Section label (uppercase, tracked)

    static let sectionLabel     = font(Face.nunitoBlack, 13, .footnote)

    // MARK: - System style aliases (for dialogs, empty states, secondary copy)

    static let headline         = font(Face.nunitoBlack, 17, .headline)
    static let subheadline      = font(Face.nunitoBold, 15, .subheadline)
    static let footnote         = font(Face.nunitoBold, 13, .footnote)
    static let caption          = font(Face.nunitoBold, 12, .caption)
    static let caption2         = font(Face.nunitoBold, 11, .caption2)
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(AppTypography.sectionLabel)
            .tracking(1)
            .foregroundColor(AppColors.textSecondary)
    }
}
