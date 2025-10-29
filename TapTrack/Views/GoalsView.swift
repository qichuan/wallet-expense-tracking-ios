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
    
    @State private var showingAddGoal = false
    @State private var selectedCard: Card?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
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
                
                // All goals
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if cards.isEmpty {
                            VStack(spacing: 8) {
                                Text("No cards yet")
                                    .foregroundColor(.white)
                                Text("Tap + to add your first card and goal")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.caption)
                            }
                            .padding()
                        } else {
                            ForEach(cards) { card in
                                Button(action: { 
                                    selectedCard = card
                                }) {
                                    CardRow(card: card)
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
            AddCardView()
        }
        .sheet(item: $selectedCard) { card in
            EditCardView(card: card)
        }
    }
}


#Preview {
    GoalsView()
        .modelContainer(ModelContainer.createMockContainer())
}
