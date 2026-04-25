//
//  SpendingCategory.swift
//  CardPulse
//

import Foundation
import SwiftData

@Model
final class SpendingCategory {
    var id: UUID
    var name: String
    /// SF Symbol name (e.g. "bag", "fork.knife").
    var icon: String
    /// Hex color as Int, e.g. 0xEC4899. Rendered via `Color(hex:)`.
    var colorHex: Int
    /// Built-in categories are seeded on first launch and cannot be deleted.
    var isBuiltIn: Bool
    var sortOrder: Int

    init(name: String, icon: String, colorHex: Int, isBuiltIn: Bool = false, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
    }
}
