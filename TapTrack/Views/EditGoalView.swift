//
//  EditGoalView.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct EditGoalView: View {
    let card: Card
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var totalGoal: String
    @State private var goalDeadline: Date
    @State private var rewardType: String
    @State private var showingDeleteAlert = false
    
    private let rewardTypes = ["miles", "cashback", "points"]
    
    init(card: Card) {
        self.card = card
        self._totalGoal = State(initialValue: String(format: "%.0f", Double(truncating: card.totalGoal as NSDecimalNumber)))
        self._goalDeadline = State(initialValue: card.goalDeadline)
        self._rewardType = State(initialValue: card.rewardType)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Card Information") {
                    HStack {
                        Text("Card Name")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(card.name)
                            .foregroundColor(.secondary)
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
                
                Section("Progress") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Current Progress")
                                .font(.headline)
                            Spacer()
                            Text("$\(Double(truncating: card.currentSpent as NSDecimalNumber), specifier: "%.0f") / $\(Double(truncating: card.totalGoal as NSDecimalNumber), specifier: "%.0f")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: card.progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: .teal))
                            .frame(height: 8)
                        
                        Text("\(Int(card.progressPercentage * 100))% Complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Delete Goal") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Edit Goal")
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
                    .disabled(totalGoal.isEmpty)
                }
            }
        }
        .alert("Delete Goal", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteGoal()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this goal? This action cannot be undone.")
        }
    }
    
    private func saveGoal() {
        guard let goalAmount = Decimal(string: totalGoal) else { return }
        
        card.totalGoal = goalAmount
        card.goalDeadline = goalDeadline
        card.rewardType = rewardType
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving goal: \(error)")
        }
    }
    
    private func deleteGoal() {
        modelContext.delete(card)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error deleting goal: \(error)")
        }
    }
}

#Preview {
    let card = Card(
        name: "Chase Sapphire Preferred",
        totalGoal: 4000,
        goalDeadline: Calendar.current.date(byAdding: .day, value: 25, to: Date()) ?? Date(),
        rewardType: "miles",
        currentSpent: 1500
    )
    
    return EditGoalView(card: card)
        .modelContainer(ModelContainer.createMockContainer())
}
