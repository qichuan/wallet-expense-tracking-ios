//
//  MerchantUtils.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI

class MerchantUtils {
    
    static func icon(for category: String?) -> String {
        guard let category = category?.lowercased() else {
            return "creditcard"
        }
        
        switch category {
        case "groceries":
            return "cart"
        case "dining out":
            return "cup.and.saucer"
        case "transport":
            return "car"
        case "entertainment":
            return "tv"
        case "shopping":
            return "bag"
        case "utilities":
            return "bolt"
        case "healthcare":
            return "cross"
        case "education":
            return "book"
        case "travel":
            return "airplane"
        case "gas":
            return "fuelpump"
        case "subscription":
            return "repeat"
        case "other":
            return "creditcard"
        default:
            return "creditcard"
        }
    }
    
    static func color(for category: String?) -> Color {
        guard let category = category?.lowercased() else {
            return .gray
        }
        
        switch category {
        case "groceries":
            return .green
        case "dining out":
            return .orange
        case "transport":
            return .blue
        case "entertainment":
            return .purple
        case "shopping":
            return .pink
        case "utilities":
            return .yellow
        case "healthcare":
            return .red
        case "education":
            return .indigo
        case "travel":
            return .cyan
        case "gas":
            return .blue
        case "subscription":
            return .mint
        case "other":
            return .gray
        default:
            return .gray
        }
    }
}
