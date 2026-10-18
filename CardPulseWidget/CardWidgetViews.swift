//
//  CardWidgetViews.swift
//  CardPulseWidget
//
//  Mirrors the Today tab's min-spend card: Fredoka title, days-left pill, and a
//  goal row per card (card art, name, chunky progress bar, status icon). Colors,
//  fonts and status come from the app's shared theme files, so the widget follows
//  light and dark like the app.
//

import SwiftUI
import WidgetKit

// MARK: - Medium widget (up to 3 cards)

struct MediumCardWidgetView: View {
    let entry: CardWidgetEntry

    /// Soonest statement among cards still working toward their goal.
    private var daysLeft: Int? {
        entry.cards.filter { $0.status != .hit }.map(\.daysRemaining).min()
    }

    var body: some View {
        if entry.cards.isEmpty {
            EmptyWidgetView()
        } else {
            let visible = Array(entry.cards.prefix(3))
            // Three rows only fit on one line each; with fewer, show the amounts too.
            let compact = visible.count >= 3
            VStack(alignment: .leading, spacing: compact ? 9 : 12) {
                HStack {
                    Text("Min-spend")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    if let daysLeft {
                        Text(daysLeftText(daysLeft).uppercased())
                            .font(AppTypography.badgeTiny)
                            .foregroundColor(AppColors.statusBehindText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppColors.statusBehindSoft))
                    }
                }
                ForEach(visible) { card in
                    GoalRowWidgetView(card: card, symbol: entry.currencySymbol, compact: compact)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func daysLeftText(_ days: Int) -> String {
        switch days {
        case 0:  return "Statement today"
        case 1:  return "1 day left"
        default: return "\(days) days left"
        }
    }
}

// MARK: - Goal row (same layout as HomeView's goalRow)

private struct GoalRowWidgetView: View {
    let card: CardSpendData
    let symbol: String
    let compact: Bool

    var body: some View {
        let status = card.status
        HStack(spacing: 10) {
            CardArt(color: CardArt.color(for: card.id), width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(card.name)
                    .font(AppTypography.rowValue)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                if !compact {
                    Text("\(money(card.monthlySpent)) / \(money(card.minimumSpending))")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            .minimumScaleFactor(0.8)
            .frame(width: 104, alignment: .leading)
            ChunkyProgressBar(progress: card.progressPercentage, color: status.color, height: 8)
            Image(systemName: status.icon)
                .font(AppTypography.iconSmall)
                .foregroundColor(status.color)
                .frame(width: 18, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.name), \(Int(card.progressPercentage * 100)) percent, \(status.label)")
    }

    private func money(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return symbol + (formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))")
    }
}

// MARK: - Accessory circular (Lock Screen)

struct AccessoryCircularWidgetView: View {
    let entry: CardWidgetEntry

    var body: some View {
        if let card = entry.cards.first {
            Gauge(value: card.progressPercentage) {
                Image(systemName: "creditcard.fill")
            } currentValueLabel: {
                Text("\(Int(card.progressPercentage * 100))%")
                    .font(AppTypography.caption2)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(AppColors.accent)
        } else {
            Image(systemName: "creditcard.fill")
        }
    }
}

// MARK: - Empty state

struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 8) {
            CardArt(color: AppColors.accent, width: 34)
            Text("Pick up to 3 cards\nwith a min-spend goal")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
