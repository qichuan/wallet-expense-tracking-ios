//
//  MerchantUtils.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI

class MerchantUtils {
    // Centralized default categories used across the app
    static let defaultCategories: [String] = [
        "Other",            // default
        "Shopping",
        "Food & Drinks",
        "Services",
        "Travel",
        "Entertainment",
        "Health"
    ]

    /// SF Symbol name for a built-in category. Used as the seed icon for `SpendingCategory`
    /// records and as the fallback when looking up an unknown category string.
    static func defaultIcon(for category: String) -> String {
        switch category {
        case "Shopping":        return "bag"
        case "Food & Drinks":   return "fork.knife"
        case "Services":        return "wrench.and.screwdriver"
        case "Travel":          return "airplane"
        case "Entertainment":   return "star"
        case "Health":          return "cross"
        case "Other":           return "dollarsign"
        default:                return "dollarsign"
        }
    }

    /// Hex color for a built-in category (as `Int` so it persists cleanly in SwiftData).
    /// Mirrors the `AppColors.category…` palette.
    static func defaultColorHex(for category: String) -> Int {
        switch category {
        case "Shopping":        return 0xEC4899
        case "Food & Drinks":   return 0xF59E0B
        case "Services":        return 0xFACC15
        case "Travel":          return 0x3B82F6
        case "Entertainment":   return 0xA855F7
        case "Health":          return 0xEF4444
        case "Other":           return 0x14B8A6
        default:                return 0x14B8A6
        }
    }

    // Normalize any raw category string to one of the default categories
    static func normalizedCategory(for rawCategory: String?) -> String {
        guard let raw = rawCategory?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "Other" // default category
        }
        let key = raw.lowercased()
        // If raw already matches a default (case-insensitive), return the canonical cased value
        if let canonical = defaultCategories.first(where: { $0.lowercased() == key }) {
            return canonical
        }
        // Fallback to Other for unknown categories
        return "Other"
    }

    static func icon(for category: String?) -> String {
        defaultIcon(for: normalizedCategory(for: category))
    }

    static func color(for category: String?) -> Color {
        let normalized = normalizedCategory(for: category)
        switch normalized {
        case "Shopping":        return AppColors.categoryShopping
        case "Food & Drinks":   return AppColors.categoryFoodDrinks
        case "Services":        return AppColors.categoryServices
        case "Travel":          return AppColors.categoryTravel
        case "Entertainment":   return AppColors.categoryEntertainment
        case "Health":          return AppColors.categoryHealth
        case "Other":           return AppColors.categoryOther
        default:                return AppColors.categoryOther
        }
    }

    /// Look up icon/color from a caller-supplied list of `SpendingCategory` records
    /// (typically from `@Query`). Falls back to the static built-in mapping for
    /// unknown names — keeps legacy `Transaction.category` strings rendering
    /// correctly even if the matching record has been deleted.
    static func icon(for category: String?, in categories: [SpendingCategory]) -> String {
        if let raw = category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let match = categories.first(where: { $0.name.caseInsensitiveCompare(raw) == .orderedSame }) {
            return match.icon
        }
        return icon(for: category)
    }

    static func color(for category: String?, in categories: [SpendingCategory]) -> Color {
        if let raw = category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let match = categories.first(where: { $0.name.caseInsensitiveCompare(raw) == .orderedSame }) {
            return Color(hex: UInt32(match.colorHex))
        }
        return color(for: category)
    }
}
