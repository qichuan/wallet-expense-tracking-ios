//
//  CardDetailView.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct CardDetailView: View {
    let card: Card
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    
    @State private var showingAddTransaction = false
    
    private var cardTransactions: [Transaction] {
        transactions.filter { $0.card?.id == card.id }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text(card.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(".... \(card.last4)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Placeholder for balance
                    Color.clear
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal)
                
                // Minimum Spend Goal Section
                VStack(spacing: 16) {
                    Text("Minimum Spend Goal")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 12)
                            .frame(width: 200, height: 200)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: card.progressPercentage)
                            .stroke(
                                LinearGradient(
                                    colors: [.teal, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.0), value: card.progressPercentage)
                        
                        VStack(spacing: 4) {
                            Text("$\(Double(truncating: card.currentSpent as NSDecimalNumber), specifier: "%.0f")")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("of $\(Double(truncating: card.totalGoal as NSDecimalNumber), specifier: "%.0f")")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal)
                
                // Rewards and Deadline Section
                HStack(spacing: 16) {
                    // Rewards Earned
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rewards Earned")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            Text("1,250")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                            
                            Text("Miles")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Goal Deadline
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal Deadline")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            Text("\(card.daysRemaining)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Days Left")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Recent Transactions Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Recent Transactions")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {}) {
                            HStack(spacing: 4) {
                                Text("Date")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    
                    LazyVStack(spacing: 8) {
                        ForEach(cardTransactions.prefix(10)) { transaction in
                            TransactionRow(transaction: transaction)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color(red: 0.05, green: 0.1, blue: 0.2))
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingAddTransaction = true }) {
                        Image(systemName: "pencil")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.teal)
                            .clipShape(Circle())
                            .shadow(radius: 8)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        )
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(selectedCard: card)
        }
    }
}


#Preview {
    let card = Card(
        name: "Gold Card",
        bank: "Chase",
        last4: "1234",
        totalGoal: 3000,
        goalDeadline: Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date(),
        rewardType: "miles",
        currentSpent: 1500
    )
    
    return CardDetailView(card: card)
        .modelContainer(for: [Card.self, Transaction.self], inMemory: true)
}
