//
//  SpendingRecapView.swift
//  CardPulse
//

import SwiftUI
import UIKit
import CoreTransferable
import UniformTypeIdentifiers

/// Sheet presenting the shareable recap. On appear it renders the map snapshot (if any)
/// and then rasterises the card into a PNG for the share sheet, so the shared image and
/// the on-screen card are identical.
struct SpendingRecapView: View {
    let recap: SpendingRecap

    @Environment(\.dismiss) private var dismiss
    @State private var mapImage: UIImage?
    @State private var shareImage: UIImage?

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
                    if let shareImage {
                        ShareLink(
                            item: RecapShareImage(image: shareImage),
                            preview: SharePreview(recap.shareTitle, image: Image(uiImage: shareImage))
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(AppTypography.navButton)
                                .foregroundColor(AppColors.accent)
                        }
                    } else {
                        ProgressView()
                    }
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

/// Wraps the rendered recap so `ShareLink` exports it as a PNG file/image.
struct RecapShareImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { wrapper in
            wrapper.image.pngData() ?? Data()
        }
    }
}
