//
//  CategoriesStepView.swift
//  CardPulse
//

import SwiftUI
import SwiftData

struct CategoriesStepView: View {
    let totalSteps: Int
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendingCategory.sortOrder) private var categories: [SpendingCategory]

    @State private var showingAddSheet = false

    /// Soft cap that matches the design copy ("Free plan: up to 7 categories").
    /// Displayed but not enforced — built-ins count toward the total.
    private let softCap = 7

    private var customCount: Int {
        categories.filter { !$0.isBuiltIn }.count
    }

    private var totalCount: Int {
        categories.count
    }

    var body: some View {
        OnboardingScaffold(
            step: 2,
            totalSteps: totalSteps,
            title: "Add some categories",
            description: "Go ahead and add some categories to get started or use the suggested ones. You can always add or edit them later.",
            primaryTitle: "Continue",
            primaryEnabled: true,
            onBack: onBack,
            onSkip: onSkip,
            onPrimary: onContinue
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 4) {
                        Text("Free plan: up to \(softCap) categories.")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Learn more.")
                            .font(AppTypography.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Text("\(totalCount) / \(softCap) categories used.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Button {
                        showingAddSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(AppTypography.navButton)
                            Text("Add category")
                                .font(AppTypography.navButton)
                        }
                        .foregroundColor(AppColors.backgroundPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(AppColors.surfaceHigh)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if !categories.isEmpty {
                        SectionLabel(text: "Outcome categories")
                            .padding(.top, 6)

                        VStack(spacing: 0) {
                            ForEach(Array(categories.enumerated()), id: \.element.id) { idx, cat in
                                categoryRow(cat)
                                if idx != categories.count - 1 {
                                    Divider()
                                        .background(AppColors.divider)
                                        .padding(.leading, 54)
                                }
                            }
                        }
                        .background(AppColors.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddCategorySheet()
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func categoryRow(_ cat: SpendingCategory) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: UInt32(cat.colorHex)).opacity(0.22))
                Image(systemName: cat.icon)
                    .font(AppTypography.iconMedium)
                    .foregroundColor(Color(hex: UInt32(cat.colorHex)))
            }
            .frame(width: 32, height: 32)

            Text(cat.name)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            if cat.isBuiltIn {
                Text("Built-in")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            } else {
                Button {
                    delete(cat)
                } label: {
                    Image(systemName: "trash")
                        .font(AppTypography.iconMedium)
                        .foregroundColor(AppColors.destructive)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func delete(_ cat: SpendingCategory) {
        guard !cat.isBuiltIn else { return }
        modelContext.delete(cat)
        try? modelContext.save()
    }
}

// MARK: - Add category sheet

struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendingCategory.sortOrder) private var categories: [SpendingCategory]

    @State private var name = ""
    @State private var icon = "tag"
    @State private var colorHex: Int = 0x2E6DFF

    /// Curated icon pool (SF Symbols only — no custom assets).
    private let iconOptions: [String] = [
        "tag", "bag", "fork.knife", "cart", "airplane", "car",
        "tram", "house", "book", "gamecontroller", "music.note",
        "heart", "cross", "pawprint", "dumbbell", "gift",
        "cup.and.saucer", "scissors", "wrench.and.screwdriver",
        "bolt", "drop", "leaf", "globe"
    ]

    private let colorOptions: [Int] = [
        0x2E6DFF, 0xEC4899, 0xF59E0B, 0xFACC15,
        0x3B82F6, 0xA855F7, 0xEF4444, 0x14B8A6,
        0x22C55E, 0x0EA5E9, 0x8B5CF6, 0xE11D48
    ]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(text: "Name")
                            TextField("", text: $name, prompt: Text("Groceries").foregroundColor(AppColors.textTertiary))
                                .font(AppTypography.rowTitle)
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(AppColors.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "Icon")
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                                ForEach(iconOptions, id: \.self) { symbol in
                                    Button { icon = symbol } label: {
                                        Image(systemName: symbol)
                                            .font(AppTypography.iconMedium)
                                            .foregroundColor(symbol == icon ? AppColors.backgroundPrimary : AppColors.textPrimary)
                                            .frame(width: 44, height: 44)
                                            .background(symbol == icon ? AppColors.surfaceHigh : AppColors.backgroundCard)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "Color")
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                                ForEach(colorOptions, id: \.self) { hex in
                                    Button { colorHex = hex } label: {
                                        ZStack {
                                            Circle().fill(Color(hex: UInt32(hex)))
                                            if hex == colorHex {
                                                Image(systemName: "checkmark")
                                                    .font(AppTypography.iconMedium)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .frame(width: 40, height: 40)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .foregroundColor(canSave ? AppColors.accent : AppColors.textTertiary)
                        .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Don't duplicate existing names (case-insensitive)
        if categories.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            dismiss()
            return
        }
        let nextOrder = (categories.map { $0.sortOrder }.max() ?? -1) + 1
        let category = SpendingCategory(
            name: trimmed,
            icon: icon,
            colorHex: colorHex,
            isBuiltIn: false,
            sortOrder: nextOrder
        )
        modelContext.insert(category)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    CategoriesStepView(
        totalSteps: 4,
        onBack: {},
        onContinue: {},
        onSkip: {}
    )
    .modelContainer(ModelContainer.createMockContainer())
}
