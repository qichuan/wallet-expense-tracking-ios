//
//  MinimumSpendHistoryGrid.swift
//  CardPulse
//

import SwiftUI
import SwiftData

/// Badge grid on the card detail screen: one badge per completed billing cycle,
/// showing whether that cycle met the card's minimum spend (issue #69).
/// Tapping a badge reveals that cycle's details, including the miles or cashback
/// earned (issue #71); tapping it again hides them.
struct MinimumSpendHistoryGrid: View {
    let cycles: [MinimumSpendHistory.Cycle]
    let minimum: Decimal
    let currencySymbol: String
    var rewardType: RewardType = .none

    @State private var selectedCycleID: Date?

    private var selectedCycle: MinimumSpendHistory.Cycle? {
        guard let id = selectedCycleID else { return nil }
        return cycles.first { $0.id == id }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    private var metCount: Int {
        cycles.filter { $0.outcome == .met }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Minimum Spend History")

            if cycles.isEmpty {
                Text("Badges appear here once a full billing cycle has passed.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Met \(metCount) of the last \(cycles.count) cycle\(cycles.count == 1 ? "" : "s")")
                    .font(AppTypography.rowValue)
                    .foregroundColor(AppColors.textSecondary)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(cycles) { cycle in
                        let isSelected = selectedCycleID == cycle.id
                        let badge = MinimumSpendBadge(
                            cycle: cycle,
                            minimum: minimum,
                            currencySymbol: currencySymbol,
                            rewardType: rewardType,
                            isSelected: isSelected
                        )
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCycleID = isSelected ? nil : cycle.id
                            }
                        } label: {
                            badge
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(badge.accessibilityText)
                        .accessibilityHint(isSelected ? "Hides this cycle's details" : "Shows this cycle's details")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }

                if let cycle = selectedCycle {
                    MinimumSpendCycleDetail(
                        cycle: cycle,
                        minimum: minimum,
                        currencySymbol: currencySymbol,
                        rewardType: rewardType
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Shared presentation helpers for a cycle's badge and its detail panel.
private enum CycleStyle {
    static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM ''yy"
        return f
    }()

    static let longMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    static func tint(_ outcome: MinimumSpendHistory.Outcome) -> Color {
        switch outcome {
        case .met:     return AppColors.statusHit
        case .missed:  return AppColors.statusBehind
        case .noSpend: return AppColors.textTertiary
        }
    }

    static func icon(_ outcome: MinimumSpendHistory.Outcome) -> String {
        switch outcome {
        case .met:     return "checkmark.circle.fill"
        case .missed:  return "xmark.circle.fill"
        case .noSpend: return "minus.circle"
        }
    }

    static func outcomeText(_ outcome: MinimumSpendHistory.Outcome) -> String {
        switch outcome {
        case .met:     return "met"
        case .missed:  return "missed"
        case .noSpend: return "no spend"
        }
    }

    static func wholeAmount(_ amount: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: amount as NSDecimalNumber) ?? "0"
    }

    static func rewardColor(_ type: RewardType) -> Color {
        type == .miles ? AppColors.rewardMiles : AppColors.rewardCash
    }

    static func rewardNoun(_ type: RewardType) -> String {
        type == .miles ? "Miles earned" : "Cashback earned"
    }
}

private struct MinimumSpendBadge: View {
    let cycle: MinimumSpendHistory.Cycle
    let minimum: Decimal
    let currencySymbol: String
    let rewardType: RewardType
    let isSelected: Bool

    private var tint: Color { CycleStyle.tint(cycle.outcome) }

    var accessibilityText: String {
        var text = "\(CycleStyle.longMonthFormatter.string(from: cycle.statementDate)) cycle, "
            + "\(CycleStyle.outcomeText(cycle.outcome)), "
            + "spent \(currencySymbol)\(CycleStyle.wholeAmount(cycle.spent)) of \(currencySymbol)\(CycleStyle.wholeAmount(minimum))"
        if rewardType != .none {
            text += ", earned \(RewardFormatter.format(cycle.earned, type: rewardType, currencySymbol: currencySymbol))"
        }
        return text
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: CycleStyle.icon(cycle.outcome))
                .font(AppTypography.iconMedium)
                .foregroundColor(tint)
            Text(CycleStyle.monthFormatter.string(from: cycle.statementDate))
                .font(AppTypography.pill)
                .foregroundColor(AppColors.textPrimary)
            Text(cycle.outcome == .noSpend ? "—" : "\(currencySymbol)\(CycleStyle.wholeAmount(cycle.spent))")
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(tint.opacity(isSelected ? 0.24 : 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? tint : AppColors.clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Detail panel under the grid for the tapped cycle: outcome, spend vs. minimum,
/// and the miles or cashback earned in that cycle.
private struct MinimumSpendCycleDetail: View {
    let cycle: MinimumSpendHistory.Cycle
    let minimum: Decimal
    let currencySymbol: String
    let rewardType: RewardType

    private var tint: Color { CycleStyle.tint(cycle.outcome) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: CycleStyle.icon(cycle.outcome))
                    .font(AppTypography.iconMedium)
                    .foregroundColor(tint)
                Text(CycleStyle.longMonthFormatter.string(from: cycle.statementDate))
                    .font(AppTypography.bannerTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(CycleStyle.outcomeText(cycle.outcome).capitalized)
                    .font(AppTypography.pill)
                    .foregroundColor(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.15))
                    .clipShape(Capsule())
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SPENT")
                        .font(AppTypography.metricLabel)
                        .foregroundColor(AppColors.textTertiary)
                    Text("\(currencySymbol)\(CycleStyle.wholeAmount(cycle.spent))")
                        .font(AppTypography.metricValue)
                        .foregroundColor(AppColors.textPrimary)
                    Text("of \(currencySymbol)\(CycleStyle.wholeAmount(minimum)) minimum")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if rewardType != .none {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(CycleStyle.rewardNoun(rewardType).uppercased())
                            .font(AppTypography.metricLabel)
                            .foregroundColor(AppColors.textTertiary)
                        Text(RewardFormatter.format(cycle.earned, type: rewardType, currencySymbol: currencySymbol))
                            .font(AppTypography.metricValue)
                            .foregroundColor(CycleStyle.rewardColor(rewardType))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundCardSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let calendar = Calendar.current
    let now = Date()
    let spends: [(date: Date, amount: Decimal)] = (1...8).flatMap { monthsAgo -> [(date: Date, amount: Decimal)] in
        guard monthsAgo != 3, let day = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else { return [] }
        return [(date: day, amount: Decimal(monthsAgo.isMultiple(of: 2) ? 650 : 320))]
    }
    let rewards = spends.map { (date: $0.date, amount: $0.amount * Decimal(string: "1.4")!) }
    let cycles = MinimumSpendHistory.pastCycles(statementDay: 15, minimum: 500, spends: spends, rewards: rewards)
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        MinimumSpendHistoryGrid(cycles: cycles, minimum: 500, currencySymbol: "S$", rewardType: .miles)
            .padding(20)
    }
    .modelContainer(ModelContainer.createMockContainer())
}
