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
        case .hit:      return "Hit"
        case .onTrack:  return "On track"
        case .behind:   return "Behind"
        }
    }

    /// SF Symbol shown in status pills and goal rows.
    var icon: String {
        switch self {
        case .hit:      return "trophy.fill"
        case .onTrack:  return "bolt.fill"
        case .behind:   return "clock.fill"
        }
    }

    /// Pill background.
    var softColor: Color {
        switch self {
        case .hit:      return AppColors.statusHitSoft
        case .onTrack:  return AppColors.statusOnTrackSoft
        case .behind:   return AppColors.statusBehindSoft
        }
    }

    /// Text drawn on `softColor`, and status copy lines.
    var textColor: Color {
        switch self {
        case .hit:      return AppColors.statusHitText
        case .onTrack:  return AppColors.statusOnTrackText
        case .behind:   return AppColors.statusBehindText
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
