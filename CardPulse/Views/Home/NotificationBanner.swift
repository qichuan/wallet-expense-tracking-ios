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
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 24))
                        .foregroundColor(.yellow)
                        .frame(width: 36, height: 36)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enable Notifications")
                            .foregroundColor(.white)
                            .font(.headline)
                        Text("Get notified when tap‑to‑pay transactions are tracked")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)

                        Button(action: {
                            // Request notification permission
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                                if granted {
                                    DispatchQueue.main.async {
                                        hasDismissedNotificationBanner = true
                                    }
                                }
                            }
                        }) {
                            Text("Enable")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.yellow)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .padding(.trailing, 32)
                
                Button(action: { }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(12)
            }
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal)
        } else {
            EmptyView()
        }
    }
}

#Preview {
    NotificationBanner()
        .background(Color(red: 0.05, green: 0.1, blue: 0.2))
}

