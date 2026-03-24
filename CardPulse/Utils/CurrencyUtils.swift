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

    // MARK: - UserDefaults accessors (usable from AppIntent too)

    static var defaultCurrencyCode: String {
        get { UserDefaults.standard.string(forKey: defaultCurrencyKey) ?? "SGD" }
        set { UserDefaults.standard.set(newValue, forKey: defaultCurrencyKey) }
    }

    static var enabledCurrencyCodes: [String] {
        get {
            guard let stored = UserDefaults.standard.string(forKey: enabledCurrenciesKey),
                  !stored.isEmpty else {
                return ["SGD", "MYR", "USD"]
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
}
