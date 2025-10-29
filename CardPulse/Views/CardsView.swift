//
//  CardsView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct CardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [Card]
    
    @State private var showingAddGoal = false
    @State private var selectedCard: Card?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.1, blue: 0.2)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Content that stretches to bottom
                    if cards.isEmpty {
                        VStack(spacing: 8) {
                            Spacer()
                            Text("No cards yet")
                                .foregroundColor(.white)
                            Text("Tap + to add your first card and goal")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(cards) { card in
                                    Button(action: { 
                                        selectedCard = card
                                    }) {
                                        CardRow(card: card)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .padding(.bottom, 100) // Space for floating button
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                
                // Floating + button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingAddGoal = true }) {
                            Image(systemName: "plus")
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
            }
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
    CardsView()
        .modelContainer(ModelContainer.createMockContainer())
}
