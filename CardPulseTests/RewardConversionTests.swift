//
//  RewardConversionTests.swift
//  CardPulseTests
//

import XCTest
import SwiftData
@testable import CardPulse

/// Covers the FX-conversion step of reward calculation (issue #36): foreign-currency
/// spend is converted to the default currency, block-rounded, and only then
/// multiplied by the reward rate — for miles and cashback alike. This is the same
/// pipeline the transaction row and detail breakdown render.
///
/// The conversion path reads `UserDefaults.standard` through `CurrencyUtils`, so
/// `setUp` seeds a deterministic default currency and rate cache and `tearDown`
/// restores whatever the host had, leaving device state untouched.
final class RewardConversionTests: XCTestCase {

    private var savedRates: Data?
    private var savedDefaultCurrency: String?

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        savedRates = defaults.data(forKey: CurrencyUtils.exchangeRatesKey)
        savedDefaultCurrency = defaults.string(forKey: CurrencyUtils.defaultCurrencyKey)
        CurrencyUtils.defaultCurrencyCode = "SGD"
        // 1 MYR = 0.25 SGD. 0.25 is exactly representable as a Double, so the
        // Double → Decimal conversion inside `amountInDefaultCurrency` is exact
        // and the assertions below can use strict equality.
        CurrencyUtils.cachedRates = ["MYR": 0.25]
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        if let savedRates {
            defaults.set(savedRates, forKey: CurrencyUtils.exchangeRatesKey)
        } else {
            defaults.removeObject(forKey: CurrencyUtils.exchangeRatesKey)
        }
        if let savedDefaultCurrency {
            defaults.set(savedDefaultCurrency, forKey: CurrencyUtils.defaultCurrencyKey)
        } else {
            defaults.removeObject(forKey: CurrencyUtils.defaultCurrencyKey)
        }
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Card.self, Transaction.self, SpendingCategory.self, CardRewardRule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeCard(rewardType: RewardType,
                          baseRate: Decimal,
                          block: Decimal = 1,
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
        return card
    }

    private func makeTxn(amount: Decimal, currency: String, card: Card?, in context: ModelContext) -> Transaction {
        let tx = Transaction(merchant: "Test", amount: amount, date: Date(), card: card, currency: currency)
        context.insert(tx)
        return tx
    }

    // MARK: - Conversion before the rate

    func testForeignMiles_ConvertsToDefaultCurrencyBeforeRate() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.4, in: ctx)
        let tx = makeTxn(amount: Decimal(400), currency: "MYR", card: card, in: ctx)

        // 400 MYR × 0.25 = S$100 → 100 × 1.4 = 140 miles.
        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(140))
        // The unconverted variant would inflate this to 400 × 1.4 = 560 — the
        // exact bug this pipeline guards against.
        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(560))
    }

    /// Block rounding must apply to the *converted* amount, matching the UOB-style
    /// example: 145.40 MYR → S$36.35 → $5 block → S$35 → 35 × 1.4 = 49 miles.
    /// (Rounding the raw MYR amount first would give 145 × 0.25 × 1.4 = 50.75.)
    func testForeignMiles_BlockRoundingAppliesToConvertedAmount() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.4, block: 5, in: ctx)
        let tx = makeTxn(amount: Decimal(string: "145.40")!, currency: "MYR", card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(49))
    }

    func testDefaultCurrencyMiles_ConversionIsIdentity() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.4, in: ctx)
        let tx = makeTxn(amount: Decimal(100), currency: "SGD", card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(140))
        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), RewardCalculator.reward(for: tx))
    }

    // MARK: - Breakdown (what the transaction detail view renders)

    func testBreakdown_ForeignMiles_ShowsConvertedAmountsAndDefaultCurrency() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.4, block: 5, in: ctx)
        let tx = makeTxn(amount: Decimal(string: "145.40")!, currency: "MYR", card: card, in: ctx)

        let breakdown = try XCTUnwrap(RewardCalculator.breakdown(for: tx))
        XCTAssertEqual(breakdown.amount, Decimal(string: "36.35"))   // converted, pre-rounding
        XCTAssertEqual(breakdown.rounded, Decimal(35))               // $5 block on converted amount
        XCTAssertEqual(breakdown.reward, Decimal(49))                // 35 × 1.4
        XCTAssertEqual(breakdown.currencyCode, "SGD")
        XCTAssertEqual(breakdown.transactionCurrency, "MYR")
        XCTAssertTrue(breakdown.isConverted)
    }

    func testBreakdown_DefaultCurrencyMiles_NotMarkedConverted() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.4, in: ctx)
        let tx = makeTxn(amount: Decimal(100), currency: "SGD", card: card, in: ctx)

        let breakdown = try XCTUnwrap(RewardCalculator.breakdown(for: tx))
        XCTAssertEqual(breakdown.amount, Decimal(100))
        XCTAssertEqual(breakdown.currencyCode, "SGD")
        XCTAssertFalse(breakdown.isConverted)
    }

    func testBreakdown_ForeignCashback_ShowsConvertedAmountsAndDefaultCurrency() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 2.0, in: ctx)
        let tx = makeTxn(amount: Decimal(400), currency: "MYR", card: card, in: ctx)

        let breakdown = try XCTUnwrap(RewardCalculator.breakdown(for: tx))
        XCTAssertEqual(breakdown.amount, Decimal(100))      // 400 MYR × 0.25
        XCTAssertEqual(breakdown.currencyCode, "SGD")
        XCTAssertEqual(breakdown.transactionCurrency, "MYR")
        XCTAssertTrue(breakdown.isConverted)
        XCTAssertEqual(breakdown.reward, Decimal(2))        // S$100 × 2%
    }

    // MARK: - Cashback conversion

    func testForeignCashback_ConvertsToDefaultCurrencyBeforeRate() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 2.0, in: ctx)
        let tx = makeTxn(amount: Decimal(400), currency: "MYR", card: card, in: ctx)

        // 400 MYR × 0.25 = S$100 → 100 × 2% = S$2 cashback.
        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(2))
        // The unconverted variant earns in MYR (RM8) — four times the value if
        // misread as default currency.
        XCTAssertEqual(RewardCalculator.reward(for: tx), Decimal(8))
    }

    /// Block rounding must apply to the *converted* amount for cashback too:
    /// 145.40 MYR → S$36.35 → $5 block → S$35 → 35 × 2% = S$0.70.
    func testForeignCashback_BlockRoundingAppliesToConvertedAmount() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 2.0, block: 5, in: ctx)
        let tx = makeTxn(amount: Decimal(string: "145.40")!, currency: "MYR", card: card, in: ctx)

        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(string: "0.7"))
    }

    // MARK: - Missing-rate fallback

    func testForeignMiles_NoCachedRate_FallsBackToRawAmount() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.4, in: ctx)
        // EUR is deliberately absent from the seeded rate cache.
        let tx = makeTxn(amount: Decimal(100), currency: "EUR", card: card, in: ctx)

        // Spend is never dropped: with no rate the raw amount is used…
        XCTAssertEqual(RewardCalculator.convertedReward(for: tx), Decimal(140))

        // …and the breakdown keeps the transaction's currency rather than
        // mislabeling unconverted values with the default symbol.
        let breakdown = try XCTUnwrap(RewardCalculator.breakdown(for: tx))
        XCTAssertEqual(breakdown.currencyCode, "EUR")
        XCTAssertFalse(breakdown.isConverted)
    }

    // MARK: - Aggregate

    func testAggregate_MixedCurrencyMiles_SumsConvertedValues() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .miles, baseRate: 1.0, in: ctx)
        let txs = [
            makeTxn(amount: Decimal(100), currency: "SGD", card: card, in: ctx),
            makeTxn(amount: Decimal(400), currency: "MYR", card: card, in: ctx), // S$100
        ]

        XCTAssertEqual(RewardCalculator.aggregate(txs).miles, Decimal(200))
    }

    func testAggregate_MixedCurrencyCashback_SumsInDefaultCurrency() throws {
        let ctx = try makeContext()
        let card = makeCard(rewardType: .cashback, baseRate: 1.0, in: ctx)
        let txs = [
            makeTxn(amount: Decimal(100), currency: "SGD", card: card, in: ctx), // S$1.00
            makeTxn(amount: Decimal(400), currency: "MYR", card: card, in: ctx), // S$100 → S$1.00
        ]

        XCTAssertEqual(RewardCalculator.aggregate(txs).cashback, Decimal(2))
    }
}
