//
//  NotificationsStepView.swift
//  CardPulse
//

import SwiftUI
import UserNotifications

struct NotificationsStepView: View {
    let totalSteps: Int
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var requestState: RequestState = .idle

    enum RequestState: Equatable {
        case idle
        case requesting
        case granted
        case denied
    }

    var body: some View {
        OnboardingScaffold(
            step: 3,
            totalSteps: totalSteps,
            title: "Get notified",
            description: "Get notified when tap-to-pay transactions are tracked.",
            primaryTitle: "Get Started",
            primaryEnabled: true,
            onBack: onBack,
            onSkip: nil,
            onPrimary: onContinue
        ) {
            VStack(alignment: .leading, spacing: 18) {
                previewCard

                Button(action: requestAuthorization) {
                    Text(buttonLabel)
                        .font(AppTypography.navButton)
                        .foregroundColor(AppColors.backgroundPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppColors.surfaceHigh)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(requestState == .requesting || requestState == .granted)

                if requestState == .denied {
                    Text("You declined notifications. You can enable them anytime in iOS Settings.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
        }
    }

    private var buttonLabel: String {
        switch requestState {
        case .idle, .denied: return "Enable notifications"
        case .requesting: return "Requesting…"
        case .granted: return "Notifications enabled"
        }
    }

    @ViewBuilder
    private var previewCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.backgroundCardSoft)
                BrandMark(size: 22)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Daily expense check-in!")
                        .font(AppTypography.bannerTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text("now")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
                Text("It's time to log today's expense")
                    .font(AppTypography.bannerBody)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.backgroundCard)
        )
    }

    private func requestAuthorization() {
        requestState = .requesting
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                requestState = granted ? .granted : .denied
            }
        }
    }
}

#Preview {
    NotificationsStepView(totalSteps: 4, onBack: {}, onContinue: {})
}
