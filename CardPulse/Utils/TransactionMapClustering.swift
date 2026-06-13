//
//  TransactionMapClustering.swift
//  CardPulse
//

import Foundation
import CoreLocation
import MapKit

/// A single located transaction reduced to what the Analysis map needs: a
/// coordinate and an amount already converted to the user's default currency.
struct MapTransactionPoint {
    let coordinate: CLLocationCoordinate2D
    /// Amount in the default currency (callers FX-convert before constructing).
    let amount: Double
}

/// A group of nearby transactions rendered as one annotation, carrying the
/// aggregated amount and member count.
struct TransactionCluster: Identifiable {
    let id = UUID()
    /// Centroid of the member coordinates.
    let coordinate: CLLocationCoordinate2D
    /// Sum of member amounts, in the default currency.
    let totalAmount: Double
    /// Number of transactions in the cluster.
    let count: Int
}

/// Pure geometry helpers for the Analysis transactions map. Kept separate from the
/// SwiftUI view so the grouping and region math can be reasoned about (and tested)
/// without a `Map`.
enum TransactionMapClustering {

    /// Greedy distance-based clustering. Each point joins the first existing cluster
    /// whose running centroid is within `threshold` degrees (compared per-axis, a
    /// cheap bounding-box test); otherwise it seeds a new cluster. When `threshold`
    /// is `nil` it is derived from the overall span so "adjacent" scales with how far
    /// apart the transactions are — points across one city group tighter than points
    /// spread across a region.
    static func clusters(for points: [MapTransactionPoint], threshold: Double? = nil) -> [TransactionCluster] {
        guard !points.isEmpty else { return [] }

        let effectiveThreshold = threshold ?? derivedThreshold(for: points)

        // Accumulators keep running sums so the centroid is exact without a second pass.
        var buckets: [(sumLat: Double, sumLon: Double, total: Double, count: Int)] = []
        for point in points {
            let lat = point.coordinate.latitude
            let lon = point.coordinate.longitude
            if let i = buckets.firstIndex(where: { bucket in
                let centroidLat = bucket.sumLat / Double(bucket.count)
                let centroidLon = bucket.sumLon / Double(bucket.count)
                return abs(centroidLat - lat) <= effectiveThreshold
                    && abs(centroidLon - lon) <= effectiveThreshold
            }) {
                buckets[i].sumLat += lat
                buckets[i].sumLon += lon
                buckets[i].total += point.amount
                buckets[i].count += 1
            } else {
                buckets.append((lat, lon, point.amount, 1))
            }
        }

        return buckets.map { bucket in
            TransactionCluster(
                coordinate: CLLocationCoordinate2D(
                    latitude: bucket.sumLat / Double(bucket.count),
                    longitude: bucket.sumLon / Double(bucket.count)
                ),
                totalAmount: bucket.total,
                count: bucket.count
            )
        }
    }

    /// Region that frames every point with headroom around the edges and a sane
    /// minimum span so a single location isn't zoomed to street level. `nil` when
    /// there are no points.
    static func region(for points: [MapTransactionPoint]) -> MKCoordinateRegion? {
        guard !points.isEmpty else { return nil }
        let lats = points.map { $0.coordinate.latitude }
        let lons = points.map { $0.coordinate.longitude }
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, minimumSpan),
            longitudeDelta: max((maxLon - minLon) * 1.4, minimumSpan)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Tuning

    /// Floor span (~2 km) so a lone pin or a tight group still reads as a place, not a point.
    private static let minimumSpan: Double = 0.02

    /// Cluster radius as a fraction of the larger span dimension, floored at ~90 m so
    /// two taps at the same shop always merge even when that's the only location.
    private static func derivedThreshold(for points: [MapTransactionPoint]) -> Double {
        let lats = points.map { $0.coordinate.latitude }
        let lons = points.map { $0.coordinate.longitude }
        let span = max((lats.max()! - lats.min()!), (lons.max()! - lons.min()!))
        return max(span * 0.08, 0.0008)
    }
}
