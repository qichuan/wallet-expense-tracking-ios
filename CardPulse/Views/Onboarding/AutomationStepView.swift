//
//  AutomationStepView.swift
//  CardPulse
//

import SwiftUI
import AVKit

struct AutomationStepView: View {
    let onRegisterPrimaryAction: (@escaping () -> Void) -> Void
    let onFinish: () -> Void

    @State private var selectedIndex = 0
    @State private var hasOpenedShortcuts = false
    @Environment(\.scenePhase) private var scenePhase

    private func makePlayer(for name: String) -> AVPlayer {
        AVPlayer(url: Bundle.main.url(forResource: name, withExtension: "mp4")!)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Set up Automation")
                .font(AppTypography.screenTitle)
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 16)

            TabView(selection: $selectedIndex) {
                videoPage(makePlayer(for: "Step1")).tag(0)
                videoPage(makePlayer(for: "Step2")).tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            onRegisterPrimaryAction(openShortcuts)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, hasOpenedShortcuts { onFinish() }
        }
    }

    @ViewBuilder
    private func videoPage(_ player: AVPlayer) -> some View {
        ClearBackgroundPlayer(player: player)
            .onAppear {
                player.seek(to: .zero)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    player.play()
                }
            }
            .onDisappear { player.pause() }
    }

    private func openShortcuts() {
        hasOpenedShortcuts = true
        if let url = URL(string: "shortcuts://"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            onFinish()
        }
    }
}

// MARK: - AVPlayerViewController with clear background

struct ClearBackgroundPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.videoGravity = .resizeAspect
        vc.view.backgroundColor = .clear
        vc.view.subviews.forEach { $0.backgroundColor = .clear }
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.player !== player { vc.player = player }
    }
}

#Preview {
    AutomationStepView(onRegisterPrimaryAction: { _ in }, onFinish: {})
        .background(AppColors.backgroundPrimary)
}
