//
//  AppAppearance.swift
//  CardPulse
//

import SwiftUI
import UIKit

/// The user's theme choice from the Me tab, stored under `AppAppearance.storageKey`.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    static let storageKey = "appearance"

    var id: String { rawValue }

    private var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// Overrides the style on every window, so sheets follow too. Done in UIKit
    /// because `.preferredColorScheme(nil)` doesn't reliably switch back to the
    /// system setting once a scheme has been forced.
    @MainActor
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }
}

/// Switches the home-screen icon to match the mascot colour picked on the Me tab.
enum AppIconSwitcher {
    /// `nil` is the primary icon (Gold); the others are alternate icon sets in the asset
    /// catalog, listed in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`.
    static func iconName(for palette: MascotPalette) -> String? {
        switch palette {
        case .gold: return nil
        case .pink: return "AppIcon-Pink"
        case .mint: return "AppIcon-Mint"
        }
    }

    /// iOS shows its own "You have changed the icon" alert after a successful switch.
    @MainActor
    static func apply(_ palette: MascotPalette) {
        let app = UIApplication.shared
        let name = iconName(for: palette)
        guard app.supportsAlternateIcons, app.alternateIconName != name else { return }
        app.setAlternateIconName(name) { error in
            if let error {
                print("Failed to change app icon: \(error.localizedDescription)")
            }
        }
    }
}
