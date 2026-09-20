//
//  CategoryInferenceTests.swift
//  CardPulseTests
//

import XCTest
@testable import CardPulse

/// Covers the pure parts of the category cascade: decoding the category API's
/// reply, the confidence gate, mapping an answer back onto a stored category,
/// the offline keyword heuristic, and the icon-derived hints sent as the
/// model's per-option descriptions. The network call itself is integration-only
/// and not covered here.
final class CategoryInferenceTests: XCTestCase {

    // MARK: - Helpers

    private func decode(_ json: String) throws -> CategoryInference.ResponseBody {
        try JSONDecoder().decode(CategoryInference.ResponseBody.self, from: Data(json.utf8))
    }

    // MARK: - Response decoding

    func testDecodesFullResponse() throws {
        let decoded = try decode("""
        {
          "category": "Food & Drinks",
          "confidence": 0.93,
          "probabilities": { "Food & Drinks": 0.91, "Shopping": 0.06, "Other": 0.03 },
          "model": "jev-1.13.0"
        }
        """)
        XCTAssertEqual(decoded.category, "Food & Drinks")
        XCTAssertEqual(decoded.confidence, 0.93, accuracy: 0.0001)
        XCTAssertEqual(decoded.probabilities?["Shopping"], 0.06)
        XCTAssertEqual(decoded.model, "jev-1.13.0")
    }

    func testDecodesResponseWithoutOptionalFields() throws {
        let decoded = try decode(#"{ "category": "Travel", "confidence": 0.8 }"#)
        XCTAssertEqual(decoded.category, "Travel")
        XCTAssertNil(decoded.probabilities)
        XCTAssertNil(decoded.model)
    }

    // MARK: - Confidence gate

    func testHighConfidenceAnswerIsAccepted() throws {
        let decoded = try decode(#"{ "category": "Food & Drinks", "confidence": 0.93 }"#)
        let resolved = CategoryInference.resolvedCategory(
            from: decoded,
            among: ["Food & Drinks", "Other"]
        )
        XCTAssertEqual(resolved, "Food & Drinks")
    }

    func testLowConfidenceAnswerIsRejected() throws {
        let decoded = try decode(#"{ "category": "Food & Drinks", "confidence": 0.41 }"#)
        XCTAssertNil(CategoryInference.resolvedCategory(
            from: decoded,
            among: ["Food & Drinks", "Other"]
        ))
    }

    func testConfidenceExactlyAtThresholdIsAccepted() throws {
        let decoded = try decode(#"{ "category": "Travel", "confidence": 0.6 }"#)
        XCTAssertEqual(
            CategoryInference.resolvedCategory(from: decoded, among: ["Travel"]),
            "Travel"
        )
    }

    // MARK: - Mapping back onto stored categories

    func testAnswerIsCanonicalisedToStoredSpelling() throws {
        // The API echoes what it was sent, but a differently-cased reply must
        // still resolve to the stored record's exact name — MerchantUtils
        // collapses anything it doesn't recognise to "Other".
        let decoded = try decode(#"{ "category": "food & drinks", "confidence": 0.9 }"#)
        XCTAssertEqual(
            CategoryInference.resolvedCategory(from: decoded, among: ["Food & Drinks"]),
            "Food & Drinks"
        )
    }

    func testCustomCategoryResolves() throws {
        let decoded = try decode(#"{ "category": "Pet Care", "confidence": 0.88 }"#)
        XCTAssertEqual(
            CategoryInference.resolvedCategory(
                from: decoded,
                among: ["Other", "Pet Care"]
            ),
            "Pet Care"
        )
    }

    func testUnknownCategoryNameIsRejected() throws {
        let decoded = try decode(#"{ "category": "Groceries", "confidence": 0.99 }"#)
        XCTAssertNil(CategoryInference.resolvedCategory(
            from: decoded,
            among: ["Shopping", "Other"]
        ))
    }

    func testEmptyCategoryNameIsRejected() throws {
        let decoded = try decode(#"{ "category": "   ", "confidence": 0.99 }"#)
        XCTAssertNil(CategoryInference.resolvedCategory(from: decoded, among: ["Other"]))
    }

    // MARK: - Offline heuristic

    func testHeuristicMatchesKnownMerchants() {
        XCTAssertEqual(CategoryInference.heuristicCategory(for: "UBER *TRIP"), "Travel")
        XCTAssertEqual(CategoryInference.heuristicCategory(for: "starbucks coffee"), "Food & Drinks")
        XCTAssertEqual(CategoryInference.heuristicCategory(for: "NETFLIX.COM"), "Entertainment")
        XCTAssertEqual(CategoryInference.heuristicCategory(for: "CVS Pharmacy #123"), "Health")
    }

    func testHeuristicFallsBackToOther() {
        XCTAssertEqual(CategoryInference.heuristicCategory(for: "BLAHCORP PTE LTD"), "Other")
        XCTAssertEqual(CategoryInference.heuristicCategory(for: ""), "Other")
    }

    // MARK: - Icon-derived hints

    func testIconKeywordsUsesCuratedMapping() {
        XCTAssertEqual(CategoryInference.iconKeywords("fork.knife"), "food restaurant dining")
        XCTAssertEqual(CategoryInference.iconKeywords("airplane"), "flight travel airline")
    }

    func testIconKeywordsFallsBackToSplittingSymbolName() {
        // Unmapped symbols are still descriptive once the dots are removed.
        XCTAssertEqual(CategoryInference.iconKeywords("figure.walk"), "figure walk")
    }

    func testEveryBuiltInCategoryIconHasAHint() {
        for name in MerchantUtils.defaultCategories {
            let hint = CategoryInference.iconKeywords(MerchantUtils.defaultIcon(for: name))
            XCTAssertFalse(hint.isEmpty, "No hint produced for built-in category \(name)")
        }
    }
}
