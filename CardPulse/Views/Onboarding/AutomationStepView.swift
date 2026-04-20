//
//  AutomationStepView.swift
//  CardPulse
//

import SwiftUI
import UIKit

struct AutomationStepView: View {
    let totalSteps: Int
    let onBack: () -> Void
    let onFinish: () -> Void

    private struct AutomationStep: Identifiable {
        let id = UUID()
        let index: Int
        let icon: String
        let title: String
        let detail: String
    }

    private let steps: [AutomationStep] = [
        .init(index: 1, icon: "app.connected.to.app.below.fill",
              title: "Open Shortcuts",
              detail: "In the Shortcuts app, go to Automations and tap “New Automation”."),
        .init(index: 2, icon: "wallet.pass",
              title: "Pick Wallet as the trigger",
              detail: "Select Wallet from the list, then choose “Run immediately”."),
        .init(index: 3, icon: "sparkles",
              title: "Run CardPulse on tap",
              detail: "Add the “Log Wallet Transaction” action and connect Merchant, Amount, and Card to Shortcut Input.")
    ]

    var body: some View {
        OnboardingScaffold(
            step: 4,
            totalSteps: totalSteps,
            title: "Automate from Wallet",
            description: "Let CardPulse log every Apple Wallet purchase automatically. It takes about a minute to set up.",
            primaryTitle: "Open Shortcuts",
            primaryEnabled: true,
            onBack: onBack,
            onSkip: nil,
            onPrimary: openShortcuts,
            secondaryTitle: "I'll do it later",
            onSecondary: onFinish
        ) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(steps) { step in
                        stepRow(step)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }

    @ViewBuilder
    private func stepRow(_ step: AutomationStep) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(AppColors.accentSoft)
                Text("\(step.index)")
                    .font(AppTypography.metricValue)
                    .foregroundColor(AppColors.accent)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: step.icon)
                        .font(AppTypography.iconMedium)
                        .foregroundColor(AppColors.accent)
                    Text(step.title)
                        .font(AppTypography.rowTitle)
                        .foregroundColor(AppColors.textPrimary)
                }
                Text(step.detail)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.backgroundCard)
        )
    }

    private func openShortcuts() {
        if let url = URL(string: "shortcuts://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        // Completing onboarding regardless — user opens Shortcuts and returns to CardPulse already onboarded.
        onFinish()
    }
}

#Preview {
    AutomationStepView(totalSteps: 4, onBack: {}, onFinish: {})
}
