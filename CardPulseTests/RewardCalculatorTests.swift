//
//  RewardCalculatorTests.swift
//  CardPulseTests
//

import XCTest
import SwiftData
@testable import CardPulse

final class RewardCalculatorTests: XCTestCase {

    // MARK: - Helpers

    /// Returns an in-memory container holding the live schema. Used so we can
    /// instantiate `Card`/`Transaction`/`CardRewardRule` with the relationships
    /// the calculator depends on. Each test gets its own context.
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Card.self, Transaction.self, SpendingCategory.self, CardRewardRule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeCard(rewardType: RewardType,
                          baseRate: Decimal,
                          block: Decimal = 1,
                          rules: [(category: String, rate: Decimal)] = [],
                          in context: ModelContext) -> Card {
        let card = Card(
            name: "Test Card",
            minimumSpendingAmount: 0,
            hasMinimumSpending: false,
            rewardType: rewardType,
            baseRewardRate: baseRate,
            roundingBlock: block
        )
        context.insert(card)
        for r in rules {
            let rule = CardRewardRule(card: card, categoryName: r.category, rate: r.rate)
            context.insert(rule)
        }
        return card
    }

    private func makeTxn(amount: Decimal, category: String? = nil, date: Date = Date(), card: Card?, in context: ModelContext) -> Transaction {
        let tx = Transaction(merchant: "Test", amount: amount, date: date, category: category, card: card)
        context.insert(tx)
        return tx
    }

    /// A miles card with one capped category bonus rule (base + bonus mpd, capped at
    /// `cap` miles per calendar month).
    private func makeCappedMilesCard(base: Decimal, category: String, bonus: Decimal, cap: Decimal, in context: ModelContext) -> Card {
        let card = makeCard(rewardType: .miles, baseRate: base, in: context)
        let rule = CardRewardRule(card: card, categoryName: category, rate: bonus, maxRewardCap: cap)
        context.insert(rule)
        return card
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    // MARK: - Cashback

    func testCashback_FlatPercentage() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 1.6, in: ctx)
        let tx = makeTxn(amount: Decimal(string: "1050.50")!, card: card, in: ctx)

        let reward = RewardCalculator.convertedReward(for: tx)
        XCTAssertNotNil(reward)
        // 1050.50 * 0.016 = 16.808
        XCTAssertEqual(reward, Decimal(string: "16.808"))
    }

    func testCashback_NoRoundingByDefault() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 2.0, block: 1, in: ctx)
        let tx = makeTxn(amount: Decimal(string: "36.35")!, card: card, in: ctx)

        // 36.35 * 0.02 = 0.727
        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(string: "0.727"))
    }

    // MARK: - Miles

    func testMiles_BaseRateNoRounding() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.4, block: 1, in: ctx)
        let tx = makeTxn(amount: Decimal(string: "100")!, card: card, in: ctx)

        // 100 * 1.4 = 140
        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(140))
    }

    /// UOB-style $5 rounding-down example from the design brief:
    /// $36.35 → rounded to $35 → 35 * 1.4 = 49 miles.
    func testMiles_FiveDollarBlockRoundsDown() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.4, block: 5, in: ctx)
        let tx = makeTxn(amount: Decimal(string: "36.35")!, card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(49))
    }

    func testMiles_BlockRoundingDoesNotRoundUp() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.0, block: 5, in: ctx)
        // 4.99 must round DOWN to 0, not UP to 5.
        let tx = makeTxn(amount: Decimal(string: "4.99")!, card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(0))
    }

    func testMiles_ExactBlockBoundary() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.0, block: 5, in: ctx)
        let tx = makeTxn(amount: Decimal(string: "35.00")!, card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(35))
    }

    // MARK: - Category bonus

    func testCategoryBonus_Overrides_BaseRate() throws {
        let ctx = try makeContext()
        let card = makeCard(
            rewardType: .miles,
            baseRate: 1.4,
            block: 1,
            rules: [(category: "Travel", rate: 4.0)],
            in: ctx
        )
        let bonus = makeTxn(amount: Decimal(100), category: "Travel", card: card, in: ctx)
        let baseline = makeTxn(amount: Decimal(100), category: "Shopping", card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.convertedReward(for: bonus), Decimal(400))
        XCTAssertEqual(RewardCalculator.convertedReward(for: baseline), Decimal(140))
    }

    func testCategoryBonus_CaseInsensitiveMatch() throws {
        let ctx = try makeContext()
        let card = makeCard(
            rewardType: .cashback,
            baseRate: 1.0,
            rules: [(category: "Food & Drinks", rate: 4.0)],
            in: ctx
        )
        let tx = makeTxn(amount: Decimal(100), category: "FOOD & drinks", card: card, in: ctx)

        // 100 * 0.04 = 4.0
        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(string: "4.0"))
    }

    func testCategoryBonus_UnmatchedCategory_FallsBackToBase() throws {
        let ctx = try makeContext()
        let card = makeCard(
            rewardType: .miles,
            baseRate: 1.4,
            rules: [(category: "Travel", rate: 4.0)],
            in: ctx
        )
        let tx = makeTxn(amount: Decimal(50), category: "Other", card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(70)) // 50 * 1.4
    }

    func testCategoryBonus_NilCategory_UsesBaseRate() throws {
        let ctx = try makeContext()
        let card = makeCard(
            rewardType: .miles,
            baseRate: 1.4,
            rules: [(category: "Travel", rate: 4.0)],
            in: ctx
        )
        let tx = makeTxn(amount: Decimal(100), category: nil, card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(140))
    }

    // MARK: - Edge cases

    func testReward_NilForNoneRewardType() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .none, baseRate: 0, in: ctx)
        let tx = makeTxn(amount: Decimal(100), card: card, in: ctx)

        XCTAssertNil(RewardCalculator.convertedReward(for: tx))
    }

    func testReward_NilForCardlessTransaction() throws {
        let ctx = try makeContext()
        let tx = makeTxn(amount: Decimal(100), card: nil, in: ctx)

        XCTAssertNil(RewardCalculator.convertedReward(for: tx))
    }

    func testReward_ZeroRate_ReturnsZero() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 0, in: ctx)
        let tx = makeTxn(amount: Decimal(100), card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(0))
    }

    // MARK: - Breakdown

    func testBreakdown_PopulatedFields_WithCategoryBonus() throws {
        let ctx = try makeContext()
        let card = makeCard(
            rewardType: .miles,
            baseRate: 1.4,
            block: 5,
            rules: [(category: "Travel", rate: 4.0)],
            in: ctx
        )
        let tx = makeTxn(amount: Decimal(string: "36.35")!, category: "Travel", card: card, in: ctx)

        let breakdown = RewardCalculator.breakdown(for: tx)
        XCTAssertNotNil(breakdown)
        XCTAssertEqual(breakdown?.amount, Decimal(string: "36.35"))
        XCTAssertEqual(breakdown?.rounded, Decimal(35))
        XCTAssertEqual(breakdown?.roundingBlock, Decimal(5))
        XCTAssertEqual(breakdown?.effectiveRate, Decimal(4))
        XCTAssertEqual(breakdown?.baseRate, Decimal(string: "1.4"))
        XCTAssertEqual(breakdown?.bonusCategory, "Travel")
        XCTAssertEqual(breakdown?.rewardType, .miles)
        XCTAssertEqual(breakdown?.reward, Decimal(140)) // 35 * 4
    }

    func testBreakdown_NoBonus_HasNilBonusCategory() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 1.6, in: ctx)
        let tx = makeTxn(amount: Decimal(50), category: "Shopping", card: card, in: ctx)

        let breakdown = RewardCalculator.breakdown(for: tx)
        XCTAssertNotNil(breakdown)
        XCTAssertNil(breakdown?.bonusCategory)
        XCTAssertEqual(breakdown?.effectiveRate, breakdown?.baseRate)
    }

    func testBreakdown_ReturnsNil_ForNoneRewardCard() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .none, baseRate: 0, in: ctx)
        let tx = makeTxn(amount: Decimal(100), card: card, in: ctx)

        XCTAssertNil(RewardCalculator.breakdown(for: tx))
    }

    // MARK: - Aggregate

    func testAggregate_BucketsByRewardType() throws {
        let ctx = try makeContext()
        let cashCard = makeCard(rewardType: .cashback, baseRate: 1.0, in: ctx)
        let milesCard = makeCard(rewardType: .miles, baseRate: 1.0, in: ctx)
        let noneCard = makeCard(rewardType: .none, baseRate: 0, in: ctx)

        let txs = [
            makeTxn(amount: Decimal(100), card: cashCard, in: ctx),
            makeTxn(amount: Decimal(50),  card: cashCard, in: ctx),
            makeTxn(amount: Decimal(200), card: milesCard, in: ctx),
            makeTxn(amount: Decimal(999), card: noneCard, in: ctx),
        ]

        let result = RewardCalculator.aggregate(txs)
        XCTAssertEqual(result.cashback, Decimal(string: "1.5")) // (100+50)*0.01
        XCTAssertEqual(result.miles, Decimal(200))             // 200*1.0
    }

    // MARK: - Cycle caps
    //
    // `Date()` transactions always fall in the card's current billing cycle, so
    // `makeTxn` is sufficient to exercise the cycle-level cap logic.

    func testCycleReward_NoCap_SumsAllTransactions() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.0, in: ctx)
        _ = makeTxn(amount: Decimal(100), card: card, in: ctx)
        _ = makeTxn(amount: Decimal(50), card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.cycleReward(for: card), Decimal(150))
    }

    func testCycleReward_ClampsToMilesCap() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.0, in: ctx)
        card.maxMilesCap = 120
        _ = makeTxn(amount: Decimal(100), card: card, in: ctx)
        _ = makeTxn(amount: Decimal(50), card: card, in: ctx) // 150 uncapped

        XCTAssertEqual(RewardCalculator.cycleReward(for: card), Decimal(120))
    }

    func testCycleReward_ClampsToCashbackCap() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 10, in: ctx) // 10%
        card.maxCashbackCap = 12
        _ = makeTxn(amount: Decimal(100), card: card, in: ctx) // 10
        _ = makeTxn(amount: Decimal(100), card: card, in: ctx) // +10 = 20 uncapped

        XCTAssertEqual(RewardCalculator.cycleReward(for: card), Decimal(12))
    }

    func testCycleReward_BelowCap_NotClamped() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.0, in: ctx)
        card.maxMilesCap = 500
        _ = makeTxn(amount: Decimal(100), card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.cycleReward(for: card), Decimal(100))
    }

    func testActiveCap_SelectsByRewardType() throws {
        let ctx = try makeContext()
        let miles = makeCard(rewardType: .miles, baseRate: 1.0, in: ctx)
        miles.maxMilesCap = 200
        miles.maxCashbackCap = 99
        XCTAssertEqual(RewardCalculator.activeCap(for: miles), Decimal(200))

        let cash = makeCard(rewardType: .cashback, baseRate: 1.0, in: ctx)
        cash.maxMilesCap = 99
        cash.maxCashbackCap = 50
        XCTAssertEqual(RewardCalculator.activeCap(for: cash), Decimal(50))
    }

    func testStatus_CapReached_AtExactBoundary() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.0, in: ctx)
        card.maxMilesCap = 100
        _ = makeTxn(amount: Decimal(100), card: card, in: ctx) // exactly the cap

        let status = RewardCalculator.cycleRewardStatus(for: card)
        XCTAssertTrue(status.isCapReached)
        XCTAssertEqual(status.earned, Decimal(100))
        XCTAssertEqual(status.remaining, Decimal(0))
        XCTAssertEqual(status.progress, 1.0)
    }

    func testStatus_BelowCap_RemainingAndProgress() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.0, in: ctx)
        card.maxMilesCap = 200
        _ = makeTxn(amount: Decimal(50), card: card, in: ctx) // 50 miles

        let status = RewardCalculator.cycleRewardStatus(for: card)
        XCTAssertFalse(status.isCapReached)
        XCTAssertEqual(status.remaining, Decimal(150))
        XCTAssertEqual(status.progress, 0.25, accuracy: 0.0001)
    }

    func testStatus_OverCap_RemainingClampedToZero() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 10, in: ctx)
        card.maxCashbackCap = 5
        _ = makeTxn(amount: Decimal(100), card: card, in: ctx) // 10 uncapped

        let status = RewardCalculator.cycleRewardStatus(for: card)
        XCTAssertTrue(status.isCapReached)
        XCTAssertEqual(status.earned, Decimal(5))
        XCTAssertEqual(status.uncapped, Decimal(10))
        XCTAssertEqual(status.remaining, Decimal(0))
    }

    func testStatus_NoCap_HasNoCapState() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.0, in: ctx)
        _ = makeTxn(amount: Decimal(100), card: card, in: ctx)

        let status = RewardCalculator.cycleRewardStatus(for: card)
        XCTAssertFalse(status.hasCap)
        XCTAssertFalse(status.isCapReached)
        XCTAssertNil(status.remaining)
        XCTAssertEqual(status.progress, 0)
        XCTAssertEqual(status.earned, Decimal(100))
    }

    // MARK: - Per-category monthly caps

    func testCategoryCap_LimitsMonthlyRewardForCategory() throws {
        let ctx = try makeContext()
        // base 1 + bonus 3 = 4 mpd on Travel, capped at 100 miles/month.
        let card = makeCappedMilesCard(base: 1, category: "Travel", bonus: 3, cap: 100, in: ctx)
        _ = makeTxn(amount: Decimal(20), category: "Travel", card: card, in: ctx) // 80 miles
        _ = makeTxn(amount: Decimal(20), category: "Travel", card: card, in: ctx) // +80 = 160 uncapped

        // Category cap clamps the Travel total to 100 (no card-wide cap set).
        XCTAssertEqual(RewardCalculator.cycleReward(for: card), Decimal(100))
    }

    func testCategoryCap_DoesNotAffectUncappedCategories() throws {
        let ctx = try makeContext()
        let card = makeCappedMilesCard(base: 1, category: "Travel", bonus: 3, cap: 100, in: ctx)
        _ = makeTxn(amount: Decimal(50), category: "Travel", card: card, in: ctx)  // 200 → capped 100
        _ = makeTxn(amount: Decimal(30), category: "Groceries", card: card, in: ctx) // 30 (base only), uncapped

        // Travel capped at 100, Groceries adds its full 30.
        XCTAssertEqual(RewardCalculator.cycleReward(for: card), Decimal(130))
    }

    func testCategoryCap_ResetsPerCalendarMonth() throws {
        let ctx = try makeContext()
        let card = makeCappedMilesCard(base: 1, category: "Travel", bonus: 3, cap: 100, in: ctx)
        // Two months of Travel spend, each exceeding the cap.
        let june = makeTxn(amount: Decimal(50), category: "Travel", date: date(year: 2026, month: 6, day: 10), card: card, in: ctx)
        let july = makeTxn(amount: Decimal(50), category: "Travel", date: date(year: 2026, month: 7, day: 10), card: card, in: ctx)

        let effective = RewardCalculator.categoryCappedRewards(for: card)
        // Each calendar month's Travel reward is independently clamped to 100.
        XCTAssertEqual(effective[june.id], Decimal(100))
        XCTAssertEqual(effective[july.id], Decimal(100))
    }

    func testCategoryCap_AllocatesChronologically() throws {
        let ctx = try makeContext()
        let card = makeCappedMilesCard(base: 1, category: "Travel", bonus: 3, cap: 100, in: ctx)
        // Same month: first tx earns 80, second is clipped to the remaining 20.
        let first = makeTxn(amount: Decimal(20), category: "Travel", date: date(year: 2026, month: 7, day: 1), card: card, in: ctx)
        let second = makeTxn(amount: Decimal(20), category: "Travel", date: date(year: 2026, month: 7, day: 2), card: card, in: ctx)

        let effective = RewardCalculator.categoryCappedRewards(for: card)
        XCTAssertEqual(effective[first.id], Decimal(80))
        XCTAssertEqual(effective[second.id], Decimal(20))
    }

    func testCategoryCap_ComposesWithCardWideCap() throws {
        let ctx = try makeContext()
        let card = makeCappedMilesCard(base: 1, category: "Travel", bonus: 3, cap: 100, in: ctx)
        card.maxMilesCap = 60 // card-wide cycle cap, applied on top of the category cap
        _ = makeTxn(amount: Decimal(50), category: "Travel", card: card, in: ctx) // 200 → category-capped 100

        let status = RewardCalculator.cycleRewardStatus(for: card)
        XCTAssertEqual(status.uncapped, Decimal(100)) // after category cap, before card-wide cap
        XCTAssertEqual(status.earned, Decimal(60))     // card-wide cap clamps further
        XCTAssertTrue(status.isCapReached)
    }

    func testCategoryCap_ZeroCapMeansUncapped() throws {
        let ctx = try makeContext()
        // maxRewardCap 0 = no cap → behaves exactly as before.
        let card = makeCappedMilesCard(base: 1, category: "Travel", bonus: 3, cap: 0, in: ctx)
        let tx = makeTxn(amount: Decimal(50), category: "Travel", card: card, in: ctx) // 200 miles

        XCTAssertEqual(RewardCalculator.categoryCappedRewards(for: card)[tx.id], Decimal(200))
        XCTAssertEqual(RewardCalculator.cycleReward(for: card), Decimal(200))
    }

    func testBreakdown_ReflectsCategoryCap() throws {
        let ctx = try makeContext()
        let card = makeCappedMilesCard(base: 1, category: "Travel", bonus: 3, cap: 100, in: ctx)
        _ = makeTxn(amount: Decimal(20), category: "Travel", date: date(year: 2026, month: 7, day: 1), card: card, in: ctx) // 80, fills toward cap
        let second = makeTxn(amount: Decimal(20), category: "Travel", date: date(year: 2026, month: 7, day: 2), card: card, in: ctx)

        let breakdown = try XCTUnwrap(RewardCalculator.breakdown(for: second))
        XCTAssertEqual(breakdown.reward, Decimal(80))          // raw
        XCTAssertEqual(breakdown.cappedReward, Decimal(20))    // clipped to remaining allowance
        XCTAssertEqual(breakdown.monthlyCategoryCap, Decimal(100))
        XCTAssertTrue(breakdown.isCategoryCapReached)
    }

    func testMonthlyCategoryCap_LookupIsCaseInsensitive() throws {
        let ctx = try makeContext()
        let card = makeCappedMilesCard(base: 1, category: "Travel", bonus: 3, cap: 100, in: ctx)
        XCTAssertEqual(RewardCalculator.monthlyCategoryCap(for: card, category: "travel"), Decimal(100))
        XCTAssertNil(RewardCalculator.monthlyCategoryCap(for: card, category: "Groceries"))
    }
}
