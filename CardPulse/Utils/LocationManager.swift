//
//  LocationManager.swift
//  CardPulse
//

import Foundation
import CoreLocation
import Combine

/// A captured location plus its reverse-geocoded place name, ready to store on a `Transaction`.
struct CapturedLocation {
    let latitude: Double
    let longitude: Double
    let placeName: String?
}

/// Single entry point for location permission + one-shot location capture.
///
/// The `@MainActor ObservableObject` surface (`authorizationStatus`, `requestPermission`)
/// is used by the onboarding step and the add-transaction form to drive UI. The static
/// `capture()` helper is a self-contained one-shot fetch (location + reverse geocode)
/// usable from anywhere — including the App Intent, which has no view to observe state.
@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        self.authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
    }

    /// True when the app may read location (foreground "when in use" or "always").
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// Permission has never been requested — the system prompt can still be shown.
    var isUndetermined: Bool {
        authorizationStatus == .notDetermined
    }

    /// Requests "when in use" authorization. No-op once a decision has been made.
    func requestPermission() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    /// Best-effort one-shot capture of the device's current location, reverse-geocoded to a
    /// place name. Returns `nil` when location is not authorized or the fix/geocode fails.
    /// Safe to call from any actor; uses its own short-lived `CLLocationManager`.
    static func capture() async -> CapturedLocation? {
        let status = CLLocationManager().authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }
        guard let location = await OneShotLocationFetcher().fetch() else { return nil }
        let placeName = await reverseGeocode(location)
        return CapturedLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            placeName: placeName
        )
    }

    /// Reverse-geocodes a coordinate into a human-readable place name (point of interest
    /// name when available, otherwise a street/locality address). Returns `nil` on failure.
    private static func reverseGeocode(_ location: CLLocation) async -> String? {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        guard let placemark = placemarks?.first else { return nil }
        if let name = placemark.name, !name.isEmpty { return name }
        let parts = [placemark.thoroughfare, placemark.locality].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

/// Wraps `CLLocationManager`'s delegate-based single fix in an async call. Retains itself
/// for the lifetime of the request so the delegate callbacks are delivered, and resolves
/// to `nil` if no fix arrives within `timeout` so a slow GPS lock can't block the caller.
///
/// Main-actor isolated: `capture()` drives it from the main actor, and `CLLocationManager`
/// delivers its delegate callbacks on the same (main) run loop, so every state mutation —
/// including the inherited-actor timeout `Task` — is serialized without a data race.
@MainActor
private final class OneShotLocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var selfRef: OneShotLocationFetcher?
    private var timeoutTask: Task<Void, Never>?

    func fetch(timeout: TimeInterval = 6) async -> CLLocation? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.selfRef = self
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.requestLocation()
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self?.finish(with: nil)
            }
        }
    }

    private func finish(with location: CLLocation?) {
        guard let continuation else { return }   // already resolved
        timeoutTask?.cancel()
        timeoutTask = nil
        self.continuation = nil
        continuation.resume(returning: location)
        selfRef = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in self.finish(with: last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(with: nil) }
    }
}
