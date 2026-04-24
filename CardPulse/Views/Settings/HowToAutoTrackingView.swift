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
        NavigationView {
            VStack(spacing: 16) {
                AutomationStepView(onRegisterPrimaryAction: { _ in }, onFinish: {})
                .background(AppColors.backgroundPrimary)
                
                OnboardingPrimaryButton(title: "Open Shortcut", enabled: true, action: {

                guard let url = URL(string: "shortcuts://"),
                      UIApplication.shared.canOpenURL(url) else {
                    dismiss()
                    return
                }
                UIApplication.shared.open(url)
                }).padding(.horizontal, 20)
            }
            .background(AppColors.backgroundPrimary) 
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
#Preview {
    HowToAutoTrackingView()
}
