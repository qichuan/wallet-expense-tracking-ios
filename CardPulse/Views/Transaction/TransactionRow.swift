//
//  TransactionRow.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "d MMM yyyy" // e.g., 20 Oct 2025
        return df
    }()
    
    private var merchantIcon: String {
        MerchantUtils.icon(for: transaction.category)
    }
    
    private var iconColor: Color {
        MerchantUtils.color(for: transaction.category)
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
                
                
                if let card = transaction.card {
                    Label(card.name, systemImage: "creditcard")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack(spacing: 8) {
                    Text(Self.dateFormatter.string(from: transaction.date))
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
    let card = Card(
        name: "Chase Sapphire Preferred",
        minimumSpendingAmount: 4000,
        hasMinimumSpending: true,
        rewardType: "miles",
        minimumSpendingByDayOfMonth: 15
    )
    
    VStack {
        TransactionRow(transaction: Transaction(
            merchant: "Apple Store",
            amount: 999.00,
            date: Date(),
            category: "Shopping",
            card: card
        ))
            
        TransactionRow(transaction: Transaction(
            merchant: "Mr. DIY",
            amount: 9.00,
            date: Date(),
            category: "Other",
            card: card
        ))
        
        TransactionRow(transaction: Transaction(
            merchant: "Netflix",
            amount: 9.00,
            date: Date(),
            category: "Entertainment",
            card: card
        ))
        
        TransactionRow(transaction: Transaction(
            merchant: "Singapore Airlines",
            amount: 999.00,
            date: Date(),
            category: "Travel",
            card: card
        ))
        
    }.background(Color(red: 0.05, green: 0.1, blue: 0.2)).padding()
    
    
}
