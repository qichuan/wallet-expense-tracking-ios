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

    /// Base reward rate. Units depend on `rewardType`:
    /// - `.cashback`: percent (e.g. `1.6` for 1.6%)
    /// - `.miles`: miles per dollar (e.g. `1.4` mpd)
    /// - `.none`: ignored
    var baseRewardRate: Decimal = 0

    /// Round the transaction amount down to the nearest multiple of this block before
    /// applying the rate. `1` means no rounding; `5` matches UOB/DBS-style $5 blocks.
    var roundingBlock: Decimal = 1

    @Relationship(deleteRule: .cascade, inverse: \Transaction.card)
    var transactions: [Transaction] = []

    @Relationship(deleteRule: .cascade, inverse: \CardRewardRule.card)
    var rewardRules: [CardRewardRule] = []

    init(name: String,
         minimumSpendingAmount: Decimal,
         hasMinimumSpending: Bool = false,
         rewardType: RewardType = .none,
         minimumSpendingByDayOfMonth: Int = 1,
         baseRewardRate: Decimal = 0,
         roundingBlock: Decimal = 1) {
        self.id = UUID()
        self.name = name
        self.minimumSpendingAmount = minimumSpendingAmount
        self.hasMinimumSpending = hasMinimumSpending
        self.rewardType = rewardType
        self.createdAt = Date()
        self.minimumSpendingByDayOfMonth = max(1, min(31, minimumSpendingByDayOfMonth))
        self.baseRewardRate = baseRewardRate
        self.roundingBlock = roundingBlock
    }
}
