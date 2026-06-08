//
//  CurrencyUtils.swift
//  CardPulse
//

import Foundation

struct CurrencyInfo: Identifiable, Hashable {
    let code: String   // e.g. "SGD"
    let name: String   // e.g. "Singapore Dollar"
    let symbol: String // e.g. "S$"

    var id: String { code }
    var displayName: String { "\(code) – \(name)" }
}

struct CurrencyUtils {
    static let defaultCurrencyKey = "defaultCurrency"
    static let enabledCurrenciesKey = "enabledCurrencies"
    static let customCurrenciesRawKey = "customCurrenciesRaw"

    // MARK: - Exchange rate cache keys (stored in UserDefaults)
    // "exchangeRates"          → JSON-encoded [String: Double]  (fromCode → rate-to-default)
    // "exchangeRates_fetchedAt"→ TimeInterval since 1970
    // "exchangeRates_base"     → String: defaultCurrencyCode when rates were fetched
    static let exchangeRatesKey = "exchangeRates"
    static let exchangeRatesFetchedAtKey = "exchangeRates_fetchedAt"
    static let exchangeRatesBaseKey = "exchangeRates_base"

    private static let rateCacheTTL: TimeInterval = 5 * 24 * 3600  // 5 days

    // Built-in currencies
    static let allCurrencies: [CurrencyInfo] = [
        CurrencyInfo(code: "SGD", name: "Singapore Dollar", symbol: "S$"),
        CurrencyInfo(code: "MYR", name: "Malaysian Ringgit", symbol: "RM"),
        CurrencyInfo(code: "USD", name: "US Dollar", symbol: "$"),
        CurrencyInfo(code: "EUR", name: "Euro", symbol: "€"),
        CurrencyInfo(code: "GBP", name: "British Pound", symbol: "£"),
        CurrencyInfo(code: "HKD", name: "Hong Kong Dollar", symbol: "HK$"),
        CurrencyInfo(code: "AUD", name: "Australian Dollar", symbol: "A$"),
        CurrencyInfo(code: "CAD", name: "Canadian Dollar", symbol: "C$"),
        CurrencyInfo(code: "JPY", name: "Japanese Yen", symbol: "¥"),
        CurrencyInfo(code: "CNY", name: "Chinese Yuan", symbol: "¥"),
        CurrencyInfo(code: "KRW", name: "South Korean Won", symbol: "₩"),
        CurrencyInfo(code: "THB", name: "Thai Baht", symbol: "฿"),
        CurrencyInfo(code: "IDR", name: "Indonesian Rupiah", symbol: "Rp"),
        CurrencyInfo(code: "PHP", name: "Philippine Peso", symbol: "₱"),
        CurrencyInfo(code: "INR", name: "Indian Rupee", symbol: "₹"),
    ]

    // Custom currencies stored as "CODE|Name|Symbol,CODE|Name|Symbol" in UserDefaults
    static var customCurrencies: [CurrencyInfo] {
        get {
            let raw = UserDefaults.standard.string(forKey: customCurrenciesRawKey) ?? ""
            return raw.components(separatedBy: ",")
                .filter { !$0.isEmpty }
                .compactMap { entry -> CurrencyInfo? in
                    let parts = entry.components(separatedBy: "|")
                    guard parts.count == 3 else { return nil }
                    return CurrencyInfo(code: parts[0], name: parts[1], symbol: parts[2])
                }
        }
        set {
            let raw = newValue.map { "\($0.code)|\($0.name)|\($0.symbol)" }.joined(separator: ",")
            UserDefaults.standard.set(raw, forKey: customCurrenciesRawKey)
        }
    }

    // All currencies: built-in + custom (no duplicates)
    static var allAvailableCurrencies: [CurrencyInfo] {
        let builtInCodes = Set(allCurrencies.map { $0.code })
        let uniqueCustom = customCurrencies.filter { !builtInCodes.contains($0.code) }
        return allCurrencies + uniqueCustom
    }

    static let defaultEnabledCurrencies = ["SGD", "MYR", "HKD", "USD", "EUR"]
    private static let defaultCurrenciesAppliedKey = "defaultCurrenciesV1Applied"

    /// Ensures the default major currencies are present in the enabled list.
    /// Runs once per install; safe to call on every launch.
    static func ensureDefaultCurrenciesEnabled() {
        guard !UserDefaults.standard.bool(forKey: defaultCurrenciesAppliedKey) else { return }
        var current = enabledCurrencyCodes
        for code in defaultEnabledCurrencies where !current.contains(code) {
            current.append(code)
        }
        enabledCurrencyCodes = current
        UserDefaults.standard.set(true, forKey: defaultCurrenciesAppliedKey)
    }

    // MARK: - UserDefaults accessors

    static var defaultCurrencyCode: String {
        get { UserDefaults.standard.string(forKey: defaultCurrencyKey) ?? "SGD" }
        set { UserDefaults.standard.set(newValue, forKey: defaultCurrencyKey) }
    }

    static var enabledCurrencyCodes: [String] {
        get {
            guard let stored = UserDefaults.standard.string(forKey: enabledCurrenciesKey),
                  !stored.isEmpty else {
                return ["SGD", "MYR", "HKD", "USD", "EUR"]
            }
            return stored.components(separatedBy: ",").filter { !$0.isEmpty }
        }
        set {
            UserDefaults.standard.set(newValue.joined(separator: ","), forKey: enabledCurrenciesKey)
        }
    }

    static var enabledCurrencies: [CurrencyInfo] {
        let codes = enabledCurrencyCodes
        return allAvailableCurrencies.filter { codes.contains($0.code) }
    }

    // Searches built-in and custom currencies
    static func info(for code: String) -> CurrencyInfo? {
        allAvailableCurrencies.first { $0.code == code }
    }

    static func symbol(for code: String) -> String {
        info(for: code)?.symbol ?? code
    }

    // MARK: - Reactive helpers (accept raw @AppStorage strings so callers stay reactive)

    static func parseCustomCurrencies(fromRaw raw: String) -> [CurrencyInfo] {
        let builtInCodes = Set(allCurrencies.map { $0.code })
        return raw.components(separatedBy: ",")
            .filter { !$0.isEmpty }
            .compactMap { entry -> CurrencyInfo? in
                let p = entry.components(separatedBy: "|")
                guard p.count == 3 else { return nil }
                return CurrencyInfo(code: p[0], name: p[1], symbol: p[2])
            }
            .filter { !builtInCodes.contains($0.code) }
    }

    static func enabledCurrencies(fromRaw enabledRaw: String, customRaw: String) -> [CurrencyInfo] {
        let codes = enabledRaw.components(separatedBy: ",").filter { !$0.isEmpty }
        let all = allCurrencies + parseCustomCurrencies(fromRaw: customRaw)
        let list = all.filter { codes.contains($0.code) }
        return list.isEmpty ? all : list
    }

    // MARK: - Exchange Rate Cache

    /// All cached exchange rates: [fromCurrencyCode: rateToDefaultCurrency].
    /// Stored as JSON Data under `exchangeRatesKey` so @AppStorage(exchangeRatesKey) in views
    /// is automatically reactive to changes.
    static var cachedRates: [String: Double] {
        get {
            guard let data = UserDefaults.standard.data(forKey: exchangeRatesKey),
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data)
            else { return [:] }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: exchangeRatesKey)
            }
        }
    }

    static var exchangeRatesFetchedAt: Date? {
        get {
            let ti = UserDefaults.standard.double(forKey: exchangeRatesFetchedAtKey)
            return ti > 0 ? Date(timeIntervalSince1970: ti) : nil
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970 ?? 0,
                                      forKey: exchangeRatesFetchedAtKey)
        }
    }

    private static var exchangeRatesBase: String? {
        get { UserDefaults.standard.string(forKey: exchangeRatesBaseKey) }
        set { UserDefaults.standard.set(newValue, forKey: exchangeRatesBaseKey) }
    }

    /// Returns true when the cached rates are missing, stale (> 5 days old),
    /// were fetched against a different default currency, or all cached values are zero.
    static var ratesNeedRefresh: Bool {
        guard let fetchedAt = exchangeRatesFetchedAt,
              exchangeRatesBase == defaultCurrencyCode else { return true }
        if Date().timeIntervalSince(fetchedAt) > rateCacheTTL { return true }
        let rates = cachedRates
        return !rates.isEmpty && rates.values.allSatisfy { $0 == 0 }
    }

    /// Rate to convert 1 unit of `fromCode` into the default currency.
    /// Returns 1.0 if `fromCode` already is the default; nil if no rate is cached.
    static func rateToDefault(from fromCode: String) -> Double? {
        let defaultCode = defaultCurrencyCode
        guard fromCode != defaultCode else { return 1.0 }
        return cachedRates[fromCode]
    }

    /// Saves `rates` and marks the cache as fresh for `baseCurrency`.
    static func saveRates(_ rates: [String: Double], baseCurrency: String) {
        cachedRates = rates
        exchangeRatesFetchedAt = Date()
        exchangeRatesBase = baseCurrency
    }

    // MARK: - Frankfurter API

    /// Fetches exchange rates for all `currencies` relative to `defaultCurrency`
    /// using a single Frankfurter API call.
    ///
    /// Returns a dict of [foreignCode: rateToDefault], e.g. ["MYR": 0.32, "USD": 1.35].
    /// The Frankfurter response gives "1 default = X foreign", so we invert to get
    /// "1 foreign = Y default".
    static func fetchRates(for currencies: [String], to defaultCurrency: String) async -> [String: Double]? {
        let foreign = currencies.filter { $0 != defaultCurrency }
        guard !foreign.isEmpty else { return [:] }

        let toParam = foreign.joined(separator: ",")
        let urlString = "https://api.frankfurter.app/latest?from=\(defaultCurrency)&to=\(toParam)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rates = json["rates"] as? [String: Double] {
                // Invert: Frankfurter gives "1 default → X foreign"; we want "1 foreign → Y default"
                var inverted: [String: Double] = [:]
                for (code, rate) in rates where rate > 0 {
                    inverted[code] = 1.0 / rate
                }
                return inverted
            }
        } catch {
            print("Exchange rate fetch error: \(error)")
        }
        return nil
    }

    // MARK: - Currency & Amount Parsing

    /// Apple Pay disambiguates currencies that share a glyph by prefixing the
    /// symbol with a country code — e.g. "JP¥1,630" for yen and "CN¥1,630" for
    /// yuan, which both otherwise collapse to a bare "¥". These prefixes are
    /// matched ahead of the plain symbols so the right currency wins.
    private static let applePaySymbolAliases: [(symbol: String, code: String)] = [
        ("JP¥", "JPY"),
        ("CN¥", "CNY"),
    ]

    /// Parses a raw amount string (e.g. "S$12.50", "MYR 8.00", "8.00 MYR", "$4.99",
    /// "JP¥1,630") into a (currencyCode, amount) tuple.  Falls back to the user's
    /// default currency when no symbol/code is recognised.
    static func parseCurrencyAndAmount(from raw: String) -> (String, Decimal)? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        let currencies = allAvailableCurrencies
        var symbolToCode: [(String, String)] = []
        // 0. Apple Pay country-disambiguated symbols (e.g. "JP¥") — matched first
        //    so they take priority over the ambiguous bare glyph.
        symbolToCode += applePaySymbolAliases.map { ($0.symbol, $0.code) }
        // 1. ISO code prefixes (e.g. "SGD 12.50")
        symbolToCode += currencies.map { ($0.code, $0.code) }
        // 2. Currency symbols, longest first so "S$" is tried before "$".
        let indexed = currencies.filter { $0.symbol != "$" }.enumerated().map { ($0.offset, $0.element) }
        let sortedBySymbolLength = indexed.sorted {
            if $0.1.symbol.count != $1.1.symbol.count { return $0.1.symbol.count > $1.1.symbol.count }
            return $0.0 < $1.0
        }
        symbolToCode += sortedBySymbolLength.map { ($0.1.symbol, $0.1.code) }
        // 3. "$" is ambiguous — map to default currency
        symbolToCode.append(("$", defaultCurrencyCode))

        for (symbol, code) in symbolToCode {
            if trimmed.uppercased().hasPrefix(symbol.uppercased()) {
                let rest = String(trimmed.dropFirst(symbol.count)).trimmingCharacters(in: .whitespaces)
                if let amount = parseDecimal(from: rest) { return (code, amount) }
            }
            if trimmed.uppercased().hasSuffix(symbol.uppercased()) {
                let rest = String(trimmed.dropLast(symbol.count)).trimmingCharacters(in: .whitespaces)
                if let amount = parseDecimal(from: rest) { return (code, amount) }
            }
        }

        // No recognised symbol — bare number with default currency
        if let amount = parseDecimal(from: trimmed) {
            return (defaultCurrencyCode, amount)
        }
        return nil
    }

    static func parseDecimal(from string: String) -> Decimal? {
        let cleaned = string.replacingOccurrences(of: ",", with: "")
        return Decimal(string: cleaned)
    }
}
