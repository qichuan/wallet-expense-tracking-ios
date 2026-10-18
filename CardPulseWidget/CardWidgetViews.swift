//
//  CardWidgetViews.swift
//  CardPulseWidget
//

import SwiftUI
import WidgetKit

// MARK: - Design tokens

private func progressTint(_ pct: Double) -> Color {
    CardStatus.derive(progress: pct).color
}

// MARK: - Medium widget (up to 3 cards)

struct MediumCardWidgetView: View {
    let entry: CardWidgetEntry

    var body: some View {
        if entry.cards.isEmpty {
            EmptyWidgetView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                let visible = Array(entry.cards.prefix(3))
                ForEach(visible) { card in
                    CardRowWidgetView(card: card)
                    if card.id != visible.last?.id {
                        Divider()
                            .background(AppColors.divider)
                            .padding(.vertical, 5)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Card row used inside medium widget

private struct CardRowWidgetView: View {
    let card: CardSpendData

    private var status: CardStatus {
        CardStatus.derive(progress: card.progressPercentage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text("$\(Int(card.monthlySpent)) / $\(Int(card.minimumSpending))")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.track)
                    Capsule()
                        .fill(status.color)
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, card.progressPercentage))))
                }
            }
            .frame(height: 6)

            Text("\(card.daysRemaining)d left · \(card.spendingPeriodDisplay)")
                .font(.caption2)
                .foregroundColor(AppColors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
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
                    .font(.caption2)
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
        VStack(spacing: 6) {
            Image(systemName: "creditcard")
                .font(.title3)
                .foregroundColor(AppColors.accent)
            Text("No cards\nselected")
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
