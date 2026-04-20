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
    @State private var categoryToRename: SpendingCategory?

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
            .sheet(item: $categoryToRename) { cat in
                RenameCategorySheet(category: cat)
                    .presentationDetents([.medium])
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
                Menu {
                    Button("Rename") { categoryToRename = cat }
                    Button("Delete", role: .destructive) { delete(cat) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(AppTypography.iconMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func delete(_ cat: SpendingCategory) {
        guard !cat.isBuiltIn else { return }
        // Clear the category string off any transactions that referenced it (fall back to "Other").
        if let txns = try? modelContext.fetch(FetchDescriptor<Transaction>()) {
            for txn in txns where txn.category == cat.name {
                txn.category = "Other"
            }
        }
        modelContext.delete(cat)
        try? modelContext.save()
    }
}

// MARK: - Rename sheet

struct RenameCategorySheet: View {
    let category: SpendingCategory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var newName: String

    init(category: SpendingCategory) {
        self.category = category
        _newName = State(initialValue: category.name)
    }

    private var canSave: Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != category.name
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Name")
                    TextField("", text: $newName)
                        .font(AppTypography.rowTitle)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AppColors.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Rename")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldName = category.name
        category.name = trimmed
        // Propagate rename to all transactions that used the old string FK.
        if let txns = try? modelContext.fetch(FetchDescriptor<Transaction>()) {
            for txn in txns where txn.category == oldName {
                txn.category = trimmed
            }
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    CategoryManagementView()
        .modelContainer(ModelContainer.createMockContainer())
}
