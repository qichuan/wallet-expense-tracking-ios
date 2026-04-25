//
//  NotificationsStepView.swift
//  CardPulse
//

import SwiftUI
import UIKit
import UserNotifications

struct NotificationsStepView: View {
    @State private var requestState: RequestState = .idle

    enum RequestState: Equatable {
        case idle, requesting, granted, denied
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Get notified")
                    .font(AppTypography.screenTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Get notified when tap-to-pay transactions are tracked.")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)

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
        case .requesting:    return "Requesting…"
        case .granted:       return "Notifications enabled"
        }
    }

    @ViewBuilder
    private var previewCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let icon = UIImage(named: "AppIcon") {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFill()
                } else {
                    BrandMark(size: 22)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Transaction Added")
                        .font(AppTypography.bannerTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text("now")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
                Text("Starbucks: $4.50 on Visa Signature")
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
    NotificationsStepView()
        .background(AppColors.backgroundPrimary)
}
