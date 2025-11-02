//
//  Card.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import Foundation
import SwiftData

enum RewardType: String, Codable, CaseIterable {
    case none = "none"
    case miles = "miles"
    case cashback = "cashback"
    
    var displayName: String {
        rawValue.capitalized
    }
}

@Model
final class Card {
    var id: UUID
    var name: String
    var minimumSpendingAmount: Decimal
    var hasMinimumSpending: Bool
    var rewardType: RewardType
    var createdAt: Date
    var minimumSpendingByDayOfMonth: Int // 1...31
    
    @Relationship(deleteRule: .cascade, inverse: \Transaction.card)
    var transactions: [Transaction] = []
    
    init(name: String, minimumSpendingAmount: Decimal, hasMinimumSpending: Bool = false, rewardType: RewardType = .none, minimumSpendingByDayOfMonth: Int = 1) {
        self.id = UUID()
        self.name = name
        self.minimumSpendingAmount = minimumSpendingAmount
        self.hasMinimumSpending = hasMinimumSpending
        self.rewardType = rewardType
        self.createdAt = Date()
        self.minimumSpendingByDayOfMonth = max(1, min(31, minimumSpendingByDayOfMonth))
    }
}


