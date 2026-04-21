//
//  WelcomeStepView.swift
//  CardPulse
//

import SwiftUI

struct WelcomeStepView: View {
    let onContinue: () -> Void

    private struct SampleTx: Identifiable {
        let id = UUID()
        let merchant: String
        let date: String
        let amount: String
        let icon: String
        let tint: Color
        let isMuted: Bool
    }

    private let samples: [SampleTx] = [
        .init(merchant: "Lunch at Starbucks", date: "09 Apr", amount: "12.50",
              icon: "fork.knife", tint: AppColors.categoryFoodDrinks, isMuted: false),
        .init(merchant: "Groceries", date: "08 Apr", amount: "54.20",
              icon: "cart", tint: AppColors.categoryShopping, isMuted: false),
        .init(merchant: "Movie Ticket", date: "07 Apr", amount: "15.00",
              icon: "ticket", tint: AppColors.categoryEntertainment, isMuted: false),
        .init(merchant: "Spotify Subscription", date: "3 Apr", amount: "9.99",
              icon: "music.note", tint: AppColors.categoryServices, isMuted: false),
        .init(merchant: "Taxi", date: "01 Apr", amount: "22.30",
              icon: "car", tint: AppColors.categoryTravel, isMuted: false),
        .init(merchant: "Train", date: "29 Mar", amount: "40.00",
              icon: "tram", tint: AppColors.categoryTravel, isMuted: true),
    ]

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                Text("CardPulse")
                    .font(.system(size: 44, weight: .heavy, design: .default))
                    .foregroundColor(AppColors.textPrimary)

                Spacer().frame(height: 18)

                deviceMockup
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 40)

                Spacer().frame(height: 20)

                VStack(spacing: 12) {
                    Text("Your Money.\nClear & Simple.")
                        .font(.system(size: 28, weight: .heavy, design: .default))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("CardPulse helps you track Apple Wallet purchases, organize them into categories, and keep an overview of your spending.")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer().frame(height: 28)

                OnboardingPrimaryButton(title: "Continue", enabled: true, action: onContinue)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var deviceMockup: some View {
        VStack(spacing: 10) {
            ForEach(Array(samples.enumerated()), id: \.element.id) { idx, tx in
                sampleRow(tx)
                    .opacity(tx.isMuted ? 0.35 : 1.0)
                    .offset(y: tx.isMuted ? CGFloat(idx - samples.count + 1) * 2 : 0)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(AppColors.backgroundCard.opacity(0.6))
        )
    }

    @ViewBuilder
    private func sampleRow(_ tx: SampleTx) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tx.tint.opacity(0.18))
                Image(systemName: tx.icon)
                    .font(AppTypography.iconMedium)
                    .foregroundColor(tx.tint)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(tx.merchant)
                    .font(AppTypography.rowTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text(tx.date)
                    .font(AppTypography.rowMeta)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            Text("$\(tx.amount)")
                .font(AppTypography.amountTransaction)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColors.backgroundCardSoft)
        )
    }
}

#Preview {
    WelcomeStepView(onContinue: {})
}
