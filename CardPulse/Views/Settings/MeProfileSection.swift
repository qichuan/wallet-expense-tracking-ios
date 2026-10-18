//
//  MeProfileSection.swift
//  CardPulse
//
//  Top of the Me tab: mascot avatar, name, derived stats, this month's
//  activity calendar and badges. Everything is computed from transactions
//  and billing cycles; nothing here is persisted except the display name.
//

import SwiftUI
import SwiftData

struct MeProfileSection: View {
    @Query(sort: \Transaction.date) private var transactions: [Transaction]
    @Query private var cards: [Card]
    @AppStorage("displayName") private var displayName = ""

    private var streak: ActivityStreak {
        ActivityStreak(dates: transactions.map(\.date))
    }

    /// Met completed cycles across all cards, plus cards already at target this cycle.
    private var targetsHit: Int {
        let goalCards = cards.filter(\.hasSpendGoal)
        let past = goalCards.reduce(0) { total, card in
            total + card.minimumSpendHistory.filter { $0.outcome == .met }.count
        }
        return past + goalCards.filter { $0.progressPercentage >= 1.0 }.count
    }

    private static let sinceFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM yyyy"
        return df
    }()

    private var sinceText: String {
        guard let first = transactions.first?.date else { return "Your first tap is waiting" }
        return "Tracking since \(Self.sinceFormatter.string(from: first))"
    }

    var body: some View {
        let streak = self.streak
        let hits = targetsHit
        VStack(alignment: .leading, spacing: 16) {
            header
            statsGrid(streak: streak, targetsHit: hits)
            MonthActivityCalendar(activeDays: streak.activeDays(inMonthOf: Date()))
            badgesCard(BadgeEvaluator.badges(for: .init(
                bestStreak: streak.bestStreak,
                transactionCount: transactions.count,
                targetsHit: hits
            )))
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Mascot(mood: .happy, size: 70, motion: .none)
                .padding(.top, 8)
                .frame(width: 92, height: 92)
                .background(Circle().fill(AppColors.goldSoft))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(AppColors.backgroundCard, lineWidth: 3))
                .overlay(Circle().stroke(AppColors.border, lineWidth: 2).padding(-1))
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName.isEmpty ? "Hello!" : displayName)
                    .font(AppTypography.profileName)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(sinceText)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private func statsGrid(streak: ActivityStreak, targetsHit: Int) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            statTile(value: streak.currentStreak, label: "Day streak", symbol: "flame.fill", color: AppColors.streak)
            statTile(value: streak.bestStreak, label: "Best streak", symbol: "star.fill", color: AppColors.goldEdge)
            statTile(value: transactions.count, label: "Taps logged", symbol: "checkmark", color: AppColors.statusHit)
            statTile(value: targetsHit, label: "Targets hit", symbol: "trophy", color: AppColors.accent)
        }
    }

    private func statTile(value: Int, label: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(AppTypography.iconLarge)
                .foregroundColor(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(AppTypography.statValue)
                    .foregroundColor(AppColors.textPrimary)
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .chunkyRow()
        .accessibilityElement(children: .combine)
    }

    private func badgesCard(_ badges: [BadgeEvaluator.Badge]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges")
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColors.textPrimary)
            HStack(alignment: .top, spacing: 8) {
                ForEach(badges) { badge in
                    BadgeTile(badge: badge)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .cardSurface()
    }
}

private struct BadgeTile: View {
    let badge: BadgeEvaluator.Badge

    private var colors: (fill: Color, edge: Color) {
        guard badge.unlocked else { return (AppColors.locked, AppColors.lockedEdge) }
        switch badge.kind {
        case .weekWarrior:   return (AppColors.streak, AppColors.streakEdge)
        case .targetSmasher: return (AppColors.gold, AppColors.goldEdge)
        case .tidyTracker:   return (AppColors.statusHit, AppColors.statusHitEdge)
        case .monthMaster:   return (AppColors.accent, AppColors.accentEdge)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: badge.unlocked ? badge.symbol : "lock.fill")
                .font(AppTypography.iconLarge)
                .foregroundColor(AppColors.onAccent)
                .frame(width: 58, height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colors.edge)
                        .offset(y: 4)
                )
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colors.fill)
                )
                .padding(.bottom, 4)
            Text(badge.name)
                .font(AppTypography.pill)
                .foregroundColor(AppColors.textPrimary)
            Text(badge.subtitle)
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge.name), \(badge.subtitle), \(badge.unlocked ? "unlocked" : "locked")")
    }
}

/// Monday-first grid of the current month; days with a tap are filled orange
/// and today is outlined in accent.
struct MonthActivityCalendar: View {
    let activeDays: Set<Int>
    var now: Date = Date()
    var calendar: Calendar = .current

    private static let titleFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df
    }()

    private var cells: [Int?] {
        guard let interval = calendar.dateInterval(of: .month, for: now),
              let dayCount = calendar.range(of: .day, in: .month, for: now)?.count else { return [] }
        let weekday = calendar.component(.weekday, from: interval.start) // 1 = Sunday
        let leading = (weekday + 5) % 7
        return Array(repeating: nil, count: leading) + (1...dayCount).map { Optional($0) }
    }

    private var today: Int { calendar.component(.day, from: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(Self.titleFormatter.string(from: now))
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(AppTypography.iconSmall)
                    Text(activeDays.count == 1 ? "1 day" : "\(activeDays.count) days")
                        .font(AppTypography.pillBold)
                }
                .foregroundColor(AppColors.streak)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }
        }
        .cardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(activeDays.count) days with taps this month")
    }

    private func dayCell(_ day: Int) -> some View {
        let active = activeDays.contains(day)
        let isToday = day == today
        let future = day > today
        return Text("\(day)")
            .font(AppTypography.pillBold)
            .foregroundColor(active ? AppColors.onAccent : (future ? AppColors.textTertiary : AppColors.textPrimary))
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(active ? AppColors.streak : AppColors.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(active ? AppColors.streakEdge : (isToday ? AppColors.accent : AppColors.track), lineWidth: 2)
            )
    }
}

#Preview("Light") {
    ScrollView {
        MeProfileSection()
            .padding(18)
    }
    .screenBackground()
    .modelContainer(ModelContainer.createMockContainer())
}

#Preview("Dark") {
    ScrollView {
        MeProfileSection()
            .padding(18)
    }
    .screenBackground()
    .modelContainer(ModelContainer.createMockContainer())
    .preferredColorScheme(.dark)
}
