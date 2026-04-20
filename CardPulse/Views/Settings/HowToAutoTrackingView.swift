//
//  HowToAutoTrackingView.swift
//  CardPulse
//

import SwiftUI
import AVKit

struct HowToAutoTrackingView: View {
    @Environment(\.dismiss) private var dismiss

    private func player(for name: String, ext: String = "mp4") -> AVPlayer? {
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return AVPlayer(url: url)
        }
        return nil
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TabView {
                    StepView(
                        title: "Step 1",
                        description: "Open Shortcuts app > Go to 'Automations' > Tap 'New Automation' > Select 'Wallet' from the list > Scroll down and select 'Run immediately' > Tap 'Next'" ,
                        player: player(for: "Step1")
                    )
                    .tag(0)

                    StepView(
                        title: "Step 2",
                        description: "Select 'Create New Shortcut' > Search 'CardPulse' > Select 'Log Wallet Transaction' > Tap 'Merchant Name' > Select 'Shortcut Input' > Tap 'Shortcut Input' > Select 'Merchant' form the list > Repeat the same for 'Amount' and 'Card Name'" ,
                        player: player(for: "Step2")
                    )
                    .tag(1)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .background(AppColors.backgroundPrimary)
            }
            .padding()
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            .navigationTitle("Set up Shortcut automation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct StepView: View {
    let title: String
    let description: String
    let player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 500)
                    .cornerRadius(12)
                    .onAppear { player.seek(to: .zero); player.play() }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.backgroundCard)
                        .frame(height: 500)
                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.textSecondary)
                        Text("Video not found")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            Text(description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    HowToAutoTrackingView()
}


