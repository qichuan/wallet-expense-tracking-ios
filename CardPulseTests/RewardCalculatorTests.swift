//
//  RewardCalculatorTests.swift
//  CardPulseTests
//

import XCTest
import SwiftData
@testable import CardPulse

final class RewardCalculatorTests: XCTestCase {

    /// The currency-rate logic compares against `CurrencyUtils.defaultCurrencyCode`
    /// (UserDefaults-backed), so pin it to SGD for the test run and restore after.
    private var savedDefaultCurrency: String?

    override func setUp() {
        super.setUp()
        savedDefaultCurrency = UserDefaults.standard.string(forKey: CurrencyUtils.defaultCurrencyKey)
        UserDefaults.standard.set("SGD", forKey: CurrencyUtils.defaultCurrencyKey)
    }

    override func tearDown() {
        if let saved = savedDefaultCurrency {
            UserDefaults.standard.set(saved, forKey: CurrencyUtils.defaultCurrencyKey)
        } else {
            UserDefaults.standard.removeObject(forKey: CurrencyUtils.defaultCurrencyKey)
        }
        super.tearDown()
    }

    // MARK: - Helpers

    /// Returns an in-memory container holding the live schema. Used so we can
    /// instantiate `Card`/`Transaction`/`CardRewardRule` with the relationships
    /// the calculator depends on. Each test gets its own context.
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Card.self, Transaction.self, SpendingCategory.self, CardRewardRule.self, CardCurrencyRule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeCard(rewardType: RewardType,
                          baseRate: Decimal,
                          block: Decimal = 1,
                          foreignRate: Decimal = 0,
                          rules: [(category: String, rate: Decimal)] = [],
                          currencyRules: [(code: String, rate: Decimal)] = [],
                          in context: ModelContext) -> Card {
        let card = Card(
            name: "Test Card",
            minimumSpendingAmount: 0,
            hasMinimumSpending: false,
            rewardType: rewardType,
            baseRewardRate: baseRate,
            roundingBlock: block,
            foreignRewardRate: foreignRate
        )
        context.insert(card)
        for r in rules {
            let rule = CardRewardRule(card: card, categoryName: r.category, rate: r.rate)
            context.insert(rule)
        }
        for r in currencyRules {
            let rule = CardCurrencyRule(card: card, currencyCode: r.code, rate: r.rate)
            context.insert(rule)
        }
        return card
    }

    private func makeTxn(amount: Decimal, category: String? = nil, card: Card?, currency: String = "", in context: ModelContext) -> Transaction {
        let tx = Transaction(merchant: "Test", amount: amount, date: Date(), category: category, card: card, currency: currency)
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

    // MARK: - Currency rates
    //
    // The UOB PRVI Miles shape from issue #25: 1.2 mpd local (SGD), 2.4 mpd on
    // any foreign currency, 3 mpd on specific currencies. Currency rates replace
    // the base rate; category bonuses still add on top.

    func testForeignRate_AppliesToNonDefaultCurrency() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.2, foreignRate: 2.4, in: ctx)
        let local = makeTxn(amount: Decimal(100), card: card, currency: "SGD", in: ctx)
        let foreign = makeTxn(amount: Decimal(100), card: card, currency: "USD", in: ctx)

        XCTAssertEqual(RewardCalculator.reward(for: local), Decimal(120))   // 100 * 1.2
        XCTAssertEqual(RewardCalculator.reward(for: foreign), Decimal(240)) // 100 * 2.4
    }

    func testForeignRate_EmptyCurrency_ResolvesToDefault_UsesBaseRate() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.2, foreignRate: 2.4, in: ctx)
        // Empty currency means "use the default currency" — must not earn the foreign rate.
        let tx = makeTxn(amount: Decimal(100), card: card, currency: "", in: ctx)

        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(120))
    }

    func testForeignRate_Unset_ForeignSpendEarnsBaseRate() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.2, foreignRate: 0, in: ctx)
        let tx = makeTxn(amount: Decimal(100), card: card, currency: "USD", in: ctx)

        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(120))
    }

    func testCurrencyRule_BeatsForeignRate() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.2, foreignRate: 2.4,
                            currencyRules: [(code: "MYR", rate: 3.0)], in: ctx)
        let myr = makeTxn(amount: Decimal(100), card: card, currency: "MYR", in: ctx)
        let usd = makeTxn(amount: Decimal(100), card: card, currency: "USD", in: ctx)

        XCTAssertEqual(RewardCalculator.reward(for: myr), Decimal(300)) // per-currency rule
        XCTAssertEqual(RewardCalculator.reward(for: usd), Decimal(240)) // blanket foreign rate
    }

    func testCurrencyRule_CaseInsensitiveMatch() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.2,
                            currencyRules: [(code: "MYR", rate: 3.0)], in: ctx)
        let tx = makeTxn(amount: Decimal(100), card: card, currency: "myr", in: ctx)

        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(300))
    }

    func testCurrencyRate_ReplacesBase_CategoryBonusStillAdds() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.2, foreignRate: 2.4,
                            rules: [(category: "Travel", rate: 4.0)],
                            currencyRules: [(code: "MYR", rate: 3.0)], in: ctx)
        // Currency rate replaces base (3, not 1.2 + 3), then the bonus adds: 3 + 4 = 7 mpd.
        let tx = makeTxn(amount: Decimal(100), category: "Travel", card: card, currency: "MYR", in: ctx)

        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(700))
    }

    func testCurrencyRate_RespectsRoundingBlock() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.2, block: 5, foreignRate: 2.4, in: ctx)
        // 36.35 → rounded to 35 → 35 * 2.4 = 84 miles.
        let tx = makeTxn(amount: Decimal(string: "36.35")!, card: card, currency: "USD", in: ctx)

        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(84))
    }

    func testForeignRate_Cashback_TreatedAsPercent() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 1.6, foreignRate: 3.0, in: ctx)
        let tx = makeTxn(amount: Decimal(100), card: card, currency: "USD", in: ctx)

        // 100 * 0.03 = 3.0
        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(3))
    }

    func testBreakdown_CurrencyOverride_PopulatesCurrencyFields() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.2, foreignRate: 2.4,
                            currencyRules: [(code: "MYR", rate: 3.0)], in: ctx)
        let tx = makeTxn(amount: Decimal(100), card: card, currency: "MYR", in: ctx)

        let breakdown = RewardCalculator.breakdown(for: tx)
        XCTAssertEqual(breakdown?.currencyCode, "MYR")
        XCTAssertEqual(breakdown?.currencyRate, Decimal(3))
        XCTAssertEqual(breakdown?.baseRate, Decimal(string: "1.2"))
        XCTAssertEqual(breakdown?.effectiveRate, Decimal(3))
        XCTAssertEqual(breakdown?.reward, Decimal(300))
    }

    func testBreakdown_DefaultCurrency_HasNoCurrencyFields() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.2, foreignRate: 2.4,
                            currencyRules: [(code: "MYR", rate: 3.0)], in: ctx)
        let tx = makeTxn(amount: Decimal(100), card: card, currency: "SGD", in: ctx)

        let breakdown = RewardCalculator.breakdown(for: tx)
        XCTAssertNil(breakdown?.currencyCode)
        XCTAssertEqual(breakdown?.currencyRate, Decimal(0))
        XCTAssertEqual(breakdown?.effectiveRate, Decimal(string: "1.2"))
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
}
