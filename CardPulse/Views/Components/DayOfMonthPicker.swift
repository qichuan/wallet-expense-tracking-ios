//
//  DayOfMonthPicker.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI

struct DayOfMonthPicker: View {
    @Binding var selectedDay: Int
    @State private var showingPicker = false
    
    private let days = Array(1...31)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                showingPicker.toggle()
            }) {
                HStack(spacing: 8) {
                    Text("By Day")
                    HStack(spacing: 6) {
                        Text("\(selectedDay)")
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .rotationEffect(.degrees(showingPicker ? 180 : 0))
                    }
                    Text("of the month")
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if showingPicker {
                VStack(spacing: 0) {
                    // Simple 7-column grid of days (1-31)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                        ForEach(days, id: \.self) { day in
                            Button(action: {
                                selectedDay = day
                                showingPicker = false
                            }) {
                                Text("\(day)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(selectedDay == day ? .white : .primary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(selectedDay == day ? Color.teal : Color.clear)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(selectedDay == day ? Color.teal : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    // .transition(.asymmetric(
                    //     insertion: .move(edge: .top).combined(with: .opacity),
                    //     removal: .move(edge: .top).combined(with: .opacity)
                    // ))
                }
                .padding(.top, 8)
            }
            
            Text("Your monthly mininum spending resets on this date. Try to reach the minimum spending amount before then to earn your rewards")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        //.animation(.easeInOut(duration: 0.3), value: showingPicker)
    }
}

#Preview {
    VStack(spacing: 20) {
        DayOfMonthPicker(selectedDay: .constant(15))
        
        DayOfMonthPicker(selectedDay: .constant(1))
        
        DayOfMonthPicker(selectedDay: .constant(31))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
