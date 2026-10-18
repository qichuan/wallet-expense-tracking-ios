//
//  CardRow.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct CardRow: View {
    let card: Card
    var status: CardStatus? = nil

    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"
    // Observed so spend/reward amounts recompute when FX rates are refreshed.
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()

    private var currencySymbol: String {
        CurrencyUtils.symbol(for: defaultCurrencyCode)
    }

    private var resolvedStatus: CardStatus {
        status ?? card.cycleStatus
    }

    private func money(_ amount: Decimal) -> String {
        CurrencyUtils.display(amount, code: defaultCurrencyCode)
    }

    private var hasGoal: Bool {
        card.hasSpendGoal
    }

    /// "S$87 to go · about S$22 a day", or the celebration line once the target is hit.
    private var statusLine: String {
        guard resolvedStatus != .hit else { return "Target smashed. Rewards unlocked!" }
        let remaining = card.remainingAmount
        let perDay = remaining / Decimal(max(1, card.daysRemaining))
        return "\(money(remaining)) to go · about \(money(perDay)) a day"
    }

    private var subtitle: String {
        var parts = [card.spendingPeriodDisplay]
        if card.rewardType != .none { parts.append(card.rewardType.displayName) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if hasGoal {
                goalBlock
            } else {
                spentBlock
            }
            if card.rewardType != .none {
                rewardsRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 22)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            CardArt(card: card, width: 46, raised: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(AppTypography.rowMeta)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if hasGoal {
                StatusPill(status: resolvedStatus)
            }
        }
    }

    private var goalBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(money(card.monthlySpent))
                    .font(AppTypography.amount)
                    .foregroundColor(AppColors.textPrimary)
                Text("/ \(money(card.minimumSpendingAmount))")
                    .font(AppTypography.amountTarget)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(MascotCopy.daysLeftText(card.daysRemaining))
                    .font(AppTypography.rowMeta)
                    .foregroundColor(AppColors.textTertiary)
            }
            ChunkyProgressBar(progress: card.progressPercentage, color: resolvedStatus.color,
                              height: 14, highlight: true)
            Text(statusLine)
                .font(AppTypography.rowValue)
                .foregroundColor(resolvedStatus.textColor)
        }
    }

    @ViewBuilder
    private var spentBlock: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(money(card.monthlySpent))
                .font(AppTypography.amount)
                .foregroundColor(AppColors.textPrimary)
            Text("spent")
                .font(AppTypography.amountTarget)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(MascotCopy.daysLeftText(card.daysRemaining))
                .font(AppTypography.rowMeta)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    private var rewardColor: Color {
        switch card.rewardType {
        case .miles: return AppColors.rewardMiles
        case .cashback: return AppColors.rewardCash
        case .none: return AppColors.textPrimary
        }
    }

    @ViewBuilder
    private var rewardsRow: some View {
        let status = RewardCalculator.cycleRewardStatus(for: card)
        let formatted = RewardFormatter.format(status.uncapped, type: card.rewardType, currencySymbol: currencySymbol)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .font(AppTypography.metricLabel)
                    .foregroundColor(rewardColor)
                Text("Earned this cycle")
                    .font(AppTypography.rowMeta)
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                Text(formatted.isEmpty ? "—" : formatted)
                    .font(AppTypography.rowValue)
                    .foregroundColor(rewardColor)
                if status.hasCap {
                    Text("/ \(RewardFormatter.format(status.cap, type: card.rewardType, currencySymbol: currencySymbol)) cap")
                        .font(AppTypography.rowMeta)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            if status.isCapReached {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.statusBehind)
                    Text("Cap reached — no more \(disclaimerUnit) this cycle")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.statusBehind)
                }
            } else if let remaining = status.remaining {
                Text("\(RewardFormatter.format(remaining, type: card.rewardType, currencySymbol: currencySymbol)) remaining until cap")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private var disclaimerUnit: String {
        card.rewardType == .miles ? "miles" : "cashback"
    }
}

#Preview {
    let card = Card(
        name: "DBS Altitude Visa",
        minimumSpendingAmount: 5000,
        hasMinimumSpending: true,
        rewardType: .miles,
        minimumSpendingByDayOfMonth: 15
    )
    return VStack(spacing: 12) {
        CardRow(card: card, status: .onTrack)
        CardRow(card: card, status: .hit)
        CardRow(card: card, status: .behind)
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}
