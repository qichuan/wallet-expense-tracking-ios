//
//  TransactionLocationMapCard.swift
//  CardPulse
//

import SwiftUI
import MapKit

/// Embedded map for the Analysis page showing where the period's transactions were
/// made. Nearby transactions are grouped into clusters whose bubble shows the
/// aggregated spend (in the default currency). The camera auto-fits all points.
///
/// The parent is responsible for only rendering this when `points` is non-empty —
/// an empty map is never shown (issue #38).
struct TransactionLocationMapCard: View {
    let points: [MapTransactionPoint]
    /// Default-currency symbol for the aggregated bubble labels.
    let currencySymbol: String

    @State private var cameraPosition: MapCameraPosition = .automatic

    private var clusters: [TransactionCluster] {
        TransactionMapClustering.clusters(for: points)
    }

    /// Stable key over the point set so the camera re-fits when the selected period
    /// changes (coordinates rounded to avoid churn from floating-point noise).
    private var pointsKey: String {
        points
            .map { String(format: "%.4f,%.4f", $0.coordinate.latitude, $0.coordinate.longitude) }
            .joined(separator: "|")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Places")
            // Non-interactive: the card lives inside the Analysis ScrollView, and an
            // interactive map would swallow the vertical scroll gesture. The camera
            // auto-fits all points, so manual panning isn't needed (matches the
            // read-only map on the transaction detail screen).
            Map(position: $cameraPosition, interactionModes: []) {
                ForEach(clusters) { cluster in
                    Annotation("", coordinate: cluster.coordinate) {
                        clusterBubble(cluster)
                    }
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .allowsHitTesting(false)
            .onAppear(perform: fitToPoints)
            .onChange(of: pointsKey) { fitToPoints() }
        }
        .cardSurface(padding: 18)
    }

    private func fitToPoints() {
        guard let region = TransactionMapClustering.region(for: points) else { return }
        cameraPosition = .region(region)
    }

    @ViewBuilder
    private func clusterBubble(_ cluster: TransactionCluster) -> some View {
        VStack(spacing: 2) {
            Text("\(currencySymbol)\(cluster.totalAmount, specifier: "%.0f")")
                .font(AppTypography.bannerCTA)
                .foregroundColor(AppColors.onAccent)
            if cluster.count > 1 {
                Text("\(cluster.count) txns")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.onAccent.opacity(0.85))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.accent)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(AppColors.onAccent.opacity(0.5), lineWidth: 1)
        )
        .shadow(radius: 3, y: 1)
    }
}

#Preview {
    let singapore = [
        MapTransactionPoint(coordinate: .init(latitude: 1.2834, longitude: 103.8607), amount: 42),
        MapTransactionPoint(coordinate: .init(latitude: 1.2840, longitude: 103.8610), amount: 18),
        MapTransactionPoint(coordinate: .init(latitude: 1.3521, longitude: 103.8198), amount: 120),
        MapTransactionPoint(coordinate: .init(latitude: 1.4927, longitude: 103.7414), amount: 65), // JB-ish
    ]
    TransactionLocationMapCard(points: singapore, currencySymbol: "$")
        .padding()
        .background(AppColors.backgroundPrimary)
}
