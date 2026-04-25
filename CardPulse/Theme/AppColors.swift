//
//  AppColors.swift
//  CardPulse
//

import SwiftUI

enum AppColors {
    // Surfaces
    static let backgroundPrimary    = Color(hex: 0x0A1428)
    static let backgroundCard       = Color(hex: 0x152238)
    static let backgroundCardSoft   = Color(hex: 0x1E2A45)
    static let divider              = Color.white.opacity(0.08)

    // Primary accent
    static let accent               = Color(hex: 0x2E6DFF)
    static let accentSoft           = Color(hex: 0x2E6DFF).opacity(0.18)

    // Status
    static let statusHit            = Color(hex: 0x22C55E)
    static let statusOnTrack        = Color(hex: 0x2E6DFF)
    static let statusBehind         = Color(hex: 0xF59E0B)

    // Text
    static let textPrimary          = Color.white
    static let textSecondary        = Color.white.opacity(0.6)
    static let textTertiary         = Color.white.opacity(0.4)

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
    static let surfaceHigh          = Color.white

    // Destructive (delete actions, negative deltas)
    static let destructive          = Color(hex: 0xEF4444)
    static let destructiveSoft      = Color(hex: 0xEF4444).opacity(0.12)

    // Modal / overlay scrim
    static let scrim                = Color.black.opacity(0.6)

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
}
