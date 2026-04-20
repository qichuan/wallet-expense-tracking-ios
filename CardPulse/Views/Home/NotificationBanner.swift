//
//  NotificationBanner.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import UserNotifications

struct NotificationBanner: View {
    @AppStorage("hasDismissedNotificationBanner") private var hasDismissedNotificationBanner = false
    
    var body: some View {
        if !hasDismissedNotificationBanner {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppColors.brandGold.opacity(0.18))
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.brandGold)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Enable Notifications")
                            .foregroundColor(AppColors.textPrimary)
                            .font(.system(size: 15, weight: .semibold))
                        Text("Get notified when tap‑to‑pay transactions are tracked")
                            .foregroundColor(AppColors.textSecondary)
                            .font(.system(size: 13))

                        Button(action: {
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                                if granted {
                                    DispatchQueue.main.async {
                                        hasDismissedNotificationBanner = true
                                    }
                                }
                            }
                        }) {
                            Text("Enable")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.backgroundPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(AppColors.brandGold)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .padding(.trailing, 32)

                Button(action: {
                    DispatchQueue.main.async {
                        hasDismissedNotificationBanner = true
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 22, height: 22)
                        .background(AppColors.backgroundCardSoft)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .background(AppColors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
        } else {
            EmptyView()
        }
    }
}

#Preview {
    NotificationBanner()
        .background(AppColors.backgroundPrimary)
}

