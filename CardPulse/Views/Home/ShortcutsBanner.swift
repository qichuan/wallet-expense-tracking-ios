//
//  ShortcutsBanner.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI

struct ShortcutsBanner: View {
    @AppStorage("hasDismissedShortcutBanner") private var hasDismissedShortcutBanner = false
    @State private var showingDismissBannerAlert = false
    @Binding var showingHowToAutoTracking: Bool
    
    var body: some View {
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
            .alert("", isPresented: $showingDismissBannerAlert) {
                Button("OK") {
                    hasDismissedShortcutBanner = true
                }
            } message: {
                Text("You can view instructions again in Settings.")
            }
        }
        else {
            EmptyView()
        }
    }
}

#Preview {
    ShortcutsBanner(showingHowToAutoTracking: .constant(false))
        .background(Color(red: 0.05, green: 0.1, blue: 0.2))
}

