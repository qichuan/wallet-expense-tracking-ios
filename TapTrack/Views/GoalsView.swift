//
//  GoalsView.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [Card]
    
    @State private var selectedTab = 0
    @State private var showingAddGoal = false
    @State private var selectedCard: Card?
    
    private var activeCards: [Card] {
        cards.filter { $0.goalDeadline > Date() }
    }
    
    private var completedCards: [Card] {
        cards.filter { $0.goalDeadline <= Date() || $0.progressPercentage >= 1.0 }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("My Goals")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { showingAddGoal = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.teal)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Tab Bar
                HStack(spacing: 0) {
                    Button(action: { selectedTab = 0 }) {
                        Text("Active")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTab == 0 ? Color.teal : Color.clear)
                            )
                    }
                    
                    Button(action: { selectedTab = 1 }) {
                        Text("Completed")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTab == 1 ? Color.teal : Color.clear)
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if selectedTab == 0 {
                            ForEach(activeCards) { card in
                                Button(action: { 
                                    selectedCard = card
                                }) {
                                    GoalCard(card: card)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        } else {
                            ForEach(completedCards) { card in
                                Button(action: { 
                                    selectedCard = card
                                }) {
                                    GoalCard(card: card)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
            }
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalView()
        }
        .sheet(item: $selectedCard) { card in
            EditGoalView(card: card)
        }
    }
}

struct GoalCard: View {
    let card: Card
    
    private var bankIcon: String {
        switch card.bank.lowercased() {
        case "chase":
            return "building.2"
        case "american express", "amex":
            return "creditcard"
        case "citi":
            return "building"
        default:
            return "creditcard"
        }
    }
    
    private var rewardTypeColor: Color {
        switch card.rewardType.lowercased() {
        case "miles":
            return .teal
        case "cashback":
            return .yellow
        case "points":
            return .purple
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
        case "points":
            return "Points"
        default:
            return "Bonus"
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
                // Card Name and Goal Type
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("\(rewardTypeText) Goal")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Progress Bar
                VStack(spacing: 4) {
                    ProgressView(value: card.progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: .teal))
                        .frame(height: 6)
                    
                    HStack {
                        Text("$\(Double(truncating: card.currentSpent as NSDecimalNumber), specifier: "%.0f") / $\(Double(truncating: card.totalGoal as NSDecimalNumber), specifier: "%.0f")")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(card.daysRemaining) days left")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Reward Type Badge
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
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }
}

#Preview {
    GoalsView()
        .modelContainer(ModelContainer.createMockContainer())
}
