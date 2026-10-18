//
//  StoreDemoData.swift
//  CardPulse
//
//  DEBUG-only demo store for App Store screenshots and previews. Launch with
//  `-StoreDemo` (see `appstore/README.md`) to run on an in-memory
//  container instead of the real store, so captures never show real spending.
//  Cards are popular Singapore cards so the screens feel familiar; merchants are made up.
//

#if DEBUG
import Foundation
import SwiftData

enum StoreDemo {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-StoreDemo")
    }
}

extension ModelContainer {
    static func createStoreDemoContainer(now: Date = Date(), calendar: Calendar = .current) -> ModelContainer {
        let schema = Schema([Card.self, Transaction.self, SpendingCategory.self, CardRewardRule.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            try CategorySeeding.seedBuiltInsIfNeeded(in: context)

            // Statement ~5 days out, so the hero reads "5 days left".
            let today = calendar.component(.day, from: now)
            let statementDay = min(28, max(1, (today + 5 - 1) % 28 + 1))

            let citi = Card(name: "Citi Cashback", minimumSpendingAmount: 800, hasMinimumSpending: true,
                            rewardType: .cashback, minimumSpendingByDayOfMonth: statementDay,
                            baseRewardRate: 0.25, maxCashbackCap: 80)
            let uob = Card(name: "UOB Lady's Card", minimumSpendingAmount: 1000, hasMinimumSpending: true,
                           rewardType: .miles, minimumSpendingByDayOfMonth: statementDay,
                           baseRewardRate: 0.4, roundingBlock: 5)
            let dbs = Card(name: "DBS Woman's World", minimumSpendingAmount: 1000, hasMinimumSpending: true,
                           rewardType: .miles, minimumSpendingByDayOfMonth: statementDay,
                           baseRewardRate: 0.4, roundingBlock: 5)
            let hsbc = Card(name: "HSBC Revolution", minimumSpendingAmount: 0, rewardType: .miles,
                            minimumSpendingByDayOfMonth: statementDay, baseRewardRate: 0.4)
            let cards = [citi, uob, dbs, hsbc]
            for card in cards { context.insert(card) }
            context.insert(CardRewardRule(card: citi, categoryName: "Food & Drinks", rate: 6))
            context.insert(CardRewardRule(card: uob, categoryName: "Food & Drinks", rate: 4, maxRewardCap: 4000))
            context.insert(CardRewardRule(card: dbs, categoryName: "Shopping", rate: 4, maxRewardCap: 4000))
            context.insert(CardRewardRule(card: hsbc, categoryName: "Entertainment", rate: 4))

            var generator = SeededGenerator(seed: 42)
            var transactions: [Transaction] = []

            for daysAgo in 0..<62 where isActive(daysAgo: daysAgo) {
                let count = daysAgo == 0 ? 3 : (generator.next() % 3 == 0 ? 2 : 1)
                for slot in 0..<count {
                    let merchant = merchants[Int(generator.next() % UInt64(merchants.count))]
                    let date = timestamp(daysAgo: daysAgo, slot: slot, now: now, calendar: calendar, generator: &generator)
                    let spread = Double(generator.next() % 1000) / 1000
                    let amount = merchant.low + (merchant.high - merchant.low) * spread
                    let card = cardFor(merchant: merchant, cards: cards, generator: &generator)
                    transactions.append(Transaction(
                        merchant: merchant.name,
                        amount: Decimal(string: String(format: "%.2f", amount)) ?? 10,
                        date: date,
                        category: merchant.category,
                        card: card,
                        currency: "SGD",
                        latitude: merchant.latitude,
                        longitude: merchant.longitude,
                        placeName: merchant.place
                    ))
                }
            }

            // Pin each goal card's current-cycle spend so the screens tell a happy story:
            // one card done and two ahead of pace, so no card is behind and the
            // mascot smiles on Today and Cards. Relative to pacing, so it holds on any date.
            let pacing = uob.cyclePacing ?? 0.8
            let targets: [(Card, Double)] = [
                (citi, 846),
                (uob, 1000 * min(0.94, pacing + 0.06)),
                (dbs, 1000 * min(0.9, pacing + 0.02)),
            ]
            for (card, target) in targets {
                let inCycle = transactions.filter { $0.card === card && $0.date >= card.currentCycleStart && $0.date <= now }
                let total = inCycle.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.amount).doubleValue }
                guard total > 0 else { continue }
                let factor = target / total
                for tx in inCycle {
                    let scaled = NSDecimalNumber(decimal: tx.amount).doubleValue * factor
                    tx.amount = Decimal(string: String(format: "%.2f", scaled)) ?? tx.amount
                }
            }

            for tx in transactions { context.insert(tx) }
            try context.save()
            return container
        } catch {
            fatalError("Could not create demo ModelContainer: \(error)")
        }
    }

    /// Current streak of 12 days, one missed day, then a 19-day best streak; sparser before that.
    private static func isActive(daysAgo: Int) -> Bool {
        switch daysAgo {
        case 0...11:  return true
        case 12:      return false
        case 13...31: return true
        case 32:      return false
        default:      return daysAgo % 4 != 0
        }
    }

    private static func timestamp(daysAgo: Int, slot: Int, now: Date, calendar: Calendar,
                                  generator: inout SeededGenerator) -> Date {
        if daysAgo == 0 {
            // Today's taps land in the last few hours, so they show as NEW.
            return now.addingTimeInterval(-Double(slot * 2 + 1) * 3600 - Double(generator.next() % 1800))
        }
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) ?? now
        let hour = [8, 12, 19][slot % 3]
        let minute = Int(generator.next() % 60)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private static func cardFor(merchant: DemoMerchant, cards: [Card], generator: inout SeededGenerator) -> Card {
        switch merchant.category {
        // cards: Citi Cashback, UOB Lady's, DBS Woman's World, HSBC Revolution
        case "Food & Drinks": return generator.next() % 3 == 0 ? cards[0] : cards[1]
        case "Shopping":      return cards[2]
        case "Entertainment": return cards[3]
        default:              return generator.next() % 2 == 0 ? cards[0] : cards[3]
        }
    }

    private struct DemoMerchant {
        let name: String
        let category: String
        let low: Double
        let high: Double
        let place: String
        let latitude: Double
        let longitude: Double
    }

    private static let merchants: [DemoMerchant] = [
        .init(name: "Kopi Corner", category: "Food & Drinks", low: 2.8, high: 7.5, place: "Tiong Bahru", latitude: 1.2852, longitude: 103.8308),
        .init(name: "Hawker Stall #12", category: "Food & Drinks", low: 4.5, high: 12, place: "Maxwell", latitude: 1.2804, longitude: 103.8448),
        .init(name: "Noodle Bar", category: "Food & Drinks", low: 12, high: 28, place: "Tanjong Pagar", latitude: 1.2764, longitude: 103.8458),
        .init(name: "Brunch Club", category: "Food & Drinks", low: 24, high: 58, place: "Holland Village", latitude: 1.3115, longitude: 103.7958),
        .init(name: "Fresh Mart", category: "Shopping", low: 18, high: 96, place: "Bishan", latitude: 1.3508, longitude: 103.8485),
        .init(name: "Orchard Books", category: "Shopping", low: 15, high: 48, place: "Orchard", latitude: 1.3040, longitude: 103.8318),
        .init(name: "Home & Living", category: "Shopping", low: 30, high: 140, place: "Paya Lebar", latitude: 1.3180, longitude: 103.8930),
        .init(name: "City Cabs", category: "Travel", low: 9, high: 32, place: "Raffles Place", latitude: 1.2840, longitude: 103.8514),
        .init(name: "Airport Duty Free", category: "Travel", low: 45, high: 160, place: "Changi", latitude: 1.3573, longitude: 103.9886),
        .init(name: "Cinema Hall", category: "Entertainment", low: 13.5, high: 32, place: "Bugis", latitude: 1.2996, longitude: 103.8553),
        .init(name: "Neighbourhood Clinic", category: "Health", low: 25, high: 70, place: "Toa Payoh", latitude: 1.3343, longitude: 103.8505),
        .init(name: "Mobile Plan", category: "Services", low: 28, high: 42, place: "Online", latitude: 1.2930, longitude: 103.8520),
    ]
}

/// Deterministic generator so every demo launch produces the same data (SplitMix64).
private struct SeededGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
#endif
