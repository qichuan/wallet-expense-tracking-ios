//
//  MapSnapshotRenderer.swift
//  CardPulse
//

import UIKit
import SwiftUI
import MapKit

/// Renders a static map image for the spending recap. `ImageRenderer` cannot capture a
/// live `Map`, so the recap embeds a bitmap produced by `MKMapSnapshotter` instead, with
/// a dot drawn at each cluster centroid (reusing `TransactionMapClustering`).
enum MapSnapshotRenderer {

    /// Produces a dark-mode snapshot framing all `points` with a marker per cluster.
    /// Returns `nil` when there are no points or the snapshot fails. Completion is
    /// delivered on the main queue.
    static func snapshot(points: [MapTransactionPoint],
                         size: CGSize,
                         completion: @escaping (UIImage?) -> Void) {
        guard let region = TransactionMapClustering.region(for: points) else {
            completion(nil)
            return
        }

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)

        let clusters = TransactionMapClustering.clusters(for: points)
        let markerFill = UIColor(AppColors.accent)
        let markerStroke = UIColor(AppColors.onAccent)

        MKMapSnapshotter(options: options).start(with: .main) { snapshot, _ in
            guard let snapshot else {
                completion(nil)
                return
            }
            let composed = UIGraphicsImageRenderer(size: size).image { _ in
                snapshot.image.draw(at: .zero)
                let radius: CGFloat = 6
                for cluster in clusters {
                    let point = snapshot.point(for: cluster.coordinate)
                    // Skip clusters that fall outside the rendered rect.
                    guard point.x >= 0, point.y >= 0, point.x <= size.width, point.y <= size.height else { continue }
                    let rect = CGRect(x: point.x - radius, y: point.y - radius,
                                      width: radius * 2, height: radius * 2)
                    let dot = UIBezierPath(ovalIn: rect)
                    markerFill.setFill()
                    markerStroke.setStroke()
                    dot.lineWidth = 2
                    dot.fill()
                    dot.stroke()
                }
            }
            completion(composed)
        }
    }
}
