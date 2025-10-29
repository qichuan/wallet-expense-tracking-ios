//
//  AddGoalView.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct AddCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var cardName = ""
    @State private var totalGoal = ""
    @State private var goalDeadline = Date() // kept internally but not user-editable; cycle uses statementDay
    @State private var rewardType = "miles"
    @State private var statementDay = 1
    
    private let rewardTypes = ["miles", "cashback"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Card Information") {
                    TextField("Card Name", text: $cardName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section("Goal Details") {
                    TextField("Total Goal Amount", text: $totalGoal)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                    
                    Picker("Reward Type", selection: $rewardType) {
                        ForEach(rewardTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Stepper(value: $statementDay, in: 1...31) {
                        Text("Statement Day (1-31): \(statementDay)")
                    }
                    Text("Your monthly spending resets each statement day. Aim to meet the minimum spend by this date for rewards.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .navigationTitle("Add Card")
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
                    .disabled(cardName.isEmpty || totalGoal.isEmpty)
                }
            }
        }
    }
    
    private func saveGoal() {
        guard let goalAmount = Decimal(string: totalGoal) else { return }
        
        let card = Card(
            name: cardName,
            totalGoal: goalAmount,
            goalDeadline: goalDeadline,
            rewardType: rewardType,
            statementDay: statementDay
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
    AddCardView()
        .modelContainer(ModelContainer.createMockContainer())
}
