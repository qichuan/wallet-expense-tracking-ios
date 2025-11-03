//
//  ImportExportUtils.swift
//  CardPulse
//

import Foundation
import SwiftData

struct ImportExportUtils {
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

    static func buildImportPreview(from csvContent: String, modelContext: ModelContext) -> (rows: [ImportPreviewRow], missingCards: [String]) {
        let rawLines = csvContent.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !rawLines.isEmpty else { return ([], []) }

        let headerFields = parseCSVLine(rawLines[0]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        func idx(_ names: [String]) -> Int? {
            for name in names { if let i = headerFields.firstIndex(of: name) { return i } }
            return nil
        }
        let iMerchant = idx(["merchant", "merchant name"]) ?? 0
        let iAmount   = idx(["amount"]) ?? 1
        let iCategory = idx(["category"]) // optional
        let iCard     = idx(["card"]) // simplified
        let iDate     = idx(["date"]) ?? 3
        let iNote     = idx(["note"]) // optional

        var rows: [ImportPreviewRow] = []
        var cardNames: Set<String> = []
        for line in rawLines.dropFirst() {
            let fields = parseCSVLine(line)
            if fields.count <= max(iMerchant, iAmount, iDate) { continue }
            let merchant = fields.indices.contains(iMerchant) ? fields[iMerchant] : ""
            let amount = fields.indices.contains(iAmount) ? fields[iAmount] : ""
            let category = (iCategory != nil && fields.indices.contains(iCategory!)) ? fields[iCategory!] : ""
            let card = (iCard != nil && fields.indices.contains(iCard!)) ? fields[iCard!] : ""
            let date = fields.indices.contains(iDate) ? fields[iDate] : ""
            let note = (iNote != nil && fields.indices.contains(iNote!)) ? fields[iNote!] : ""
            rows.append(ImportPreviewRow(merchant: merchant, amount: amount, category: category, card: card, date: date, note: note))
            if !card.isEmpty { cardNames.insert(card) }
        }

        let existingCards = try? modelContext.fetch(FetchDescriptor<Card>())
        let existingNames = Set((existingCards ?? []).map { $0.name })
        let missing = Array(cardNames.subtracting(existingNames)).sorted()

        return (rows, missing)
    }

    static func precreateAndMapCards(missingCardNames: [String], modelContext: ModelContext) -> [String: Card] {
        let existingCards = (try? modelContext.fetch(FetchDescriptor<Card>())) ?? []
        var nameToCard: [String: Card] = Dictionary(uniqueKeysWithValues: existingCards.map { ($0.name, $0) })
        for name in missingCardNames where !name.isEmpty {
            if nameToCard[name] == nil {
                let newCard = Card(
                    name: name,
                    minimumSpendingAmount: 0,
                    hasMinimumSpending: false,
                    rewardType: .none
                )
                modelContext.insert(newCard)
                nameToCard[name] = newCard
            }
        }
        return nameToCard
    }

    static func importCSV(content: String, nameToCard: [String: Card], modelContext: ModelContext) throws -> Int {
        let lines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var processedCount = 0
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for (index, line) in lines.enumerated() {
            if index == 0 || line.isEmpty { continue }
            let components = parseCSVLine(line)
            guard components.count >= 5 else { continue }

            let merchant = components[0]
            let amountString = components[1]
            let category = components[2].isEmpty ? nil : components[2]
            let cardName = components[3]
            let dateString = components[4]
            let note = components.count > 5 ? components[5] : nil

            guard let amount = Decimal(string: amountString),
                  let date = dateFormatter.date(from: dateString) else { continue }

            let matchedCard: Card? = cardName.isEmpty ? nil : nameToCard[cardName]

            let transaction = Transaction(
                merchant: merchant,
                amount: amount,
                date: date,
                category: category,
                note: note,
                card: matchedCard
            )
            modelContext.insert(transaction)
            processedCount += 1
        }

        try modelContext.save()
        return processedCount
    }

    static func exportCSV(modelContext: ModelContext, from startDate: Date, to endDate: Date) -> String {
        var request = FetchDescriptor<Transaction>()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        request.predicate = #Predicate { transaction in
            transaction.date >= startOfDay && transaction.date < endOfDay
        }

        do {
            let transactions = try modelContext.fetch(request)
            var csvString = "Merchant,Amount,Category,Card,Date,Note\n"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

            for transaction in transactions {
                let merchant = escapeCSVField(transaction.merchant)
                let amount = String(format: "%.2f", Double(truncating: transaction.amount as NSDecimalNumber))
                let category = escapeCSVField(transaction.category ?? "")
                let cardName = escapeCSVField(transaction.card?.name ?? "")
                let dateString = dateFormatter.string(from: transaction.date)
                let note = escapeCSVField(transaction.note ?? "")
                csvString += "\(merchant),\(amount),\(category),\(cardName),\(dateString),\(note)\n"
            }
            return csvString
        } catch {
            return ""
        }
    }

    private static func escapeCSVField(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") || escaped.contains("\r") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}


