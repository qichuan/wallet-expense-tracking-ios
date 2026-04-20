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

// MARK: - V2 Schema (Transaction gains `currency` field)

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Card.self, Transaction.self] }
}

// MARK: - V3 Schema (current — adds `SpendingCategory` model)

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Card.self, Transaction.self, SpendingCategory.self]
    }
}

// MARK: - Migration Plan

enum CardPulseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] { [migrateV1toV2, migrateV2toV3] }

    /// V1 → V2: backfill `currency` on existing transactions using the user's stored default.
    /// Skipped when the user has not yet chosen a default currency — the onboarding
    /// currency step will perform the backfill after the user makes their selection.
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            guard UserDefaults.standard.bool(forKey: "hasChosenDefaultCurrency"),
                  let defaultCurrency = UserDefaults.standard.string(forKey: CurrencyUtils.defaultCurrencyKey),
                  !defaultCurrency.isEmpty
            else { return }

            let transactions = try context.fetch(FetchDescriptor<Transaction>())
            for txn in transactions where txn.currency.isEmpty {
                txn.currency = defaultCurrency
            }
            try context.save()
        }
    )

    /// V2 → V3: seed the 7 built-in `SpendingCategory` records if none exist yet.
    /// Transaction.category strings continue to function as loose foreign keys by name.
    static let migrateV2toV3 = MigrationStage.custom(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self,
        willMigrate: nil,
        didMigrate: { context in
            try CategorySeeding.seedBuiltInsIfNeeded(in: context)
        }
    )
}

/// Seeds the 7 built-in `SpendingCategory` records.
///
/// Used both by the V2→V3 migration and at launch (for users who install
/// on V3 directly — no migration runs, so we need a safety seed).
enum CategorySeeding {
    @discardableResult
    static func seedBuiltInsIfNeeded(in context: ModelContext) throws -> Bool {
        let existing = try context.fetch(FetchDescriptor<SpendingCategory>())
        guard existing.isEmpty else { return false }
        for (idx, name) in MerchantUtils.defaultCategories.enumerated() {
            let category = SpendingCategory(
                name: name,
                icon: MerchantUtils.defaultIcon(for: name),
                colorHex: MerchantUtils.defaultColorHex(for: name),
                isBuiltIn: true,
                sortOrder: idx
            )
            context.insert(category)
        }
        try context.save()
        return true
    }
}
