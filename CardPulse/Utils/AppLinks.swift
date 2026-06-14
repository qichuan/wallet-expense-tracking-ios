//
//  AppLinks.swift
//  CardPulse
//

import Foundation

/// Canonical external links for the app. Centralised so CTAs and attribution
/// parameters live in one place.
enum AppLinks {
    /// App Store product page. The `ct` campaign token attributes installs that
    /// originate from a shared recap CTA.
    static let appStore = URL(string: "https://apps.apple.com/app/apple-store/id6754640005?pt=128186520&ct=from_cta&mt=8")!
}
