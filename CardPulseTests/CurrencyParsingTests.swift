//
//  CurrencyParsingTests.swift
//  CardPulseTests
//

import XCTest
@testable import CardPulse

final class CurrencyParsingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Set a known default currency so tests are deterministic
        UserDefaults.standard.set("SGD", forKey: CurrencyUtils.defaultCurrencyKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: CurrencyUtils.defaultCurrencyKey)
        super.tearDown()
    }

    // MARK: - ISO code prefix

    func testISOCodePrefix_SGD() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "SGD 12.50")
        XCTAssertEqual(result?.0, "SGD")
        XCTAssertEqual(result?.1, Decimal(string: "12.50"))
    }

    func testISOCodePrefix_MYR() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "MYR 8.00")
        XCTAssertEqual(result?.0, "MYR")
        XCTAssertEqual(result?.1, Decimal(string: "8.00"))
    }

    func testISOCodePrefix_USD() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "USD 100")
        XCTAssertEqual(result?.0, "USD")
        XCTAssertEqual(result?.1, Decimal(100))
    }

    func testISOCodePrefix_EUR() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "EUR 50.99")
        XCTAssertEqual(result?.0, "EUR")
        XCTAssertEqual(result?.1, Decimal(string: "50.99"))
    }

    func testISOCodePrefix_GBP() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "GBP 25.00")
        XCTAssertEqual(result?.0, "GBP")
        XCTAssertEqual(result?.1, Decimal(string: "25.00"))
    }

    func testISOCodePrefix_JPY() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "JPY 1500")
        XCTAssertEqual(result?.0, "JPY")
        XCTAssertEqual(result?.1, Decimal(1500))
    }

    func testISOCodePrefix_noSpace() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "SGD12.50")
        XCTAssertEqual(result?.0, "SGD")
        XCTAssertEqual(result?.1, Decimal(string: "12.50"))
    }

    func testISOCodePrefix_lowercased() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "sgd 12.50")
        XCTAssertEqual(result?.0, "SGD")
        XCTAssertEqual(result?.1, Decimal(string: "12.50"))
    }

    // MARK: - ISO code suffix

    func testISOCodeSuffix_MYR() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "8.00 MYR")
        XCTAssertEqual(result?.0, "MYR")
        XCTAssertEqual(result?.1, Decimal(string: "8.00"))
    }

    func testISOCodeSuffix_USD() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "100.00 USD")
        XCTAssertEqual(result?.0, "USD")
        XCTAssertEqual(result?.1, Decimal(string: "100.00"))
    }

    func testISOCodeSuffix_EUR() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "50.99 EUR")
        XCTAssertEqual(result?.0, "EUR")
        XCTAssertEqual(result?.1, Decimal(string: "50.99"))
    }

    // MARK: - Currency symbol prefix

    func testSymbolPrefix_SGD() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "S$12.50")
        XCTAssertEqual(result?.0, "SGD")
        XCTAssertEqual(result?.1, Decimal(string: "12.50"))
    }

    func testSymbolPrefix_SGD_withSpace() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "S$ 12.50")
        XCTAssertEqual(result?.0, "SGD")
        XCTAssertEqual(result?.1, Decimal(string: "12.50"))
    }

    func testSymbolPrefix_MYR() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "RM8.00")
        XCTAssertEqual(result?.0, "MYR")
        XCTAssertEqual(result?.1, Decimal(string: "8.00"))
    }

    func testSymbolPrefix_MYR_withSpace() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "RM 8.00")
        XCTAssertEqual(result?.0, "MYR")
        XCTAssertEqual(result?.1, Decimal(string: "8.00"))
    }

    func testSymbolPrefix_EUR() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "€50.99")
        XCTAssertEqual(result?.0, "EUR")
        XCTAssertEqual(result?.1, Decimal(string: "50.99"))
    }

    func testSymbolPrefix_GBP() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "£25.00")
        XCTAssertEqual(result?.0, "GBP")
        XCTAssertEqual(result?.1, Decimal(string: "25.00"))
    }

    func testSymbolPrefix_JPY_yen() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "¥1500")
        XCTAssertEqual(result?.0, "JPY")
        XCTAssertEqual(result?.1, Decimal(1500))
    }

    func testSymbolPrefix_HKD() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "HK$88.00")
        XCTAssertEqual(result?.0, "HKD")
        XCTAssertEqual(result?.1, Decimal(string: "88.00"))
    }

    func testSymbolPrefix_AUD() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "A$45.00")
        XCTAssertEqual(result?.0, "AUD")
        XCTAssertEqual(result?.1, Decimal(string: "45.00"))
    }

    func testSymbolPrefix_CAD() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "C$30.00")
        XCTAssertEqual(result?.0, "CAD")
        XCTAssertEqual(result?.1, Decimal(string: "30.00"))
    }

    func testSymbolPrefix_KRW() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "₩50000")
        XCTAssertEqual(result?.0, "KRW")
        XCTAssertEqual(result?.1, Decimal(50000))
    }

    func testSymbolPrefix_INR() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "₹500")
        XCTAssertEqual(result?.0, "INR")
        XCTAssertEqual(result?.1, Decimal(500))
    }

    func testSymbolPrefix_PHP() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "₱200")
        XCTAssertEqual(result?.0, "PHP")
        XCTAssertEqual(result?.1, Decimal(200))
    }

    func testSymbolPrefix_THB() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "฿300")
        XCTAssertEqual(result?.0, "THB")
        XCTAssertEqual(result?.1, Decimal(300))
    }

    func testSymbolPrefix_IDR() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "Rp50000")
        XCTAssertEqual(result?.0, "IDR")
        XCTAssertEqual(result?.1, Decimal(50000))
    }

    // MARK: - Apple Pay country-disambiguated symbols

    func testApplePaySymbol_JPY() {
        // Sample from Apple Pay (issue #30): "JP¥1,630"
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "JP¥1,630")
        XCTAssertEqual(result?.0, "JPY")
        XCTAssertEqual(result?.1, Decimal(1630))
    }

    func testApplePaySymbol_JPY_withSpace() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "JP¥ 1,630")
        XCTAssertEqual(result?.0, "JPY")
        XCTAssertEqual(result?.1, Decimal(1630))
    }

    func testApplePaySymbol_CNY() {
        // CN¥ shares the "¥" glyph with yen but must resolve to yuan.
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "CN¥88.00")
        XCTAssertEqual(result?.0, "CNY")
        XCTAssertEqual(result?.1, Decimal(string: "88.00"))
    }

    func testBareYen_stillResolvesToJPY() {
        // Without a country prefix the bare glyph keeps its existing behaviour.
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "¥1500")
        XCTAssertEqual(result?.0, "JPY")
        XCTAssertEqual(result?.1, Decimal(1500))
    }

    // MARK: - Bare dollar sign ($) uses default currency

    func testBareDollarSign_usesDefaultCurrency() {
        UserDefaults.standard.set("SGD", forKey: CurrencyUtils.defaultCurrencyKey)
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "$4.99")
        XCTAssertEqual(result?.0, "SGD")
        XCTAssertEqual(result?.1, Decimal(string: "4.99"))
    }

    func testBareDollarSign_usesDefaultCurrency_USD() {
        UserDefaults.standard.set("USD", forKey: CurrencyUtils.defaultCurrencyKey)
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "$4.99")
        XCTAssertEqual(result?.0, "USD")
        XCTAssertEqual(result?.1, Decimal(string: "4.99"))
    }

    // MARK: - Bare number (no currency symbol/code)

    func testBareNumber_usesDefaultCurrency() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "12.50")
        XCTAssertEqual(result?.0, "SGD")
        XCTAssertEqual(result?.1, Decimal(string: "12.50"))
    }

    func testBareNumber_integer() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "100")
        XCTAssertEqual(result?.0, "SGD")
        XCTAssertEqual(result?.1, Decimal(100))
    }

    // MARK: - Thousand separators

    func testThousandSeparators_prefix() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "SGD 1,250.00")
        XCTAssertEqual(result?.0, "SGD")
        XCTAssertEqual(result?.1, Decimal(string: "1250.00"))
    }

    func testThousandSeparators_bare() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "1,000")
        XCTAssertEqual(result?.0, "SGD")
        XCTAssertEqual(result?.1, Decimal(1000))
    }

    func testThousandSeparators_symbol() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "₩1,000,000")
        XCTAssertEqual(result?.0, "KRW")
        XCTAssertEqual(result?.1, Decimal(1000000))
    }

    // MARK: - Whitespace handling

    func testLeadingTrailingWhitespace() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "  SGD 12.50  ")
        XCTAssertEqual(result?.0, "SGD")
        XCTAssertEqual(result?.1, Decimal(string: "12.50"))
    }

    func testExtraSpaceBetweenSymbolAndAmount() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "RM  8.00")
        XCTAssertEqual(result?.0, "MYR")
        XCTAssertEqual(result?.1, Decimal(string: "8.00"))
    }

    // MARK: - Invalid input

    func testInvalidInput_emptyString() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "")
        XCTAssertNil(result)
    }

    func testInvalidInput_onlyText() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "hello")
        XCTAssertNil(result)
    }

    func testInvalidInput_onlyCurrencyCode() {
        let result = CurrencyUtils.parseCurrencyAndAmount(from: "SGD")
        XCTAssertNil(result)
    }
}
