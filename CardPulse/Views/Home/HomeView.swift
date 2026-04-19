//
//  HomeView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    
    @State private var showingAddTransaction = false
    @State private var showingHowToAutoTracking = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Suggestion banner for Shortcut automation setup
                ShortcutsBanner(showingHowToAutoTracking: $showingHowToAutoTracking)
                
                // Notification banner
                NotificationBanner()

                Group {
                if transactions.isEmpty {
                    VStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Text("No transactions yet")
                                .foregroundColor(.white)
                            Text("Tap + to add your first transaction")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                        }
                        .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal)
                } else {
                    AllTransactionsView()
                }
                }
            }
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingAddTransaction = true }) {
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
            )
        }
        .sheet(isPresented: $showingAddTransaction) {
            TransactionFormView()
        }
        .sheet(isPresented: $showingHowToAutoTracking) {
            HowToAutoTrackingView()
        }
    }
}


#Preview {
    HomeView()
        .modelContainer(ModelContainer.createMockContainer())
}
