//
//  TransactionMapClusteringTests.swift
//  CardPulseTests
//

import XCTest
import CoreLocation
import MapKit
@testable import CardPulse

/// Covers the Analysis map's grouping and auto-fit math (issue #38): the region
/// must frame every location (e.g. both Singapore and Johor Bahru), adjacent
/// transactions must merge into one aggregated cluster, and a lone location must
/// still get a sane zoom.
final class TransactionMapClusteringTests: XCTestCase {

    // Reference coordinates.
    private let marinaBay = CLLocationCoordinate2D(latitude: 1.2834, longitude: 103.8607)
    private let orchard   = CLLocationCoordinate2D(latitude: 1.3048, longitude: 103.8318)
    private let johorBahru = CLLocationCoordinate2D(latitude: 1.4927, longitude: 103.7414)

    private func point(_ c: CLLocationCoordinate2D, _ amount: Double) -> MapTransactionPoint {
        MapTransactionPoint(coordinate: c, amount: amount)
    }

    // MARK: - Region

    func testRegion_Empty_ReturnsNil() {
        XCTAssertNil(TransactionMapClustering.region(for: []))
    }

    func testRegion_CoversBothCities() throws {
        let points = [point(marinaBay, 10), point(johorBahru, 20)]
        let region = try XCTUnwrap(TransactionMapClustering.region(for: points))

        // Center sits between the two coordinates.
        XCTAssertEqual(region.center.latitude, (marinaBay.latitude + johorBahru.latitude) / 2, accuracy: 1e-9)
        XCTAssertEqual(region.center.longitude, (marinaBay.longitude + johorBahru.longitude) / 2, accuracy: 1e-9)

        // Span is wide enough to contain both points with headroom to spare.
        let latSpread = johorBahru.latitude - marinaBay.latitude
        let lonSpread = marinaBay.longitude - johorBahru.longitude
        XCTAssertGreaterThan(region.span.latitudeDelta, latSpread)
        XCTAssertGreaterThan(region.span.longitudeDelta, lonSpread)
    }

    func testRegion_SingleLocation_UsesMinimumSpan() throws {
        let region = try XCTUnwrap(TransactionMapClustering.region(for: [point(orchard, 50)]))
        XCTAssertEqual(region.center.latitude, orchard.latitude, accuracy: 1e-9)
        XCTAssertEqual(region.center.longitude, orchard.longitude, accuracy: 1e-9)
        // Lone pin gets the 0.02° floor rather than a zero span.
        XCTAssertEqual(region.span.latitudeDelta, 0.02, accuracy: 1e-9)
        XCTAssertEqual(region.span.longitudeDelta, 0.02, accuracy: 1e-9)
    }

    // MARK: - Clustering

    func testClusters_Empty_ReturnsEmpty() {
        XCTAssertTrue(TransactionMapClustering.clusters(for: []).isEmpty)
    }

    func testClusters_AdjacentPointsMergeWithSummedAmount() {
        let nearby = CLLocationCoordinate2D(latitude: marinaBay.latitude + 0.0002,
                                            longitude: marinaBay.longitude - 0.0002)
        let clusters = TransactionMapClustering.clusters(
            for: [point(marinaBay, 12.50), point(nearby, 7.50)],
            threshold: 0.001
        )

        XCTAssertEqual(clusters.count, 1)
        let cluster = clusters[0]
        XCTAssertEqual(cluster.count, 2)
        XCTAssertEqual(cluster.totalAmount, 20.0, accuracy: 1e-9)
        // Centroid is the mean of the two coordinates.
        XCTAssertEqual(cluster.coordinate.latitude, (marinaBay.latitude + nearby.latitude) / 2, accuracy: 1e-9)
    }

    func testClusters_DistantPointsStaySeparate() {
        let clusters = TransactionMapClustering.clusters(
            for: [point(marinaBay, 10), point(johorBahru, 20)],
            threshold: 0.01
        )
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters.map { $0.count }, [1, 1])
    }

    func testClusters_SameLocationManyTransactions_OneClusterCountsAll() {
        let points = (0..<5).map { _ in point(orchard, 4) }
        let clusters = TransactionMapClustering.clusters(for: points)
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].count, 5)
        XCTAssertEqual(clusters[0].totalAmount, 20.0, accuracy: 1e-9)
    }

    func testClusters_DerivedThreshold_GroupsWithinCitySeparatesAcrossBorder() throws {
        // Marina Bay + Orchard are ~3 km apart (same city); JB is ~25 km north.
        // With the span-derived threshold the two SG spots merge and JB stands alone.
        let clusters = TransactionMapClustering.clusters(for: [
            point(marinaBay, 10), point(orchard, 15), point(johorBahru, 30),
        ])
        XCTAssertEqual(clusters.count, 2)
        let jbCluster = try XCTUnwrap(clusters.first { $0.count == 1 })
        XCTAssertEqual(jbCluster.totalAmount, 30.0, accuracy: 1e-9)
        let sgCluster = try XCTUnwrap(clusters.first { $0.count == 2 })
        XCTAssertEqual(sgCluster.totalAmount, 25.0, accuracy: 1e-9)
    }
}
