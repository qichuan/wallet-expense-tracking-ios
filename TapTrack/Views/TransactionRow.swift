//
//  TransactionRow.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    
    private var merchantIcon: String {
        switch transaction.merchant.lowercased() {
        case let merchant where merchant.contains("apple"):
            return "apple.logo"
        case let merchant where merchant.contains("starbucks"):
            return "cup.and.saucer"
        case let merchant where merchant.contains("doordash"):
            return "takeoutbag.and.cup.and.straw"
        case let merchant where merchant.contains("whole foods"):
            return "leaf"
        case let merchant where merchant.contains("uber"):
            return "car"
        case let merchant where merchant.contains("netflix"):
            return "tv"
        case let merchant where merchant.contains("amazon"):
            return "shippingbox"
        case let merchant where merchant.contains("target"):
            return "target"
        case let merchant where merchant.contains("mcdonald"):
            return "takeoutbag.and.cup.and.straw"
        case let merchant where merchant.contains("shell"):
            return "fuelpump"
        default:
            return "creditcard"
        }
    }
    
    private var iconColor: Color {
        switch transaction.merchant.lowercased() {
        case let merchant where merchant.contains("apple"):
            return .black
        case let merchant where merchant.contains("starbucks"):
            return .green
        case let merchant where merchant.contains("doordash"):
            return .teal
        case let merchant where merchant.contains("whole foods"):
            return .green
        case let merchant where merchant.contains("uber"):
            return .blue
        case let merchant where merchant.contains("netflix"):
            return .red
        case let merchant where merchant.contains("amazon"):
            return .orange
        case let merchant where merchant.contains("target"):
            return .red
        case let merchant where merchant.contains("mcdonald"):
            return .yellow
        case let merchant where merchant.contains("shell"):
            return .blue
        default:
            return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Merchant Icon
            Circle()
                .fill(iconColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: merchantIcon)
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    if let card = transaction.card {
                        Text("\(card.name) •••\(card.last4)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    if let category = transaction.category {
                        Text("• \(category)")
                            .font(.caption)
                            .foregroundColor(.teal)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(transaction.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(transaction.date, style: .time)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .italic()
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Amount
            Text("-$\(Double(truncating: transaction.amount as NSDecimalNumber), specifier: "%.2f")")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    let transaction = Transaction(
        merchant: "Apple Store",
        amount: 999.00,
        date: Date(),
        category: "Shopping"
    )
    
    return TransactionRow(transaction: transaction)
        .padding()
        .background(Color(red: 0.05, green: 0.1, blue: 0.2))
}
