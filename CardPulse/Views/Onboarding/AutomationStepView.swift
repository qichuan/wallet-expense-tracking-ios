//
//  AutomationStepView.swift
//  CardPulse
//

import SwiftUI
import UIKit
import AVKit
import AVFoundation

struct AutomationStepView: View {
    let onRegisterPrimaryAction: (@escaping () -> Void) -> Void
    let onFinish: () -> Void

    private struct VideoStep: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let resource: String
    }

    private let videoSteps: [VideoStep] = [
        .init(
            title: "Step 1",
            description: "Open Shortcuts app > Go to 'Automations' > Tap 'New Automation' > Select 'Wallet' from the list > Scroll down and select 'Run immediately' > Tap 'Next'",
            resource: "Step1"
        ),
        .init(
            title: "Step 2",
            description: "Select 'Create New Shortcut' > Search 'CardPulse' > Select 'Log Wallet Transaction' > Tap 'Merchant Name' > Select 'Shortcut Input' > Tap 'Shortcut Input' > Select 'Merchant' from the list > Repeat the same for 'Amount' and 'Card Name'",
            resource: "Step2"
        )
    ]

    @State private var selectedIndex = 0
    @State private var hasOpenedShortcuts = false
    @State private var startedResources: Set<String> = []
    @Environment(\.scenePhase) private var scenePhase
    @State private var players = OnboardingVideoPlayers()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Set up Automation")
                    .font(AppTypography.screenTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Let CardPulse log every Apple Wallet purchase automatically. It takes about a minute to set up.")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)

            VStack(spacing: 12) {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(videoSteps.enumerated()), id: \.element.id) { idx, step in
                        VStack(alignment: .leading, spacing: 12) {
                            playerView(for: step)
                                .frame(maxHeight: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Text(step.title)
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.textPrimary)

                            Text(step.description)
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 20)
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
        .onAppear {
            players.configureAudioSession()
            players.load(resources: videoSteps.map { $0.resource })
            onRegisterPrimaryAction(openShortcuts)
        }
        .onChange(of: selectedIndex) { _, newValue in
            guard newValue >= 0, newValue < videoSteps.count else { return }
            let resource = videoSteps[newValue].resource
            players.pauseAll()
            if startedResources.contains(resource) {
                players.play(resource: resource)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, hasOpenedShortcuts {
                onFinish()
            }
        }
        .onDisappear {
            players.teardown()
        }
    }

    @ViewBuilder
    private func playerView(for step: VideoStep) -> some View {
        if let player = players.player(for: step.resource) {
            ZStack {
                PiPPlayerView(player: player) { controller in
                    players.registerPiPController(controller, for: step.resource)
                }

                if !startedResources.contains(step.resource) {
                    Button {
                        players.play(resource: step.resource)
                        startedResources.insert(step.resource)
                    } label: {
                        ZStack {
                            Color.black.opacity(0.35)
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 64, weight: .regular))
                                .foregroundStyle(.white, .black.opacity(0.35))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.backgroundCard)
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle")
                        .font(AppTypography.iconXXLarge)
                        .foregroundColor(AppColors.textSecondary)
                    Text("Video not found")
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private func openShortcuts() {
        hasOpenedShortcuts = true
        let resource = videoSteps[selectedIndex].resource
        let shouldPiP = startedResources.contains(resource)

        if shouldPiP {
            players.startPiP(forResourceAt: selectedIndex)
        }

        let delay: TimeInterval = shouldPiP ? 0.2 : 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if let url = URL(string: "shortcuts://"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                onFinish()
            }
        }
    }
}

// MARK: - Shared player bag

@Observable
final class OnboardingVideoPlayers {
    @ObservationIgnored private var playersByResource: [String: AVPlayer] = [:]
    @ObservationIgnored private var pipControllers: [String: AVPictureInPictureController] = [:]
    @ObservationIgnored private var orderedResources: [String] = []
    @ObservationIgnored private var loopObservers: [NSObjectProtocol] = []

    func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func load(resources: [String]) {
        orderedResources = resources
        for resource in resources where playersByResource[resource] == nil {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "mp4") else { continue }
            let player = AVPlayer(url: url)
            player.isMuted = true
            player.actionAtItemEnd = .none
            let observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
            loopObservers.append(observer)
            playersByResource[resource] = player
        }
    }

    func player(for resource: String) -> AVPlayer? { playersByResource[resource] }

    func registerPiPController(_ controller: AVPictureInPictureController, for resource: String) {
        pipControllers[resource] = controller
    }

    func play(index: Int) {
        guard index >= 0, index < orderedResources.count else { return }
        play(resource: orderedResources[index])
    }

    func play(resource: String) {
        for (key, player) in playersByResource {
            if key == resource { player.seek(to: .zero); player.play() }
            else { player.pause() }
        }
    }

    func pauseAll() {
        playersByResource.values.forEach { $0.pause() }
    }

    func startPiP(forResourceAt index: Int) {
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              index >= 0, index < orderedResources.count else { return }
        let resource = orderedResources[index]
        guard let controller = pipControllers[resource],
              controller.isPictureInPicturePossible else { return }
        controller.startPictureInPicture()
    }

    func teardown() {
        loopObservers.forEach { NotificationCenter.default.removeObserver($0) }
        loopObservers.removeAll()
        playersByResource.values.forEach { $0.pause() }
        pipControllers.removeAll()
        playersByResource.removeAll()
        orderedResources.removeAll()
    }
}

// MARK: - UIView-backed player with PiP

struct PiPPlayerView: UIViewRepresentable {
    let player: AVPlayer
    let onControllerReady: (AVPictureInPictureController) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect

        if AVPictureInPictureController.isPictureInPictureSupported() {
            let pip = AVPictureInPictureController(playerLayer: view.playerLayer)
            pip?.canStartPictureInPictureAutomaticallyFromInline = true
            pip?.delegate = context.coordinator
            context.coordinator.pipController = pip
            if let pip { onControllerReady(pip) }
        }
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        if uiView.playerLayer.player !== player { uiView.playerLayer.player = player }
    }

    final class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        var pipController: AVPictureInPictureController?
    }
}

final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

#Preview {
    AutomationStepView(onRegisterPrimaryAction: { _ in }, onFinish: {})
        .background(AppColors.backgroundPrimary)
}
