//
//  AppConfig.swift
//  CardPulse
//

import Foundation

/// Build-time configuration injected through `Config/Secrets.xcconfig`.
///
/// This repository is open source, so the category API's host and shared token
/// are never committed. `Config/App.xcconfig` optionally includes a gitignored
/// `Config/Secrets.xcconfig`, whose values land in `Info.plist` via
/// `$(CATEGORY_API_BASE_URL)` / `$(CATEGORY_API_TOKEN)`. A clone without that
/// file simply builds with the values unset, and every reader here returns nil.
enum AppConfig {

    /// Host of the category inference service, e.g. `"cardpulse-api.vercel.app"`.
    ///
    /// Stored without a scheme on purpose: xcconfig treats `//` as the start of
    /// a comment, so `https://host` would be silently truncated to `https:`.
    static var categoryAPIHost: String? { infoValue(for: "CategoryAPIBaseURL") }

    /// Shared bearer token the service requires. Extractable from the binary, so
    /// it throttles casual abuse rather than authenticating anyone.
    static var categoryAPIToken: String? { infoValue(for: "CategoryAPIToken") }

    /// Full endpoint URL, or nil when the app was built without category API config.
    static var categoryAPIURL: URL? {
        guard let host = categoryAPIHost else { return nil }
        return URL(string: "https://\(host)/api/categorize")
    }

    /// Reads an Info.plist string, treating blanks and unsubstituted build
    /// settings (`$(FOO)`, left behind when the xcconfig is absent) as unset.
    private static func infoValue(for key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
