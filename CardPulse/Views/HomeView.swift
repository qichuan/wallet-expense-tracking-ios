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
    @State private var showingAllTransactions = false
    @State private var selectedTransaction: Transaction?
    @State private var showingHowToAutoTracking = false
    @State private var showingDismissBannerAlert = false
    @AppStorage("hasDismissedShortcutBanner") private var hasDismissedShortcutBanner = false
    
    
    private var recentTransactions: [Transaction] {
        transactions
            .sorted { $0.date > $1.date }
            .prefix(10)
            .map { $0 }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Suggestion banner for Shortcut automation setup
                if !hasDismissedShortcutBanner {
                    ZStack(alignment: .topTrailing) {
                        HStack(alignment: .top, spacing: 12) {
                            Image("shortcuts")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Set up an automation in Shortcuts app")
                                    .foregroundColor(.white)
                                    .font(.headline)
                                Text("Use an automation in Shortcuts app to track tap‑to‑pay transactions automatically.")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.subheadline)

                                Button(action: { showingHowToAutoTracking = true }) {
                                    Text("View Instructions")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.yellow)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .padding(.trailing, 32)
                        
                        Button(action: { showingDismissBannerAlert = true }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                    }
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

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
                    ScrollView {
                        VStack(spacing: 20) {
                            // Latest Transactions Section
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Latest Transactions")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                }
                                
                                LazyVStack(spacing: 8) {
                                    ForEach(recentTransactions) { transaction in
                                        Button(action: { selectedTransaction = transaction }) {
                                            TransactionRow(transaction: transaction)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    
                                    // View All button at the end of the list
                                    Button(action: { showingAllTransactions = true }) {
                                        HStack {
                                            Spacer()
                                            Text("View All")
                                                .font(.subheadline)
                                                .foregroundColor(.teal)
                                            Spacer()
                                        }
                                        .padding(.vertical, 12)
                                        .background(Color.teal.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 100)
                    }
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
                                .background(Color.yellow)
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
        .sheet(isPresented: $showingAllTransactions) {
            AllTransactionsView()
        }
        .sheet(isPresented: $showingHowToAutoTracking) {
            HowToAutoTrackingView()
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionFormView(transaction: transaction)
        }
        .alert("", isPresented: $showingDismissBannerAlert) {
            Button("OK") {
                hasDismissedShortcutBanner = true
            }
        } message: {
            Text("You can view instructions again in Settings.")
        }
    }
}


#Preview {
    HomeView()
        .modelContainer(ModelContainer.createMockContainer())
}
