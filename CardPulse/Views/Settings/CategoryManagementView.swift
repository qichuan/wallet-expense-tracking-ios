//
//  CategoryManagementView.swift
//  CardPulse
//

import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendingCategory.sortOrder) private var categories: [SpendingCategory]

    @State private var showingAddSheet = false
    @State private var categoryToEdit: SpendingCategory?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
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
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        VStack(spacing: 0) {
                            ForEach(Array(categories.enumerated()), id: \.element.id) { idx, cat in
                                row(cat)
                                if idx != categories.count - 1 {
                                    Divider()
                                        .background(AppColors.divider)
                                        .padding(.leading, 54)
                                }
                            }
                        }
                        .background(AppColors.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddCategorySheet()
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $categoryToEdit) { cat in
                EditCategorySheet(category: cat)
                    .presentationDetents([.medium, .large])
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func row(_ cat: SpendingCategory) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: UInt32(cat.colorHex)).opacity(0.22))
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
                    categoryToEdit = cat
                } label: {
                    Image(systemName: "pencil")
                        .font(AppTypography.iconMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func delete(_ cat: SpendingCategory) {
        guard !cat.isBuiltIn else { return }
        let name = cat.name
        // Clear the category string off any transactions that referenced it (fall back to "Other").
        if let txns = try? modelContext.fetch(FetchDescriptor<Transaction>()) {
            for txn in txns where txn.category == cat.name {
                txn.category = "Other"
            }
        }
        modelContext.delete(cat)
        try? modelContext.save()
        AnalyticsTracker.log(AnalyticsTracker.Event.categoryDeleted, [
            "name": name,
            "source": "settings"
        ])
    }
}

// MARK: - Edit sheet

struct EditCategorySheet: View {
    let category: SpendingCategory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendingCategory.sortOrder) private var allCategories: [SpendingCategory]

    @State private var name: String
    @State private var icon: String
    @State private var colorHex: Int
    @State private var showingDeleteAlert = false

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

    init(category: SpendingCategory) {
        self.category = category
        _name = State(initialValue: category.name)
        _icon = State(initialValue: category.icon)
        _colorHex = State(initialValue: category.colorHex)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        guard !trimmedName.isEmpty else { return false }
        return trimmedName != category.name
            || icon != category.icon
            || colorHex != category.colorHex
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

                        DestructiveButton(title: "Delete Category") {
                            showingDeleteAlert = true
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Category")
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
        .alert("Delete Category", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deleteCategory() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Transactions in this category will be moved to Other. This cannot be undone.")
        }
    }

    private func save() {
        guard canSave else { return }
        let oldName = category.name
        // Don't duplicate existing names (case-insensitive), other than this category.
        if trimmedName != oldName,
           allCategories.contains(where: {
               $0.id != category.id
                   && $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
           }) {
            dismiss()
            return
        }
        category.name = trimmedName
        category.icon = icon
        category.colorHex = colorHex
        if trimmedName != oldName,
           let txns = try? modelContext.fetch(FetchDescriptor<Transaction>()) {
            for txn in txns where txn.category == oldName {
                txn.category = trimmedName
            }
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteCategory() {
        guard !category.isBuiltIn else { return }
        let name = category.name
        if let txns = try? modelContext.fetch(FetchDescriptor<Transaction>()) {
            for txn in txns where txn.category == category.name {
                txn.category = "Other"
            }
        }
        modelContext.delete(category)
        try? modelContext.save()
        AnalyticsTracker.log(AnalyticsTracker.Event.categoryDeleted, [
            "name": name,
            "source": "edit_sheet"
        ])
        dismiss()
    }
}

#Preview {
    CategoryManagementView()
        .modelContainer(ModelContainer.createMockContainer())
}
