//
//  ActivityShareSheet.swift
//  CardPulse
//

import SwiftUI
import UIKit

/// Thin wrapper around `UIActivityViewController` so we can share heterogeneous items
/// (e.g. an image plus a caption string with a link) — something `ShareLink` can't do.
/// Used by the spending recap to attach the rendered image alongside a download CTA.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
