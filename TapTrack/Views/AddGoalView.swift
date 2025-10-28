//
//  AddGoalView.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var cardName = ""
    @State private var bank = "Chase"
    @State private var last4 = ""
    @State private var totalGoal = ""
    @State private var goalDeadline = Date()
    @State private var rewardType = "miles"
    
    private let banks = ["Chase", "American Express", "Citi", "Bank of America", "Capital One", "Discover", "Other"]
    private let rewardTypes = ["miles", "cashback", "points"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Card Information") {
                    TextField("Card Name", text: $cardName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Bank", selection: $bank) {
                        ForEach(banks, id: \.self) { bank in
                            Text(bank).tag(bank)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    TextField("Last 4 Digits", text: $last4)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .onChange(of: last4) { _, newValue in
                            if newValue.count > 4 {
                                last4 = String(newValue.prefix(4))
                            }
                        }
                }
                
                Section("Goal Details") {
                    TextField("Total Goal Amount", text: $totalGoal)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                    
                    DatePicker("Goal Deadline", selection: $goalDeadline, in: Date()..., displayedComponents: .date)
                    
                    Picker("Reward Type", selection: $rewardType) {
                        ForEach(rewardTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGoal()
                    }
                    .disabled(cardName.isEmpty || bank.isEmpty || last4.count != 4 || totalGoal.isEmpty)
                }
            }
        }
    }
    
    private func saveGoal() {
        guard let goalAmount = Decimal(string: totalGoal) else { return }
        
        let card = Card(
            name: cardName,
            bank: bank,
            last4: last4,
            totalGoal: goalAmount,
            goalDeadline: goalDeadline,
            rewardType: rewardType
        )
        
        modelContext.insert(card)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving goal: \(error)")
        }
    }
}

#Preview {
    AddGoalView()
        .modelContainer(ModelContainer.createMockContainer())
}
