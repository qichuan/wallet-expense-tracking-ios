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
//
// Reuses `SchemaV3.Transaction` as the frozen shape — V2 and V3 have the same
// `Transaction` columns (V3's only additions are the `SpendingCategory` model
// and seeding logic, not Transaction-shape changes). Card is shared with V3/V4.

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [SchemaV4.Card.self, SchemaV3.Transaction.self] }
}

// MARK: - V3 Schema (adds `SpendingCategory` model — frozen pre-`isRecurring` shape)

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV4.Card.self, SchemaV3.Transaction.self, SpendingCategory.self]
    }

    @Model final class Transaction {
        var id: UUID
        var merchant: String
        var amount: Decimal
        var currency: String = ""
        var date: Date
        var category: String?
        var note: String?
        var card: SchemaV4.Card?

        init(merchant: String, amount: Decimal, date: Date,
             category: String? = nil, note: String? = nil, card: SchemaV4.Card? = nil,
             currency: String = "") {
            self.id = UUID()
            self.merchant = merchant
            self.amount = amount
            self.currency = currency
            self.date = date
            self.category = category
            self.note = note
            self.card = card
        }
    }
}

// MARK: - V4 Schema (Transaction gains `isRecurring` flag — frozen pre-rewards shape)
//
// V4 freezes `Card` and `Transaction` so V5's additions to live `Card` (reward fields,
// `rewardRules` relationship to the new `CardRewardRule` model) don't change V4's
// per-stage SwiftData checksum.

enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV4.Card.self, SchemaV4.Transaction.self, SpendingCategory.self]
    }

    @Model final class Card {
        var id: UUID
        var name: String
        var minimumSpendingAmount: Decimal
        var hasMinimumSpending: Bool
        var rewardType: RewardType
        var createdAt: Date
        var minimumSpendingByDayOfMonth: Int

        @Relationship(deleteRule: .cascade, inverse: \SchemaV4.Transaction.card)
        var transactions: [SchemaV4.Transaction] = []

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
        var currency: String = ""
        var date: Date
        var category: String?
        var note: String?
        var card: SchemaV4.Card?
        var isRecurring: Bool = false

        init(merchant: String, amount: Decimal, date: Date,
             category: String? = nil, note: String? = nil, card: SchemaV4.Card? = nil,
             currency: String = "", isRecurring: Bool = false) {
            self.id = UUID()
            self.merchant = merchant
            self.amount = amount
            self.currency = currency
            self.date = date
            self.category = category
            self.note = note
            self.card = card
            self.isRecurring = isRecurring
        }
    }
}

// MARK: - V5 Schema (adds reward-rate fields to Card and the CardRewardRule model — frozen pre-location shape)
//
// V5 freezes `Card`, `Transaction`, and `CardRewardRule` (which are coupled by
// relationships) so V6's additions of location fields to live `Transaction`
// don't change V5's per-stage SwiftData checksum.

enum SchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV5.Card.self, SchemaV5.Transaction.self, SpendingCategory.self, SchemaV5.CardRewardRule.self]
    }

    @Model final class Card {
        var id: UUID
        var name: String
        var minimumSpendingAmount: Decimal
        var hasMinimumSpending: Bool
        var rewardType: RewardType
        var createdAt: Date
        var minimumSpendingByDayOfMonth: Int
        var baseRewardRate: Decimal = 0
        var roundingBlock: Decimal = 1

        @Relationship(deleteRule: .cascade, inverse: \SchemaV5.Transaction.card)
        var transactions: [SchemaV5.Transaction] = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV5.CardRewardRule.card)
        var rewardRules: [SchemaV5.CardRewardRule] = []

        init(name: String, minimumSpendingAmount: Decimal, hasMinimumSpending: Bool = false,
             rewardType: RewardType = .none, minimumSpendingByDayOfMonth: Int = 1,
             baseRewardRate: Decimal = 0, roundingBlock: Decimal = 1) {
            self.id = UUID()
            self.name = name
            self.minimumSpendingAmount = minimumSpendingAmount
            self.hasMinimumSpending = hasMinimumSpending
            self.rewardType = rewardType
            self.createdAt = Date()
            self.minimumSpendingByDayOfMonth = minimumSpendingByDayOfMonth
            self.baseRewardRate = baseRewardRate
            self.roundingBlock = roundingBlock
        }
    }

    @Model final class Transaction {
        var id: UUID
        var merchant: String
        var amount: Decimal
        var currency: String = ""
        var date: Date
        var category: String?
        var note: String?
        var card: SchemaV5.Card?
        var isRecurring: Bool = false

        init(merchant: String, amount: Decimal, date: Date,
             category: String? = nil, note: String? = nil, card: SchemaV5.Card? = nil,
             currency: String = "", isRecurring: Bool = false) {
            self.id = UUID()
            self.merchant = merchant
            self.amount = amount
            self.currency = currency
            self.date = date
            self.category = category
            self.note = note
            self.card = card
            self.isRecurring = isRecurring
        }
    }

    @Model final class CardRewardRule {
        var id: UUID
        var card: SchemaV5.Card?
        var categoryName: String
        var rate: Decimal
        var createdAt: Date

        init(card: SchemaV5.Card? = nil, categoryName: String, rate: Decimal) {
            self.id = UUID()
            self.card = card
            self.categoryName = categoryName
            self.rate = rate
            self.createdAt = Date()
        }
    }
}

// MARK: - V6 Schema (frozen — Transaction gained `latitude`, `longitude`, `placeName`)
//
// V6 freezes `Card`, `Transaction`, and `CardRewardRule` so V7's additions to the
// live `Card` (`maxMilesCap`, `maxCashbackCap`) don't change V6's per-stage checksum.

enum SchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV6.Card.self, SchemaV6.Transaction.self, SpendingCategory.self, SchemaV6.CardRewardRule.self]
    }

    @Model final class Card {
        var id: UUID
        var name: String
        var minimumSpendingAmount: Decimal
        var hasMinimumSpending: Bool
        var rewardType: RewardType
        var createdAt: Date
        var minimumSpendingByDayOfMonth: Int
        var baseRewardRate: Decimal = 0
        var roundingBlock: Decimal = 1

        @Relationship(deleteRule: .cascade, inverse: \SchemaV6.Transaction.card)
        var transactions: [SchemaV6.Transaction] = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV6.CardRewardRule.card)
        var rewardRules: [SchemaV6.CardRewardRule] = []

        init(name: String, minimumSpendingAmount: Decimal, hasMinimumSpending: Bool = false,
             rewardType: RewardType = .none, minimumSpendingByDayOfMonth: Int = 1,
             baseRewardRate: Decimal = 0, roundingBlock: Decimal = 1) {
            self.id = UUID()
            self.name = name
            self.minimumSpendingAmount = minimumSpendingAmount
            self.hasMinimumSpending = hasMinimumSpending
            self.rewardType = rewardType
            self.createdAt = Date()
            self.minimumSpendingByDayOfMonth = minimumSpendingByDayOfMonth
            self.baseRewardRate = baseRewardRate
            self.roundingBlock = roundingBlock
        }
    }

    @Model final class Transaction {
        var id: UUID
        var merchant: String
        var amount: Decimal
        var currency: String = ""
        var date: Date
        var category: String?
        var note: String?
        var card: SchemaV6.Card?
        var isRecurring: Bool = false
        var latitude: Double?
        var longitude: Double?
        var placeName: String?

        init(merchant: String, amount: Decimal, date: Date,
             category: String? = nil, note: String? = nil, card: SchemaV6.Card? = nil,
             currency: String = "", isRecurring: Bool = false,
             latitude: Double? = nil, longitude: Double? = nil, placeName: String? = nil) {
            self.id = UUID()
            self.merchant = merchant
            self.amount = amount
            self.currency = currency
            self.date = date
            self.category = category
            self.note = note
            self.card = card
            self.isRecurring = isRecurring
            self.latitude = latitude
            self.longitude = longitude
            self.placeName = placeName
        }
    }

    @Model final class CardRewardRule {
        var id: UUID
        var card: SchemaV6.Card?
        var categoryName: String
        var rate: Decimal
        var createdAt: Date

        init(card: SchemaV6.Card? = nil, categoryName: String, rate: Decimal) {
            self.id = UUID()
            self.card = card
            self.categoryName = categoryName
            self.rate = rate
            self.createdAt = Date()
        }
    }
}

// MARK: - V7 Schema (frozen — Card gained `maxMilesCap` and `maxCashbackCap`)
//
// V7 freezes `Card`, `Transaction`, and `CardRewardRule` so V8's additions to the
// live `Card` (`foreignRewardRate`, `currencyRules` relationship to the new
// `CardCurrencyRule` model) don't change V7's per-stage checksum.

enum SchemaV7: VersionedSchema {
    static var versionIdentifier = Schema.Version(7, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV7.Card.self, SchemaV7.Transaction.self, SpendingCategory.self, SchemaV7.CardRewardRule.self]
    }

    @Model final class Card {
        var id: UUID
        var name: String
        var minimumSpendingAmount: Decimal
        var hasMinimumSpending: Bool
        var rewardType: RewardType
        var createdAt: Date
        var minimumSpendingByDayOfMonth: Int
        var baseRewardRate: Decimal = 0
        var roundingBlock: Decimal = 1
        var maxMilesCap: Decimal = 0
        var maxCashbackCap: Decimal = 0

        @Relationship(deleteRule: .cascade, inverse: \SchemaV7.Transaction.card)
        var transactions: [SchemaV7.Transaction] = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV7.CardRewardRule.card)
        var rewardRules: [SchemaV7.CardRewardRule] = []

        init(name: String, minimumSpendingAmount: Decimal, hasMinimumSpending: Bool = false,
             rewardType: RewardType = .none, minimumSpendingByDayOfMonth: Int = 1,
             baseRewardRate: Decimal = 0, roundingBlock: Decimal = 1,
             maxMilesCap: Decimal = 0, maxCashbackCap: Decimal = 0) {
            self.id = UUID()
            self.name = name
            self.minimumSpendingAmount = minimumSpendingAmount
            self.hasMinimumSpending = hasMinimumSpending
            self.rewardType = rewardType
            self.createdAt = Date()
            self.minimumSpendingByDayOfMonth = minimumSpendingByDayOfMonth
            self.baseRewardRate = baseRewardRate
            self.roundingBlock = roundingBlock
            self.maxMilesCap = maxMilesCap
            self.maxCashbackCap = maxCashbackCap
        }
    }

    @Model final class Transaction {
        var id: UUID
        var merchant: String
        var amount: Decimal
        var currency: String = ""
        var date: Date
        var category: String?
        var note: String?
        var card: SchemaV7.Card?
        var isRecurring: Bool = false
        var latitude: Double?
        var longitude: Double?
        var placeName: String?

        init(merchant: String, amount: Decimal, date: Date,
             category: String? = nil, note: String? = nil, card: SchemaV7.Card? = nil,
             currency: String = "", isRecurring: Bool = false,
             latitude: Double? = nil, longitude: Double? = nil, placeName: String? = nil) {
            self.id = UUID()
            self.merchant = merchant
            self.amount = amount
            self.currency = currency
            self.date = date
            self.category = category
            self.note = note
            self.card = card
            self.isRecurring = isRecurring
            self.latitude = latitude
            self.longitude = longitude
            self.placeName = placeName
        }
    }

    @Model final class CardRewardRule {
        var id: UUID
        var card: SchemaV7.Card?
        var categoryName: String
        var rate: Decimal
        var createdAt: Date

        init(card: SchemaV7.Card? = nil, categoryName: String, rate: Decimal) {
            self.id = UUID()
            self.card = card
            self.categoryName = categoryName
            self.rate = rate
            self.createdAt = Date()
        }
    }
}

// MARK: - V8 Schema (current — Card gains `foreignRewardRate` and the `CardCurrencyRule` model)

enum SchemaV8: VersionedSchema {
    static var versionIdentifier = Schema.Version(8, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Card.self, Transaction.self, SpendingCategory.self, CardRewardRule.self, CardCurrencyRule.self]
    }
}

// MARK: - Migration Plan

enum CardPulseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self, SchemaV6.self, SchemaV7.self, SchemaV8.self]
    }

    static var stages: [MigrationStage] { [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5, migrateV5toV6, migrateV6toV7, migrateV7toV8] }

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

            let transactions = try context.fetch(FetchDescriptor<SchemaV3.Transaction>())
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

    /// V3 → V4: add `isRecurring` to `Transaction`. Default `false` is supplied by the
    /// model declaration, so SwiftData handles this as a lightweight migration.
    static let migrateV3toV4 = MigrationStage.lightweight(
        fromVersion: SchemaV3.self,
        toVersion: SchemaV4.self
    )

    /// V4 → V5: add `baseRewardRate` and `roundingBlock` to `Card` and introduce the
    /// `CardRewardRule` model. Defaults are supplied by the model declarations
    /// (rate `0`, block `1`), so SwiftData handles this as a lightweight migration.
    static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: SchemaV4.self,
        toVersion: SchemaV5.self
    )

    /// V5 → V6: add `latitude`, `longitude`, and `placeName` to `Transaction`. All three
    /// are optional with no default, so SwiftData handles this as a lightweight migration.
    static let migrateV5toV6 = MigrationStage.lightweight(
        fromVersion: SchemaV5.self,
        toVersion: SchemaV6.self
    )

    /// V6 → V7: add `maxMilesCap` and `maxCashbackCap` to `Card`. Both default to `0`
    /// (no cap), so SwiftData handles this as a lightweight migration.
    static let migrateV6toV7 = MigrationStage.lightweight(
        fromVersion: SchemaV6.self,
        toVersion: SchemaV7.self
    )

    /// V7 → V8: add `foreignRewardRate` to `Card` and introduce the `CardCurrencyRule`
    /// model. The rate defaults to `0` (foreign spending earns the base rate), so
    /// SwiftData handles this as a lightweight migration.
    static let migrateV7toV8 = MigrationStage.lightweight(
        fromVersion: SchemaV7.self,
        toVersion: SchemaV8.self
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
