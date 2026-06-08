//
//  HowToAutoTrackingView.swift
//  CardPulse
//

import SwiftUI
import AVFoundation
import Combine

struct HowToAutoTrackingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            AutomationStepView(onRegisterPrimaryAction: { _ in }, onFinish: {}, showTitle: false)
                .background(AppColors.backgroundPrimary)

            OnboardingPrimaryButton(title: "Open Shortcuts to set up", enabled: true, action: {
                guard let url = URL(string: "shortcuts://"),
                      UIApplication.shared.canOpenURL(url) else {
                    dismiss()
                    return
                }
                UIApplication.shared.open(url)
            }).padding(.horizontal, 20)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundPrimary.ignoresSafeArea())
        // Floating dismiss button overlapping the video — no title bar, so the
        // video gets the full height of the sheet.
        .overlay(alignment: .topTrailing) {
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(AppTypography.navButton)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(AppColors.divider, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .onAppear {
            AnalyticsTracker.view("automation_howto", ["source": "settings"])
        }
    }
}
#Preview {
    HowToAutoTrackingView()
}
