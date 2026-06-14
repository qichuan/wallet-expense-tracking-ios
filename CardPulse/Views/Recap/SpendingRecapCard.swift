//
//  SpendingRecapCard.swift
//  CardPulse
//

import SwiftUI
import UIKit

/// Immutable snapshot of a period's spending, used to render the shareable recap.
/// All monetary values are already converted to the user's default currency by the
/// caller (`AnalysisView`).
struct SpendingRecap {
    struct Category: Identifiable {
        let id = UUID()
        let name: String
        let amount: Double
        let color: Color
    }
    struct Merchant {
        let name: String
        let amount: Double
    }

    /// e.g. "June 2026" or "2026".
    let periodTitle: String
    let totalSpend: Double
    let currencySymbol: String
    let miles: Decimal
    let cashback: Decimal
    /// Up to three biggest categories, largest first.
    let topCategories: [Category]
    let topMerchant: Merchant?
    let transactionCount: Int
    /// Distinct places (clusters) the spend happened across; `0` when no locations.
    let placesCount: Int
    /// Located points for the embedded map snapshot; empty hides the map.
    let mapPoints: [MapTransactionPoint]

    var shareTitle: String { "My \(periodTitle) spending recap" }
    var hasRewards: Bool { miles > 0 || cashback > 0 }

    /// Caption shared alongside the recap image. Includes a download CTA + App Store
    /// link so anyone who sees the post can tap through and install CardPulse.
    var shareCaption: String {
        "My \(periodTitle) spending recap, tracked with CardPulse 📊\n"
        + "Track your cards, spending and rewards: \(AppLinks.appStore.absoluteString)"
    }
}

/// The visual recap. Rendered both on screen and (via `ImageRenderer`) into the shared
/// image, so it must lay out at a fixed width with no scrolling. The map is passed in as
/// a pre-rendered image because `ImageRenderer` cannot capture a live `Map`.
struct SpendingRecapCard: View {
    let recap: SpendingRecap
    let mapImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            total
            if recap.hasRewards { rewards }
            if !recap.topCategories.isEmpty { categories }
            if let merchant = recap.topMerchant { topSpot(merchant) }
            if let mapImage { mapSnapshot(mapImage) }
            footer
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [AppColors.backgroundCard, AppColors.backgroundCardSoft],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 10) {
            BrandMark(size: 26)
            Text("CardPulse")
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(recap.periodTitle)
                .font(AppTypography.metricValue)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var total: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total spent")
                .font(AppTypography.metricLabel)
                .foregroundColor(AppColors.textTertiary)
                .tracking(1.0)
            Text(money(recap.totalSpend))
                .font(AppTypography.amountHero)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(recap.transactionCount) \(recap.transactionCount == 1 ? "transaction" : "transactions")"
                 + (recap.placesCount > 0 ? " · \(recap.placesCount) \(recap.placesCount == 1 ? "place" : "places")" : ""))
                .font(AppTypography.rowMeta)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var rewards: some View {
        HStack(spacing: 14) {
            if recap.miles > 0 {
                rewardTile(
                    label: "Miles",
                    value: RewardFormatter.format(recap.miles, type: .miles, currencySymbol: recap.currencySymbol),
                    color: AppColors.rewardMiles
                )
            }
            if recap.cashback > 0 {
                rewardTile(
                    label: "Cashback",
                    value: RewardFormatter.format(recap.cashback, type: .cashback, currencySymbol: recap.currencySymbol),
                    color: AppColors.rewardCash
                )
            }
        }
    }

    private func rewardTile(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTypography.metricLabel)
                .foregroundColor(AppColors.textTertiary)
                .tracking(1.0)
            Text(value)
                .font(AppTypography.metricValue)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.backgroundPrimary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top categories")
                .font(AppTypography.metricLabel)
                .foregroundColor(AppColors.textTertiary)
                .tracking(1.0)
            ForEach(recap.topCategories) { category in
                HStack(spacing: 8) {
                    Circle().fill(category.color).frame(width: 8, height: 8)
                    Text(category.name)
                        .font(AppTypography.bannerBody)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(money(category.amount, fractionDigits: 0))
                        .font(AppTypography.bannerCTA)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
    }

    private func topSpot(_ merchant: SpendingRecap.Merchant) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .font(AppTypography.iconMedium)
                .foregroundColor(AppColors.accent)
            Text("Top spot")
                .font(AppTypography.bannerBody)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(merchant.name)
                .font(AppTypography.bannerCTA)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
    }

    private func mapSnapshot(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var footer: some View {
        Text("Tracked with CardPulse")
            .font(AppTypography.caption2)
            .foregroundColor(AppColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Formatting

    private func money(_ value: Double, fractionDigits: Int = 2) -> String {
        String(format: "%@%.\(fractionDigits)f", recap.currencySymbol, value)
    }
}

#Preview {
    let recap = SpendingRecap(
        periodTitle: "June 2026",
        totalSpend: 2480.50,
        currencySymbol: "$",
        miles: 3472,
        cashback: 0,
        topCategories: [
            .init(name: "Food & Drinks", amount: 920, color: AppColors.categoryFoodDrinks),
            .init(name: "Shopping", amount: 640, color: AppColors.categoryShopping),
            .init(name: "Travel", amount: 510, color: AppColors.categoryTravel),
        ],
        topMerchant: .init(name: "Tiong Bahru Bakery", amount: 184),
        transactionCount: 47,
        placesCount: 12,
        mapPoints: []
    )
    SpendingRecapCard(recap: recap, mapImage: nil)
        .padding()
        .background(AppColors.backgroundPrimary)
}
