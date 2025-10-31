//
//  GoalCard.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct CardRow: View {
    let card: Card
    
    private var bankIcon: String { "creditcard" }
    
    private var rewardTypeColor: Color {
        switch card.rewardType.lowercased() {
        case "miles":
            return .teal
        case "cashback":
            return .yellow
        
        default:
            return .teal
        }
    }
    
    private var rewardTypeText: String {
        switch card.rewardType.lowercased() {
        case "miles":
            return "Miles"
        case "cashback":
            return "Cashback"
        default:
            return "None"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Bank Logo
            Circle()
                .fill(Color.white)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: bankIcon)
                        .font(.title2)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Card Name 
                Text(card.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                
                // Progress Bar (only if card has a goal)
                if card.totalGoal > 0 {
                    VStack(spacing: 4) {
                        ProgressView(value: card.progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: .teal))
                            .frame(height: 6)
                        
                        HStack {
                            Text("$\(Double(truncating: card.monthlySpent as NSDecimalNumber), specifier: "%.0f") / $\(Double(truncating: card.totalGoal as NSDecimalNumber), specifier: "%.0f")")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(card.daysRemaining) days to statement")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                // Reward Type Badge (hidden for none)
                if card.rewardType.lowercased() != "none" {
                    HStack {
                        Text(rewardTypeText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(rewardTypeColor == .yellow ? .black : .white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(rewardTypeColor)
                            .cornerRadius(6)
                        
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }
}

#Preview {
    let card = Card(
        name: "Chase Sapphire Preferred",
        totalGoal: 4000,
        rewardType: "miles",
        statementDay: 15
    )
    
    CardRow(card: card)
        .padding()
        .background(Color(red: 0.05, green: 0.1, blue: 0.2))
}
