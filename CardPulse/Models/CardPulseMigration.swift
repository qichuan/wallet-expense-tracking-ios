//
//  CardPulseMigration.swift
//  CardPulse
//

import Foundation
import SwiftData

// MARK: - V1 Schema (original — Transaction has no currency field)

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [SchemaV1.Card.self, SchemaV1.Transaction.self] }

    @Model final class Card {
        var id: UUID
        var name: String
        var minimumSpendingAmount: Decimal
        var hasMinimumSpending: Bool
        var rewardType: RewardType
        var createdAt: Date
        var minimumSpendingByDayOfMonth: Int

        @Relationship(deleteRule: .cascade, inverse: \SchemaV1.Transaction.card)
        var transactions: [SchemaV1.Transaction] = []

        init(name: String, minimumSpendingAmount: Decimal, hasMinimumSpending: Bool = false,
             rewardType: RewardType = .none, minimumSpendingByDayOfMonth: Int = 1) {
            self.id = UUID()
            self.name = name
            self.minimumSpendingAmount = minimumSpendingAmount
            self.hasMinimumSpending = hasMinimumSpending
            self.rewardType = rewardType
            self.createdAt = Date()
            self.minimumSpendingByDayOfMonth = minimumSpendingByDayOfMonth
        }
    }

    @Model final class Transaction {
        var id: UUID
        var merchant: String
        var amount: Decimal
        var date: Date
        var category: String?
        var note: String?
        var card: SchemaV1.Card?

        init(merchant: String, amount: Decimal, date: Date,
             category: String? = nil, note: String? = nil, card: SchemaV1.Card? = nil) {
            self.id = UUID()
            self.merchant = merchant
            self.amount = amount
            self.date = date
            self.category = category
            self.note = note
            self.card = card
        }
    }
}

// MARK: - V2 Schema (current — Transaction gains `currency` field)

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Card.self, Transaction.self] }
}

// MARK: - Migration Plan

enum CardPulseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [migrateV1toV2] }

    /// V1 → V2: backfill `currency` on existing transactions using the user's stored default.
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let defaultCurrency = UserDefaults.standard.string(forKey: CurrencyUtils.defaultCurrencyKey) ?? "SGD"
            let transactions = try context.fetch(FetchDescriptor<Transaction>())
            for txn in transactions where txn.currency.isEmpty {
                txn.currency = defaultCurrency
            }
            try context.save()
        }
    )
}
