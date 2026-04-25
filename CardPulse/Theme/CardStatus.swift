//
//  CardStatus.swift
//  CardPulse
//

import SwiftUI

enum CardStatus {
    case hit
    case onTrack
    case behind

    var label: String {
        switch self {
        case .hit:      return "HIT"
        case .onTrack:  return "ON TRACK"
        case .behind:   return "BEHIND"
        }
    }

    var color: Color {
        switch self {
        case .hit:      return AppColors.statusHit
        case .onTrack:  return AppColors.statusOnTrack
        case .behind:   return AppColors.statusBehind
        }
    }

    /// Derives a status from a progress ratio, optionally weighted by how far into the cycle we are.
    static func derive(progress: Double, pacing: Double? = nil) -> CardStatus {
        if progress >= 1.0 { return .hit }
        if let p = pacing {
            return progress + 0.05 >= p ? .onTrack : .behind
        }
        return progress >= 0.65 ? .onTrack : .behind
    }
}
