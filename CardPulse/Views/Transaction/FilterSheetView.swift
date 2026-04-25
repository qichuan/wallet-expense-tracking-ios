//
//  FilterSheetView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI

struct FilterSheetView: View {
    let cards: [Card]
    @Binding var selectedCard: Card?
    @Binding var useDateRange: Bool
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    
    @Environment(\.dismiss) private var dismiss
    
    // Local state for date pickers (need non-optional dates)
    @State private var localStartDate: Date
    @State private var localEndDate: Date
    
    init(cards: [Card], selectedCard: Binding<Card?>, useDateRange: Binding<Bool>, startDate: Binding<Date?>, endDate: Binding<Date?>) {
        self.cards = cards
        self._selectedCard = selectedCard
        self._useDateRange = useDateRange
        self._startDate = startDate
        self._endDate = endDate
        
        // Initialize local dates from bindings or defaults
        let defaultStartDate = startDate.wrappedValue ?? Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let defaultEndDate = endDate.wrappedValue ?? Date()
        
        _localStartDate = State(initialValue: defaultStartDate)
        _localEndDate = State(initialValue: defaultEndDate)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Card Filter Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Card Filter")
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Picker("Card", selection: $selectedCard) {
                            Text("All Cards").tag(nil as Card?)
                            ForEach(cards) { card in
                                Text(card.name).tag(card as Card?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    
                    // Date Range Filter Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Date Range Filter")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $useDateRange)
                                .labelsHidden()
                                .onChange(of: useDateRange) { _, newValue in
                                    if newValue {
                                        // When enabling date range, set dates if not already set
                                        if startDate == nil {
                                            startDate = localStartDate
                                        }
                                        if endDate == nil {
                                            endDate = localEndDate
                                        }
                                    } else {
                                        // When disabling, clear dates
                                        startDate = nil
                                        endDate = nil
                                    }
                                }
                        }
                        
                        if useDateRange {
                            VStack(spacing: 12) {
                                HStack {
                                    DatePicker("Start Date", selection: $localStartDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .colorScheme(.dark)
                                        .onChange(of: localStartDate) { _, newValue in
                                            startDate = newValue
                                            // Ensure end date is not before start date
                                            if let end = endDate, newValue > end {
                                                endDate = newValue
                                                localEndDate = newValue
                                            }
                                    }
                                }
                                
                                HStack {
                                    DatePicker("End Date", selection: $localEndDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .colorScheme(.dark)
                                        .onChange(of: localEndDate) { _, newValue in
                                            endDate = newValue
                                            // Ensure start date is not after end date
                                            if let start = startDate, newValue < start {
                                                startDate = newValue
                                                localStartDate = newValue
                                            }
                                        }
                                }
                            }
                            .padding()
                            .background(AppColors.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    
                    // Clear All Filters Button
                    if selectedCard != nil || useDateRange {
                        Button(action: {
                            selectedCard = nil
                            useDateRange = false
                            startDate = nil
                            endDate = nil
                            // Reset to default date range (last 30 days)
                            localStartDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                            localEndDate = Date()
                        }) {
                            Text("Clear All Filters")
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.destructive)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.destructiveSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding()
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
        }
        .onAppear {
            // Sync local dates with bindings when view appears
            if let start = startDate {
                localStartDate = start
            }
            if let end = endDate {
                localEndDate = end
            }
        }
    }
}

#Preview {
    let card1 = Card(name: "Chase Sapphire Preferred", minimumSpendingAmount: 4000, hasMinimumSpending: true, rewardType: .miles)
    let card2 = Card(name: "Amex Gold", minimumSpendingAmount: 3000, hasMinimumSpending: true, rewardType: .cashback)
    
    FilterSheetView(
        cards: [card1, card2],
        selectedCard: .constant(nil),
        useDateRange: .constant(false),
        startDate: .constant(nil),
        endDate: .constant(nil)
    )
}

