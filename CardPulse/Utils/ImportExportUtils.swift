//
//  ImportExportUtils.swift
//  CardPulse
//

import Foundation
import SwiftData

// MARK: - Parsed entity types

struct ParsedCardEntry {
    let name: String
    let minimumSpending: Decimal
    let hasMinimumSpending: Bool
    let rewardType: String
    let minSpendingDay: Int
}

struct ParsedCategoryEntry {
    let name: String
    let icon: String
    let colorHex: Int
    let sortOrder: Int
}

struct ParsedCurrencyEntry {
    let code: String
    let name: String
    let symbol: String
    let isCustom: Bool
    let isEnabled: Bool
    let isDefault: Bool
}

// MARK: - Import plan & result

struct ImportPlan {
    var transactionRows: [ImportPreviewRow] = []
    var cards: [ParsedCardEntry] = []
    var categories: [ParsedCategoryEntry] = []
    var currencies: [ParsedCurrencyEntry] = []

    // Computed against current DB / settings
    var cardsToCreate: [String] = []
    var categoriesToCreate: [String] = []
    var currenciesToEnable: [String] = []
    var customCurrenciesToAdd: [ParsedCurrencyEntry] = []
    var suggestedDefaultCurrency: String? = nil

    /// Rows from the source CSV that match an already-stored transaction
    /// (same merchant + amount + date + currency + card) and will be skipped
    /// during import. Surfaced in the preview so users know what's being
    /// dropped.
    var duplicateRowsSkipped: Int = 0
}

struct ImportResult {
    let transactionsAdded: Int
    let cardsAdded: Int
    let categoriesAdded: Int
    let transactionsSkippedAsDuplicates: Int
}

/// Stable signature for transaction de-duplication. Two transactions hash to
/// the same key when they are functionally identical from the user's POV —
/// regardless of insertion order or `id`.
private struct TransactionSignature: Hashable {
    let merchant: String      // trimmed, lowercased
    let amountCents: Int64    // amount × 100 to avoid Decimal hashing surprises
    let date: Date
    let currency: String      // uppercased
    let cardName: String      // trimmed, lowercased; "" when no card

    static func make(merchant: String, amount: Decimal, date: Date, currency: String, cardName: String?) -> TransactionSignature {
        let cents = NSDecimalNumber(decimal: amount * 100).int64Value
        return TransactionSignature(
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            amountCents: cents,
            date: date,
            currency: currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            cardName: (cardName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }
}

struct ImportExportUtils {
    static let exportHeader = "# CARDPULSE_BACKUP,v2"
    private static let sectionMarkerPrefix = "# SECTION,"

    // MARK: - Helpers

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func parseCSVLine(_ line: String) -> [String] {
        var components: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            if ch == "\"" {
                let next = line.index(after: i)
                if inQuotes && next < line.endIndex && line[next] == "\"" {
                    current.append("\"")
                    i = line.index(after: next)
                } else {
                    inQuotes.toggle()
                    i = next
                }
            } else if ch == "," && !inQuotes {
                components.append(current)
                current = ""
                i = line.index(after: i)
            } else {
                current.append(ch)
                i = line.index(after: i)
            }
        }
        components.append(current)
        return components
    }

    private static func escapeCSVField(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") || escaped.contains("\r") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    // MARK: - Section splitting

    /// Splits a multi-section CSV into a dictionary keyed by section name.
    /// Lines beginning with `#` that aren't `SECTION` markers are treated as comments and skipped.
    /// If no SECTION markers are found, the entire body is returned under "TRANSACTIONS"
    /// (legacy single-section transactions-only file).
    private static func splitSections(_ content: String) -> [String: [String]] {
        var sections: [String: [String]] = [:]
        var currentName: String? = nil
        var currentLines: [String] = []
        var sawSectionMarker = false

        for rawLine in content.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix(sectionMarkerPrefix) {
                sawSectionMarker = true
                if let name = currentName { sections[name] = currentLines }
                let value = String(trimmed.dropFirst(sectionMarkerPrefix.count)).trimmingCharacters(in: .whitespaces)
                currentName = value.uppercased()
                currentLines = []
            } else if trimmed.hasPrefix("#") {
                continue // comment
            } else if !trimmed.isEmpty {
                currentLines.append(rawLine)
            }
        }
        if let name = currentName { sections[name] = currentLines }

        if !sawSectionMarker {
            // Legacy: whole file is transactions
            let lines = content.components(separatedBy: "\n").filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            sections["TRANSACTIONS"] = lines
        }

        return sections
    }

    // MARK: - Section parsers

    private static func parseTransactionSection(lines: [String]) -> [ImportPreviewRow] {
        guard !lines.isEmpty else { return [] }
        let header = parseCSVLine(lines[0]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        func idx(_ names: [String]) -> Int? {
            for n in names { if let i = header.firstIndex(of: n) { return i } }
            return nil
        }
        let iMerchant = idx(["merchant", "merchant name"]) ?? 0
        let iAmount   = idx(["amount"]) ?? 1
        let iCurrency = idx(["currency"])
        let iCategory = idx(["category"])
        let iCard     = idx(["card"])
        let iDate     = idx(["date"]) ?? 3
        let iNote     = idx(["note"])

        var rows: [ImportPreviewRow] = []
        for line in lines.dropFirst() {
            let f = parseCSVLine(line)
            if f.count <= max(iMerchant, iAmount, iDate) { continue }
            rows.append(ImportPreviewRow(
                merchant: f.indices.contains(iMerchant) ? f[iMerchant] : "",
                amount:   f.indices.contains(iAmount)   ? f[iAmount]   : "",
                currency: (iCurrency != nil && f.indices.contains(iCurrency!)) ? f[iCurrency!] : "",
                category: (iCategory != nil && f.indices.contains(iCategory!)) ? f[iCategory!] : "",
                card:     (iCard != nil && f.indices.contains(iCard!))         ? f[iCard!]     : "",
                date:     f.indices.contains(iDate) ? f[iDate] : "",
                note:     (iNote != nil && f.indices.contains(iNote!))         ? f[iNote!]     : ""
            ))
        }
        return rows
    }

    private static func parseCardSection(lines: [String]) -> [ParsedCardEntry] {
        guard !lines.isEmpty else { return [] }
        let header = parseCSVLine(lines[0]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        func idx(_ names: [String]) -> Int? {
            for n in names { if let i = header.firstIndex(of: n) { return i } }
            return nil
        }
        let iName   = idx(["name"]) ?? 0
        let iAmount = idx(["minimumspending"]) ?? 1
        let iHas    = idx(["hasminimumspending"]) ?? 2
        let iReward = idx(["rewardtype"]) ?? 3
        let iDay    = idx(["minspendingbydayofmonth"]) ?? 4

        var result: [ParsedCardEntry] = []
        for line in lines.dropFirst() {
            let f = parseCSVLine(line)
            guard f.indices.contains(iName), !f[iName].isEmpty else { continue }
            let amount = Decimal(string: f.indices.contains(iAmount) ? f[iAmount] : "0") ?? 0
            let has = ((f.indices.contains(iHas) ? f[iHas] : "false").lowercased() == "true")
            let reward = f.indices.contains(iReward) ? f[iReward] : "none"
            let day = Int(f.indices.contains(iDay) ? f[iDay] : "1") ?? 1
            result.append(ParsedCardEntry(
                name: f[iName],
                minimumSpending: amount,
                hasMinimumSpending: has,
                rewardType: reward,
                minSpendingDay: day
            ))
        }
        return result
    }

    private static func parseCategorySection(lines: [String]) -> [ParsedCategoryEntry] {
        guard !lines.isEmpty else { return [] }
        let header = parseCSVLine(lines[0]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        func idx(_ names: [String]) -> Int? {
            for n in names { if let i = header.firstIndex(of: n) { return i } }
            return nil
        }
        let iName  = idx(["name"]) ?? 0
        let iIcon  = idx(["icon"]) ?? 1
        let iColor = idx(["colorhex"]) ?? 2
        let iOrder = idx(["sortorder"]) ?? 3

        var result: [ParsedCategoryEntry] = []
        for line in lines.dropFirst() {
            let f = parseCSVLine(line)
            guard f.indices.contains(iName), !f[iName].isEmpty else { continue }
            let icon = f.indices.contains(iIcon) ? f[iIcon] : "tag"
            let colorHex = Int(f.indices.contains(iColor) ? f[iColor] : "0") ?? 0
            let sortOrder = Int(f.indices.contains(iOrder) ? f[iOrder] : "0") ?? 0
            result.append(ParsedCategoryEntry(
                name: f[iName],
                icon: icon.isEmpty ? "tag" : icon,
                colorHex: colorHex,
                sortOrder: sortOrder
            ))
        }
        return result
    }

    private static func parseCurrencySection(lines: [String]) -> [ParsedCurrencyEntry] {
        guard !lines.isEmpty else { return [] }
        let header = parseCSVLine(lines[0]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        func idx(_ names: [String]) -> Int? {
            for n in names { if let i = header.firstIndex(of: n) { return i } }
            return nil
        }
        let iCode      = idx(["code"]) ?? 0
        let iName      = idx(["name"]) ?? 1
        let iSymbol    = idx(["symbol"]) ?? 2
        let iCustom    = idx(["iscustom"])
        let iEnabled   = idx(["isenabled"])
        let iDefault   = idx(["isdefault"])

        var result: [ParsedCurrencyEntry] = []
        for line in lines.dropFirst() {
            let f = parseCSVLine(line)
            guard f.indices.contains(iCode), !f[iCode].isEmpty else { continue }
            let code = f[iCode]
            let name = f.indices.contains(iName) ? f[iName] : code
            let symbol = f.indices.contains(iSymbol) ? f[iSymbol] : code
            let isCustom = (iCustom != nil && f.indices.contains(iCustom!) && f[iCustom!].lowercased() == "true")
            let isEnabled = (iEnabled != nil && f.indices.contains(iEnabled!) && f[iEnabled!].lowercased() == "true")
            let isDefault = (iDefault != nil && f.indices.contains(iDefault!) && f[iDefault!].lowercased() == "true")
            result.append(ParsedCurrencyEntry(
                code: code,
                name: name,
                symbol: symbol,
                isCustom: isCustom,
                isEnabled: isEnabled,
                isDefault: isDefault
            ))
        }
        return result
    }

    // MARK: - Build import plan

    static func buildImportPlan(from csvContent: String, modelContext: ModelContext) -> ImportPlan {
        let sections = splitSections(csvContent)
        var plan = ImportPlan()

        if let lines = sections["CARDS"] { plan.cards = parseCardSection(lines: lines) }
        if let lines = sections["CATEGORIES"] { plan.categories = parseCategorySection(lines: lines) }
        if let lines = sections["CURRENCIES"] { plan.currencies = parseCurrencySection(lines: lines) }
        if let lines = sections["TRANSACTIONS"] { plan.transactionRows = parseTransactionSection(lines: lines) }

        plan.suggestedDefaultCurrency = plan.currencies.first(where: { $0.isDefault })?.code

        // Diff: cards
        let existingCards = (try? modelContext.fetch(FetchDescriptor<Card>())) ?? []
        let existingCardNames = Set(existingCards.map { $0.name })
        let cardNamesFromTxn = Set(plan.transactionRows.map { $0.card }.filter { !$0.isEmpty })
        let cardNamesFromExport = Set(plan.cards.map { $0.name })
        plan.cardsToCreate = Array(cardNamesFromTxn.union(cardNamesFromExport).subtracting(existingCardNames)).sorted()

        // Diff: categories
        let existingCategories = (try? modelContext.fetch(FetchDescriptor<SpendingCategory>())) ?? []
        let existingCategoryNames = Set(existingCategories.map { $0.name.lowercased() })
        plan.categoriesToCreate = Array(
            Set(plan.categories.map { $0.name })
                .filter { !existingCategoryNames.contains($0.lowercased()) }
        ).sorted()

        // Diff: currencies
        let enabledNow = Set(CurrencyUtils.enabledCurrencyCodes)
        let codesFromTxn = Set(plan.transactionRows.map { $0.currency }.filter { !$0.isEmpty })
        let codesFromCurrencies = Set(plan.currencies.filter { $0.isEnabled }.map { $0.code })
        plan.currenciesToEnable = Array(codesFromTxn.union(codesFromCurrencies).subtracting(enabledNow)).sorted()

        let builtInCodes = Set(CurrencyUtils.allCurrencies.map { $0.code })
        let existingCustomCodes = Set(CurrencyUtils.customCurrencies.map { $0.code })
        plan.customCurrenciesToAdd = plan.currencies.filter {
            $0.isCustom && !builtInCodes.contains($0.code) && !existingCustomCodes.contains($0.code)
        }

        // Diff: drop transaction rows that already exist in the store. Done
        // here (not in `applyImportPlan`) so the preview's row count and
        // "duplicates skipped" stat match what will actually be imported.
        let existingTxns = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        let existingSignatures = Set(existingTxns.map {
            TransactionSignature.make(
                merchant: $0.merchant,
                amount: $0.amount,
                date: $0.date,
                currency: $0.resolvedCurrency,
                cardName: $0.card?.name
            )
        })
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let defaultCurrency = CurrencyUtils.defaultCurrencyCode
        var deduped: [ImportPreviewRow] = []
        var seenInBatch: Set<TransactionSignature> = []
        var skipped = 0
        for row in plan.transactionRows {
            guard let amount = Decimal(string: row.amount),
                  let date = dateFormatter.date(from: row.date) else {
                deduped.append(row) // malformed rows fall through; applyImportPlan will skip them
                continue
            }
            let sig = TransactionSignature.make(
                merchant: row.merchant,
                amount: amount,
                date: date,
                currency: row.currency.isEmpty ? defaultCurrency : row.currency,
                cardName: row.card.isEmpty ? nil : row.card
            )
            if existingSignatures.contains(sig) || seenInBatch.contains(sig) {
                skipped += 1
                continue
            }
            seenInBatch.insert(sig)
            deduped.append(row)
        }
        plan.transactionRows = deduped
        plan.duplicateRowsSkipped = skipped

        return plan
    }

    // MARK: - Apply import plan

    /// Inserts new cards, categories, and transactions from the plan. Does NOT modify
    /// UserDefaults / @AppStorage values for currencies — the caller must apply
    /// `currenciesToEnable` and `customCurrenciesToAdd` so they persist via the
    /// SettingsView's @AppStorage bindings.
    static func applyImportPlan(_ plan: ImportPlan, modelContext: ModelContext) throws -> ImportResult {
        // 1. Cards
        let existingCards = (try? modelContext.fetch(FetchDescriptor<Card>())) ?? []
        var nameToCard: [String: Card] = Dictionary(uniqueKeysWithValues: existingCards.map { ($0.name, $0) })
        var cardsAdded = 0

        for parsed in plan.cards where nameToCard[parsed.name] == nil {
            let card = Card(
                name: parsed.name,
                minimumSpendingAmount: parsed.minimumSpending,
                hasMinimumSpending: parsed.hasMinimumSpending,
                rewardType: RewardType(rawValue: parsed.rewardType) ?? .none,
                minimumSpendingByDayOfMonth: parsed.minSpendingDay
            )
            modelContext.insert(card)
            nameToCard[parsed.name] = card
            cardsAdded += 1
        }
        // Cards referenced only by transactions (no CARDS row): create stubs
        for name in plan.cardsToCreate where nameToCard[name] == nil {
            let card = Card(name: name, minimumSpendingAmount: 0, hasMinimumSpending: false, rewardType: .none)
            modelContext.insert(card)
            nameToCard[name] = card
            cardsAdded += 1
        }

        // 2. Categories
        let existingCategories = (try? modelContext.fetch(FetchDescriptor<SpendingCategory>())) ?? []
        let existingCategoryNamesLower = Set(existingCategories.map { $0.name.lowercased() })
        var maxOrder = existingCategories.map { $0.sortOrder }.max() ?? -1
        var categoriesAdded = 0

        for parsed in plan.categories where !existingCategoryNamesLower.contains(parsed.name.lowercased()) {
            let order: Int
            if parsed.sortOrder > 0 {
                order = parsed.sortOrder
            } else {
                maxOrder += 1
                order = maxOrder
            }
            let cat = SpendingCategory(
                name: parsed.name,
                icon: parsed.icon,
                colorHex: parsed.colorHex,
                isBuiltIn: false,
                sortOrder: order
            )
            modelContext.insert(cat)
            categoriesAdded += 1
        }

        // 3. Transactions
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let defaultCurrency = CurrencyUtils.defaultCurrencyCode
        var txnAdded = 0

        for row in plan.transactionRows {
            guard let amount = Decimal(string: row.amount),
                  let date = dateFormatter.date(from: row.date) else { continue }
            let card: Card? = row.card.isEmpty ? nil : nameToCard[row.card]
            let txn = Transaction(
                merchant: row.merchant,
                amount: amount,
                date: date,
                category: row.category.isEmpty ? nil : row.category,
                note: row.note.isEmpty ? nil : row.note,
                card: card,
                currency: row.currency.isEmpty ? defaultCurrency : row.currency
            )
            modelContext.insert(txn)
            txnAdded += 1
        }

        try modelContext.save()
        return ImportResult(
            transactionsAdded: txnAdded,
            cardsAdded: cardsAdded,
            categoriesAdded: categoriesAdded,
            transactionsSkippedAsDuplicates: plan.duplicateRowsSkipped
        )
    }

    // MARK: - Export

    /// Exports a full multi-section backup: cards, categories, currencies, and transactions.
    /// Date range applies to TRANSACTIONS only — cards/categories/currencies are exported in full.
    static func exportBackupCSV(
        modelContext: ModelContext,
        from startDate: Date,
        to endDate: Date,
        defaultCurrency: String,
        enabledCurrencyCodes: [String],
        customCurrenciesRaw: String
    ) -> String {
        var out = ""
        out += "\(exportHeader)\n"
        out += "# Generated \(ISO8601DateFormatter().string(from: Date()))\n"
        out += "\n"

        // CARDS
        out += "\(sectionMarkerPrefix)CARDS\n"
        out += "Name,MinimumSpending,HasMinimumSpending,RewardType,MinSpendingByDayOfMonth\n"
        let cards = (try? modelContext.fetch(FetchDescriptor<Card>())) ?? []
        for card in cards {
            let amount = String(format: "%.2f", Double(truncating: card.minimumSpendingAmount as NSDecimalNumber))
            out += "\(escapeCSVField(card.name)),\(amount),\(card.hasMinimumSpending),\(card.rewardType.rawValue),\(card.minimumSpendingByDayOfMonth)\n"
        }
        out += "\n"

        // CATEGORIES
        out += "\(sectionMarkerPrefix)CATEGORIES\n"
        out += "Name,Icon,ColorHex,SortOrder\n"
        let categories = (try? modelContext.fetch(FetchDescriptor<SpendingCategory>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        for cat in categories {
            out += "\(escapeCSVField(cat.name)),\(escapeCSVField(cat.icon)),\(cat.colorHex),\(cat.sortOrder)\n"
        }
        out += "\n"

        // CURRENCIES
        out += "\(sectionMarkerPrefix)CURRENCIES\n"
        out += "Code,Name,Symbol,IsCustom,IsEnabled,IsDefault\n"
        let builtInCodes = Set(CurrencyUtils.allCurrencies.map { $0.code })
        let customCurrencies = CurrencyUtils.parseCustomCurrencies(fromRaw: customCurrenciesRaw)
        let allCurrencies = CurrencyUtils.allCurrencies + customCurrencies.filter { !builtInCodes.contains($0.code) }
        let enabledSet = Set(enabledCurrencyCodes)
        for cur in allCurrencies {
            let isCustom = !builtInCodes.contains(cur.code)
            let isEnabled = enabledSet.contains(cur.code)
            let isDefault = (cur.code == defaultCurrency)
            out += "\(cur.code),\(escapeCSVField(cur.name)),\(escapeCSVField(cur.symbol)),\(isCustom),\(isEnabled),\(isDefault)\n"
        }
        out += "\n"

        // TRANSACTIONS
        out += "\(sectionMarkerPrefix)TRANSACTIONS\n"
        out += "Merchant,Amount,Currency,Category,Card,Date,Note\n"
        var request = FetchDescriptor<Transaction>()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        request.predicate = #Predicate { transaction in
            transaction.date >= startOfDay && transaction.date < endOfDay
        }
        let transactions = (try? modelContext.fetch(request)) ?? []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        for tx in transactions {
            let merchant = escapeCSVField(tx.merchant)
            let amount = String(format: "%.2f", Double(truncating: tx.amount as NSDecimalNumber))
            let currency = escapeCSVField(tx.currency)
            let category = escapeCSVField(tx.category ?? "")
            let cardName = escapeCSVField(tx.card?.name ?? "")
            let dateString = dateFormatter.string(from: tx.date)
            let note = escapeCSVField(tx.note ?? "")
            out += "\(merchant),\(amount),\(currency),\(category),\(cardName),\(dateString),\(note)\n"
        }

        return out
    }
}
