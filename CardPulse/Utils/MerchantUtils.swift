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
        let normalized = normalizedCategory(for: category)
        switch normalized {
        case "Shopping":
            return "bag"
        case "Food & Drinks":
            return "fork.knife"
        case "Services":
            return "wrench.and.screwdriver"
        case "Travel":
            return "airplane"
        case "Entertainment":
            return "tv"
        case "Health":
            return "cross"
        case "Other":
            return "creditcard"
        default:
            return "creditcard"
        }
    }
    
    static func color(for category: String?) -> Color {
        let normalized = normalizedCategory(for: category)
        switch normalized {
        case "Shopping":
            return .pink
        case "Food & Drinks":
            return .orange
        case "Services":
            return .yellow
        case "Travel":
            return .cyan
        case "Entertainment":
            return .purple
        case "Health":
            return .red
        case "Other":
            return .gray
        default:
            return .gray
        }
    }
}
