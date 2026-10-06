//
//  MinimumSpendHistoryGrid.swift
//  CardPulse
//

import SwiftUI
import SwiftData

/// Badge grid on the card detail screen: one badge per completed billing cycle,
/// showing whether that cycle met the card's minimum spend (issue #69).
struct MinimumSpendHistoryGrid: View {
    let cycles: [MinimumSpendHistory.Cycle]
    let minimum: Decimal
    let currencySymbol: String

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
                        MinimumSpendBadge(cycle: cycle, minimum: minimum, currencySymbol: currencySymbol)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MinimumSpendBadge: View {
    let cycle: MinimumSpendHistory.Cycle
    let minimum: Decimal
    let currencySymbol: String

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM ''yy"
        return f
    }()

    private static let accessibilityMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private var tint: Color {
        switch cycle.outcome {
        case .met:     return AppColors.statusHit
        case .missed:  return AppColors.statusBehind
        case .noSpend: return AppColors.textTertiary
        }
    }

    private var icon: String {
        switch cycle.outcome {
        case .met:     return "checkmark.circle.fill"
        case .missed:  return "xmark.circle.fill"
        case .noSpend: return "minus.circle"
        }
    }

    private var outcomeText: String {
        switch cycle.outcome {
        case .met:     return "met"
        case .missed:  return "missed"
        case .noSpend: return "no spend"
        }
    }

    private func formatted(_ amount: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: amount as NSDecimalNumber) ?? "0"
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(AppTypography.iconMedium)
                .foregroundColor(tint)
            Text(Self.monthFormatter.string(from: cycle.statementDate))
                .font(AppTypography.pill)
                .foregroundColor(AppColors.textPrimary)
            Text(cycle.outcome == .noSpend ? "—" : "\(currencySymbol)\(formatted(cycle.spent))")
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(Self.accessibilityMonthFormatter.string(from: cycle.statementDate)) cycle, \(outcomeText), "
            + "spent \(currencySymbol)\(formatted(cycle.spent)) of \(currencySymbol)\(formatted(minimum))"
        )
    }
}

#Preview {
    let calendar = Calendar.current
    let now = Date()
    let spends: [(date: Date, amount: Decimal)] = (1...8).flatMap { monthsAgo -> [(date: Date, amount: Decimal)] in
        guard monthsAgo != 3, let day = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else { return [] }
        return [(date: day, amount: Decimal(monthsAgo.isMultiple(of: 2) ? 650 : 320))]
    }
    let cycles = MinimumSpendHistory.pastCycles(statementDay: 15, minimum: 500, spends: spends)
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        MinimumSpendHistoryGrid(cycles: cycles, minimum: 500, currencySymbol: "S$")
            .padding(20)
    }
    .modelContainer(ModelContainer.createMockContainer())
}
