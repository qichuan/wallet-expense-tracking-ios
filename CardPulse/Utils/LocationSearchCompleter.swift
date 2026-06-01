//
//  LocationSearchCompleter.swift
//  CardPulse
//

import Foundation
import MapKit
import Combine

/// Drives address/point-of-interest autocomplete for the transaction form's location box.
///
/// Wraps `MKLocalSearchCompleter` behind a debounced `query` so typing produces a short
/// list of `MKLocalSearchCompletion` suggestions. Resolving a chosen suggestion to an
/// actual coordinate is done separately via `resolve(_:)`, which runs an `MKLocalSearch`.
/// Autocomplete itself needs no location permission — it's a network lookup.
@MainActor
final class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    /// Bound to the location text field. Each change is debounced before hitting the network.
    @Published var query: String = ""
    /// Latest suggestions for the current query (capped). Empty when the query is too short.
    @Published private(set) var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()
    private var cancellable: AnyCancellable?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        cancellable = $query
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] text in
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count >= 3 else {
                    self?.results = []
                    return
                }
                self?.completer.queryFragment = trimmed
            }
    }

    /// Clears the current suggestion list (e.g. right after the user picks one).
    func clearResults() {
        results = []
    }

    /// Resolves a chosen completion into a concrete coordinate via `MKLocalSearch`.
    /// Returns `nil` when the lookup fails.
    func resolve(_ completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request(completion: completion)
        let response = try? await MKLocalSearch(request: request).start()
        return response?.mapItems.first?.placemark.coordinate
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = Array(completer.results.prefix(6))
        Task { @MainActor in self.results = results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.results = [] }
    }
}
