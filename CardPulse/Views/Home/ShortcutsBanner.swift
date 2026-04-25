//
//  ShortcutsBanner.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI

struct ShortcutsBanner: View {
    @AppStorage("hasDismissedShortcutBanner") private var hasDismissedShortcutBanner = false
    @State private var showingDismissBannerAlert = false
    @Binding var showingHowToAutoTracking: Bool
    
    var body: some View {
        if !hasDismissedShortcutBanner {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppColors.destructive.opacity(0.18))
                        Image("shortcuts")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Set up an automation in Shortcuts app")
                            .foregroundColor(AppColors.textPrimary)
                            .font(AppTypography.bannerTitle)
                        Text("Auto-log tap-to-pay transactions.")
                            .foregroundColor(AppColors.textSecondary)
                            .font(AppTypography.bannerBody)

                        Button(action: { showingHowToAutoTracking = true }) {
                            Text("View Instructions")
                                .font(AppTypography.bannerCTA)
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

                Button(action: { showingDismissBannerAlert = true }) {
                    Image(systemName: "xmark")
                        .font(AppTypography.bannerClose)
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
            .alert("", isPresented: $showingDismissBannerAlert) {
                Button("OK") {
                    hasDismissedShortcutBanner = true
                }
            } message: {
                Text("You can view instructions again in Settings.")
            }
        }
        else {
            EmptyView()
        }
    }
}

#Preview {
    ShortcutsBanner(showingHowToAutoTracking: .constant(false))
        .background(AppColors.backgroundPrimary)
}

