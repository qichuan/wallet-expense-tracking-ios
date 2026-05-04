//
//  AnalyticsTracker.swift
//  CardPulse
//

import Foundation
import FirebaseAnalytics

enum AnalyticsTracker {

    // MARK: - Event names
    enum Event {
        // Cards
        static let cardAdded = "card_added"
        static let cardDeleted = "card_deleted"

        // Categories
        static let categoryAdded = "category_added"
        static let categoryDeleted = "category_deleted"

        // Currencies
        static let currencyCustomAdded = "currency_custom_added"
        static let currencyEnabled = "currency_enabled"
        static let currencyDisabled = "currency_disabled"
        static let currencyDefaultSet = "currency_default_set"
        static let exchangeRateRefreshed = "exchange_rate_refreshed"

        // Data
        static let importStarted = "import_started"
        static let importCompleted = "import_completed"
        static let importFailed = "import_failed"
        static let exportStarted = "export_started"
        static let exportCompleted = "export_completed"

        // Misc
        static let contactDeveloper = "contact_developer"
        static let onboardingCompleted = "onboarding_completed"
        static let merchantSuggestionSelected = "merchant_suggestion_selected"
    }

    /// Logs an event with optional sanitised parameters.
    /// Firebase Analytics restricts parameter values to 100 chars; we trim defensively.
    /// Debug builds skip the network call entirely so dev sessions don't pollute prod analytics.
    static func log(_ name: String, _ parameters: [String: Any] = [:]) {
        var sanitised: [String: Any] = [:]
        for (key, value) in parameters {
            if let s = value as? String {
                sanitised[key] = String(s.prefix(100))
            } else {
                sanitised[key] = value
            }
        }
        #if DEBUG
        print("[Analytics:DEBUG-skipped] \(name) \(sanitised)")
        #else
        Analytics.logEvent(name, parameters: sanitised.isEmpty ? nil : sanitised)
        #endif
    }

    /// Logs a "view" action — use when the user opens or navigates to a screen/sheet.
    static func view(_ screen: String, _ parameters: [String: Any] = [:]) {
        var params = parameters
        params["screen"] = screen
        log("view", params)
    }

    /// Logs an "edit" action — use when the user modifies existing data.
    static func edit(_ subject: String, _ parameters: [String: Any] = [:]) {
        var params = parameters
        params["subject"] = subject
        log("edit", params)
    }
}
