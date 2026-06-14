//
//  SpendingRecapView.swift
//  CardPulse
//

import SwiftUI
import UIKit

/// Sheet presenting the shareable recap. On appear it renders the map snapshot (if any)
/// and then rasterises the card into an image, so the shared image and the on-screen card
/// are identical. Sharing attaches the image plus a caption with an App Store download CTA.
struct SpendingRecapView: View {
    let recap: SpendingRecap

    @Environment(\.dismiss) private var dismiss
    @State private var mapImage: UIImage?
    @State private var shareImage: UIImage?
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()
                ScrollView {
                    SpendingRecapCard(recap: recap, mapImage: mapImage)
                        .padding()
                }
            }
            .navigationTitle("Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if shareImage != nil {
                        Button(action: { showingShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(AppTypography.navButton)
                                .foregroundColor(AppColors.accent)
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let shareImage {
                    // Image first, then the CTA caption: social targets attach the image
                    // and compose the caption (with the App Store link) as the post text.
                    ActivityShareSheet(items: [shareImage, recap.shareCaption])
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await prepareShareImage() }
    }

    @MainActor
    private func prepareShareImage() async {
        if !recap.mapPoints.isEmpty {
            mapImage = await withCheckedContinuation { continuation in
                MapSnapshotRenderer.snapshot(
                    points: recap.mapPoints,
                    size: CGSize(width: 320, height: 150)
                ) { image in
                    continuation.resume(returning: image)
                }
            }
        }

        let renderer = ImageRenderer(
            content: SpendingRecapCard(recap: recap, mapImage: mapImage)
                .frame(width: 360)
                .background(AppColors.backgroundPrimary)
        )
        renderer.scale = 3
        shareImage = renderer.uiImage
    }
}
