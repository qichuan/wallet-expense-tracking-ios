//
//  AutomationStepView.swift
//  CardPulse
//

import SwiftUI
import AVKit
import AVFoundation
import Combine

struct AutomationStepView: View {
    let onRegisterPrimaryAction: (@escaping () -> Void) -> Void
    let onFinish: () -> Void

    @StateObject private var players = AutomationPlayers()
    @State private var hasOpenedShortcuts = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Set up Automation")
                .font(AppTypography.screenTitle)
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 16)

            PiPPlayerView(player: players.step1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
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
        // canStartPictureInPictureAutomaticallyFromInline triggers PiP automatically when
        // the app backgrounds. isPictureInPicturePossible is always false in the foreground,
        // so calling startPictureInPicture() here would be a no-op anyway.
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
        step1 = AVPlayer(url: Bundle.main.url(forResource: "Step1", withExtension: "mp4")!)
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
}

// MARK: - Custom player view with AVPictureInPictureController

#if os(iOS)
struct PiPPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .clear
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect

        if AVPictureInPictureController.isPictureInPictureSupported(),
           let pip = AVPictureInPictureController(playerLayer: view.playerLayer) {
            pip.canStartPictureInPictureAutomaticallyFromInline = true
            pip.delegate = context.coordinator
            context.coordinator.pipController = pip
        }
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    final class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        var pipController: AVPictureInPictureController?
    }
}

final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
#endif

#Preview {
    AutomationStepView(onRegisterPrimaryAction: { _ in }, onFinish: {})
        .background(AppColors.backgroundPrimary)
}
