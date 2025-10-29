//
//  SettingsView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("autoSyncWallet") private var autoSyncWallet = true
    @State private var showingCSVManager = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // DATA MANAGEMENT Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DATA MANAGEMENT")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "rectangle.and.pencil.and.ellipsis",
                                title: "Manage Categories",
                                action: {}
                            )
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            SettingsRow(
                                icon: "square.and.arrow.up",
                                title: "Import from CSV",
                                action: { showingCSVManager = true }
                            )
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            SettingsRow(
                                icon: "square.and.arrow.down",
                                title: "Export to CSV",
                                action: { showingCSVManager = true }
                            )
                        }
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // SECURITY & PRIVACY Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SECURITY & PRIVACY")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "shield",
                                title: "Privacy & Permissions",
                                action: {}
                            )
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            SettingsRow(
                                icon: "touchid",
                                title: "App Lock",
                                action: {}
                            )
                        }
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // SUPPORT & ABOUT Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SUPPORT & ABOUT")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "questionmark.circle",
                                title: "Help & FAQ",
                                action: {}
                            )
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            SettingsRow(
                                icon: "info.circle",
                                title: "About CardPulse",
                                action: {}
                            )
                        }
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100)
            }
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
        }
        .sheet(isPresented: $showingCSVManager) {
            CSVManagerView()
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .stroke(Color.teal, lineWidth: 1)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
}
