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
        status ?? CardStatus.derive(progress: card.progressPercentage)
    }

    private var spentAmount: String {
        "\(currencySymbol)\(formatted(card.monthlySpent))"
    }

    private var targetAmount: String {
        "\(currencySymbol)\(formatted(card.minimumSpendingAmount))"
    }

    private func formatted(_ amount: Decimal) -> String {
        let number = Double(truncating: amount as NSDecimalNumber)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: number)) ?? "0"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(resolvedStatus.color)
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 12) {
                header
                if card.hasMinimumSpending && card.minimumSpendingAmount > 0 {
                    goalBlock
                } else {
                    spentBlock
                }
                if card.rewardType != .none {
                    rewardsRow
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 2)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if showsCycleLabel {
                        Text(card.spendingPeriodDisplay)
                    }
                }
                .font(AppTypography.bannerBody)
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            RewardTypePill(rewardType: card.rewardType)
        }
    }

    @ViewBuilder
    private var goalBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(spentAmount)
                        .font(AppTypography.amount)
                        .foregroundColor(AppColors.textPrimary)
                    Text("/ \(targetAmount)")
                        .font(AppTypography.amountTarget)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    StatusPill(status: resolvedStatus)
                    Text("\(card.daysRemaining)d left")
                        .font(AppTypography.rowMeta)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            progressBar
        }
    }

    private var showsCycleLabel: Bool {
        true
    }

    @ViewBuilder
    private var spentBlock: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(spentAmount)
                .font(AppTypography.amount)
                .foregroundColor(AppColors.textPrimary)
            Text("spent")
                .font(AppTypography.amountTarget)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text("\(card.daysRemaining)d left")
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
        let formatted = RewardFormatter.format(status.earned, type: card.rewardType, currencySymbol: currencySymbol)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .font(AppTypography.metricLabel)
                    .foregroundColor(rewardColor)
                Text("Earned this cycle")
                    .font(AppTypography.rowMeta)
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                if status.hasCap {
                    Text("/ \(RewardFormatter.format(status.cap, type: card.rewardType, currencySymbol: currencySymbol)) cap")
                        .font(AppTypography.rowMeta)
                        .foregroundColor(AppColors.textTertiary)
                }
                Text(formatted.isEmpty ? "—" : formatted)
                    .font(AppTypography.rowValue)
                    .foregroundColor(rewardColor)
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

    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.backgroundCardSoft)
                Capsule()
                    .fill(resolvedStatus.color)
                    .frame(width: geo.size.width * CGFloat(card.progressPercentage))
            }
        }
        .frame(height: 6)
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
