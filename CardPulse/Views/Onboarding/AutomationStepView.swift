//
//  AutomationStepView.swift
//  CardPulse
//

import SwiftUI
import AVFoundation
import Combine

struct AutomationStepView: View {
    let onRegisterPrimaryAction: (@escaping () -> Void) -> Void
    let onFinish: () -> Void
    var showTitle: Bool = true

    @StateObject private var players = AutomationPlayers()
    @State private var hasOpenedShortcuts = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showTitle {
                Text("Set up Auto-track")
                    .font(AppTypography.screenTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 16)
            }

            #if os(iOS)
            PiPPlayerView(player: players.step1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif
        }
        .onAppear {
            AnalyticsTracker.view("automation_howto", ["source": "onboarding"])
            onRegisterPrimaryAction(openShortcuts)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                players.step1.seek(to: .zero)
                players.step1.play()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, hasOpenedShortcuts { onFinish() }
        }
    }

    private func openShortcuts() {
        hasOpenedShortcuts = true
        #if os(iOS)
        guard let url = URL(string: "shortcuts://"),
              UIApplication.shared.canOpenURL(url) else {
            onFinish()
            return
        }
        UIApplication.shared.open(url)
        #else
        onFinish()
        #endif
    }
}

// MARK: - Stable player holder

final class AutomationPlayers: ObservableObject {
    let step1: AVPlayer

    init() {
        step1 = AVPlayer(url: Bundle.main.url(forResource: "Setup-Automation", withExtension: "mp4")!)
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
}

#Preview {
    AutomationStepView(onRegisterPrimaryAction: { _ in }, onFinish: {})
        .background(AppColors.backgroundPrimary)
}
