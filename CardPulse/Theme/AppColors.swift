//
//  AppColors.swift
//  CardPulse
//
//  Every token resolves per appearance: the light set is the cream "CardLah Fun"
//  palette, the dark set keeps the original navy surfaces.
//

import SwiftUI
import UIKit

enum AppColors {
    // Surfaces
    static let backgroundPrimary    = Color(light: 0xFFF7E8, dark: 0x0A1428)
    static let backgroundCard       = Color(light: 0xFFFFFF, dark: 0x152238)
    static let backgroundCardSoft   = Color(light: 0xF1E8D8, dark: 0x1E2A45)
    static let divider              = Color(light: 0xF6EEDF, dark: 0xFFFFFF, darkAlpha: 0.08)

    /// 2pt outline and bottom "lip" of chunky cards, rows and chips.
    static let border               = Color(light: 0xEFE3CC, dark: 0x26344F)
    /// Empty part of progress bars and future/inactive cells.
    static let track                = Color(light: 0xF1E8D8, dark: 0x1E2A45)

    // Primary accent
    static let accent               = Color(hex: 0x2E6DFF)
    static let accentEdge           = Color(hex: 0x1E4FD6)
    static let accentSoft           = Color(light: 0xE3ECFF, dark: 0x2E6DFF, darkAlpha: 0.22)
    static let accentSoftBorder     = Color(light: 0xBFD2FF, dark: 0x2E6DFF, darkAlpha: 0.45)

    // Status
    static let statusHit            = Color(hex: 0x22C55E)
    static let statusOnTrack        = Color(hex: 0x2E6DFF)
    static let statusBehind         = Color(hex: 0xF59E0B)
    static let statusHitEdge        = Color(hex: 0x16A34A)
    static let statusHitSoft        = Color(light: 0xDCFCE7, dark: 0x22C55E, darkAlpha: 0.18)
    static let statusHitText        = Color(light: 0x15803D, dark: 0x4ADE80)
    static let statusOnTrackSoft    = Color(light: 0xE3ECFF, dark: 0x2E6DFF, darkAlpha: 0.22)
    static let statusOnTrackText    = Color(light: 0x1E4FD6, dark: 0x7FA6FF)
    static let statusBehindSoft     = Color(light: 0xFFEFD2, dark: 0xF59E0B, darkAlpha: 0.18)
    static let statusBehindText     = Color(light: 0xB45309, dark: 0xFBBF24)

    // Gamification
    static let streak               = Color(hex: 0xF97316)
    static let streakEdge           = Color(hex: 0xEA580C)
    static let gold                 = Color(hex: 0xFFC93C)
    static let goldEdge             = Color(hex: 0xE3A21A)
    static let goldSoft             = Color(light: 0xFFE9A8, dark: 0xFFC93C, darkAlpha: 0.25)
    static let locked               = Color(light: 0xD5CBB6, dark: 0x3A4763)
    static let lockedEdge           = Color(light: 0xB8AD96, dark: 0x2A3550)

    // Text
    static let textPrimary          = Color(light: 0x0A1428, dark: 0xFFFFFF)
    static let textSecondary        = Color(light: 0x5B6478, dark: 0xFFFFFF, darkAlpha: 0.6)
    static let textTertiary         = Color(light: 0x9AA1B2, dark: 0xFFFFFF, darkAlpha: 0.4)
    static let chevron              = Color(light: 0xC2B9A6, dark: 0xFFFFFF, darkAlpha: 0.3)

    // Categories (PDF donut palette)
    static let categoryFoodDrinks   = Color(hex: 0xF59E0B)
    static let categoryShopping     = Color(hex: 0xEC4899)
    static let categoryTravel       = Color(hex: 0x3B82F6)
    static let categoryEntertainment = Color(hex: 0xA855F7)
    static let categoryServices     = Color(hex: 0xFACC15)
    static let categoryHealth       = Color(hex: 0xEF4444)
    static let categoryOther        = Color(hex: 0x14B8A6)

    // Reward badges
    static let rewardMiles          = Color(hex: 0x14B8A6)
    static let rewardCash           = Color(hex: 0xFACC15)

    // Brand accent (for BrandMark gradient)
    static let brandGold            = Color(hex: 0xFFD166)

    // On-accent — text / glyphs rendered on colored surfaces (pills, buttons, category circles)
    static let onAccent             = Color.white

    // High-contrast fill (used for selected filter chip)
    static let surfaceHigh          = Color(light: 0x0A1428, dark: 0xFFFFFF)
    static let onSurfaceHigh        = Color(light: 0xFFFFFF, dark: 0x0A1428)

    // Destructive (delete actions, negative deltas)
    static let destructive          = Color(hex: 0xEF4444)
    static let destructiveSoft      = Color(hex: 0xEF4444).opacity(0.12)

    // Bottom inner shade on sticker-style icon circles
    static let innerShade           = Color.black.opacity(0.15)

    // Modal / overlay scrim
    static let scrim                = Color.black.opacity(0.45)

    // Transparent / clear
    static let clear                = Color.clear
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// A color that resolves to `light` or `dark` with the current trait collection.
    init(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
