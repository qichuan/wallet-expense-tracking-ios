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

    private func makeTxn(amount: Decimal, category: String? = nil, card: Card?, in context: ModelContext) -> Transaction {
        let tx = Transaction(merchant: "Test", amount: amount, date: Date(), category: category, card: card)
        context.insert(tx)
        return tx
    }

    // MARK: - Cashback

    func testCashback_FlatPercentage() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 1.6, in: ctx)
        let tx = makeTxn(amount: Decimal(string: "1050.50")!, card: card, in: ctx)

        let reward = RewardCalculator.reward(for: tx)
        XCTAssertNotNil(reward)
        // 1050.50 * 0.016 = 16.808
        XCTAssertEqual(reward, Decimal(string: "16.808"))
    }

    func testCashback_NoRoundingByDefault() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 2.0, block: 1, in: ctx)
        let tx = makeTxn(amount: Decimal(string: "36.35")!, card: card, in: ctx)

        // 36.35 * 0.02 = 0.727
        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(string: "0.727"))
    }

    // MARK: - Miles

    func testMiles_BaseRateNoRounding() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.4, block: 1, in: ctx)
        let tx = makeTxn(amount: Decimal(string: "100")!, card: card, in: ctx)

        // 100 * 1.4 = 140
        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(140))
    }

    /// UOB-style $5 rounding-down example from the design brief:
    /// $36.35 → rounded to $35 → 35 * 1.4 = 49 miles.
    func testMiles_FiveDollarBlockRoundsDown() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.4, block: 5, in: ctx)
        let tx = makeTxn(amount: Decimal(string: "36.35")!, card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(49))
    }

    func testMiles_BlockRoundingDoesNotRoundUp() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.0, block: 5, in: ctx)
        // 4.99 must round DOWN to 0, not UP to 5.
        let tx = makeTxn(amount: Decimal(string: "4.99")!, card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(0))
    }

    func testMiles_ExactBlockBoundary() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.0, block: 5, in: ctx)
        let tx = makeTxn(amount: Decimal(string: "35.00")!, card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(35))
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

        XCTAssertEqual(RewardCalculator.reward(for: bonus), Decimal(400))
        XCTAssertEqual(RewardCalculator.reward(for: baseline), Decimal(140))
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
        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(string: "4.0"))
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

        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(70)) // 50 * 1.4
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

        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(140))
    }

    // MARK: - Edge cases

    func testReward_NilForNoneRewardType() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .none, baseRate: 0, in: ctx)
        let tx = makeTxn(amount: Decimal(100), card: card, in: ctx)

        XCTAssertNil(RewardCalculator.reward(for: tx))
    }

    func testReward_NilForCardlessTransaction() throws {
        let ctx = try makeContext()
        let tx = makeTxn(amount: Decimal(100), card: nil, in: ctx)

        XCTAssertNil(RewardCalculator.reward(for: tx))
    }

    func testReward_ZeroRate_ReturnsZero() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 0, in: ctx)
        let tx = makeTxn(amount: Decimal(100), card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(0))
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
}
