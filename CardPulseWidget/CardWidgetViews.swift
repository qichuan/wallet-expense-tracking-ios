//
//  CardWidgetViews.swift
//  CardPulseWidget
//

import SwiftUI
import WidgetKit

// MARK: - Design tokens

private let navyBackground = Color(red: 0.05, green: 0.10, blue: 0.20)
private let teal = Color.teal

private func progressTint(_ pct: Double) -> Color {
    if pct >= 1.0 { return .green }
    if pct >= 0.65 { return .teal }
    return .orange
}

// MARK: - Small widget

struct SmallCardWidgetView: View {
    let entry: CardWidgetEntry

    var body: some View {
        if let card = entry.cards.first {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                ProgressView(value: card.progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressTint(card.progressPercentage)))
                    .scaleEffect(x: 1, y: 1.4, anchor: .center)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("$\(Int(card.monthlySpent))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("/ $\(Int(card.minimumSpending))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.55))
                }

                Text("\(card.daysRemaining)d left · \(card.spendingPeriodDisplay)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(navyBackground)
        } else {
            EmptyWidgetView()
        }
    }
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
                            .background(Color.white.opacity(0.08))
                            .padding(.vertical, 5)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(navyBackground)
        }
    }
}

// MARK: - Card row used inside medium widget

private struct CardRowWidgetView: View {
    let card: CardSpendData

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Text("$\(Int(card.monthlySpent)) / $\(Int(card.minimumSpending))")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.75))
            }
            ProgressView(value: card.progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: progressTint(card.progressPercentage)))
                .scaleEffect(x: 1, y: 1.2, anchor: .center)
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
                .foregroundColor(teal)
            Text("No cards\nselected")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(navyBackground)
    }
}
