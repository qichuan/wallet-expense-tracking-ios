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
        NavigationStack {
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
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Set up Auto-track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                AnalyticsTracker.view("automation_howto", ["source": "settings"])
            }
        }
    }
}
#Preview {
    HowToAutoTrackingView()
}
