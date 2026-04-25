//
//  CategoryListView.swift
//  CardPulse
//

import SwiftUI
import SwiftData

// Shared across Add and Edit sheets
private let categoryIconOptions: [String] = [
    // Food & Drink
    "fork.knife", "cup.and.saucer", "mug", "wineglass", "takeoutbag.and.cup.and.straw",
    "birthday.cake", "carrot", "fish", "popcorn", "refrigerator",
    // Shopping
    "bag", "cart", "handbag", "tag", "gift", "creditcard",
    "storefront", "building.2", "basket", "shippingbox",
    // Transport
    "car", "airplane", "tram", "bus", "bicycle", "scooter",
    "ferry", "fuelpump", "parkingsign", "car.rear",
    "airplane.departure", "train.side.front.car", "bolt.car", "figure.walk",
    // Entertainment
    "gamecontroller", "tv", "film", "ticket", "music.note",
    "headphones", "guitar", "microphone", "theatermasks", "dice",
    "sportscourt", "paintpalette", "camera", "photo",
    // Health & Fitness
    "heart", "cross", "pills", "bandage", "syringe",
    "stethoscope", "dumbbell", "figure.run", "figure.cooldown",
    "lungs", "brain.head.profile", "eye",
    // Home & Bills
    "house", "lightbulb", "drop", "bolt", "flame",
    "wrench.and.screwdriver", "hammer", "screwdriver", "sofa", "washer",
    "phone", "wifi", "tv.and.hifispeaker.fill", "shower",
    // Finance
    "dollarsign.circle", "building.columns", "chart.line.uptrend.xyaxis",
    "banknote", "percent", "arrow.left.arrow.right",
    // Education
    "book", "graduationcap", "pencil", "ruler",
    "backpack", "microscope", "globe", "magnifyingglass",
    // Personal
    "scissors", "tshirt", "shoe", "comb",
    "umbrella", "sunglasses", "figure.dress.line.vertical.figure",
    // Nature & Other
    "leaf", "tree", "pawprint", "snowflake",
    "sun.max", "moon", "cloud", "star",
    "music.mic", "theatermasks.fill", "sparkles",
]

private let categoryColorOptions: [Int] = [
    0x2E6DFF, 0xEC4899, 0xF59E0B, 0xFACC15,
    0x3B82F6, 0xA855F7, 0xEF4444, 0x14B8A6,
    0x22C55E, 0x0EA5E9, 0x8B5CF6, 0xE11D48
]

// MARK: - CategoryListView

struct CategoryListView: View {
    enum Mode {
        case management
        case onboarding(onDelete: (SpendingCategory) -> Void)
    }

    var mode: Mode

    @Query(sort: \SpendingCategory.sortOrder) private var categories: [SpendingCategory]
    @State private var showingAddSheet = false
    @State private var categoryToEdit: SpendingCategory?

    private var rowActionIcon: String {
        switch mode {
        case .management: return "pencil"
        case .onboarding: return "trash"
        }
    }

    private var rowActionIconColor: Color {
        switch mode {
        case .management: return AppColors.textSecondary
        case .onboarding: return AppColors.destructive
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Button { showingAddSheet = true } label: {
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
        .sheet(isPresented: $showingAddSheet) {
            AddCategorySheet()
                .presentationDetents([.large])
        }
        .sheet(item: $categoryToEdit) { cat in
            EditCategorySheet(category: cat)
                .presentationDetents([.large])
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
                    switch mode {
                    case .management:
                        categoryToEdit = cat
                    case .onboarding(let onDelete):
                        onDelete(cat)
                    }
                } label: {
                    Image(systemName: rowActionIcon)
                        .font(AppTypography.iconMedium)
                        .foregroundColor(rowActionIconColor)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
    @State private var iconSearch = ""

    @FocusState private var nameFocused: Bool
    @FocusState private var iconSearchFocused: Bool

    private var filteredIcons: [String] {
        guard !iconSearch.isEmpty else { return categoryIconOptions }
        return categoryIconOptions.filter { $0.localizedCaseInsensitiveContains(iconSearch) }
    }

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
                                .focused($nameFocused)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(AppColors.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        iconPickerSection(selected: $icon, search: $iconSearch, searchFocused: $iconSearchFocused)

                        colorPickerSection(selected: $colorHex)
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        nameFocused = false
                        iconSearchFocused = false
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
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
        AnalyticsTracker.log(AnalyticsTracker.Event.categoryAdded, [
            "name": trimmed,
            "icon": icon
        ])
        dismiss()
    }
}

// MARK: - Edit category sheet

struct EditCategorySheet: View {
    let category: SpendingCategory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendingCategory.sortOrder) private var allCategories: [SpendingCategory]

    @State private var name: String
    @State private var icon: String
    @State private var colorHex: Int
    @State private var iconSearch = ""
    @State private var showingDeleteAlert = false

    @FocusState private var nameFocused: Bool
    @FocusState private var iconSearchFocused: Bool

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
                                .focused($nameFocused)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(AppColors.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        iconPickerSection(selected: $icon, search: $iconSearch, searchFocused: $iconSearchFocused)

                        colorPickerSection(selected: $colorHex)

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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        nameFocused = false
                        iconSearchFocused = false
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .foregroundColor(AppColors.accent)
                    }
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

// MARK: - Shared picker subviews

@ViewBuilder
private func iconPickerSection(
    selected: Binding<String>,
    search: Binding<String>,
    searchFocused: FocusState<Bool>.Binding
) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        SectionLabel(text: "Icon")

        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
            TextField("", text: search, prompt: Text("Search icons…").foregroundColor(AppColors.textTertiary))
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textPrimary)
                .focused(searchFocused)
                .autocorrectionDisabled()
            if !search.wrappedValue.isEmpty {
                Button { search.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        let filtered = search.wrappedValue.isEmpty
            ? categoryIconOptions
            : categoryIconOptions.filter { $0.localizedCaseInsensitiveContains(search.wrappedValue) }

        if filtered.isEmpty {
            Text("No icons match \(search.wrappedValue)")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(
                    rows: Array(repeating: GridItem(.fixed(48), spacing: 10), count: 3),
                    spacing: 10
                ) {
                    ForEach(filtered, id: \.self) { symbol in
                        Button { selected.wrappedValue = symbol } label: {
                            Image(systemName: symbol)
                                .font(AppTypography.iconMedium)
                                .foregroundColor(symbol == selected.wrappedValue ? AppColors.backgroundPrimary : AppColors.textPrimary)
                                .frame(width: 48, height: 48)
                                .background(symbol == selected.wrappedValue ? AppColors.surfaceHigh : AppColors.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 48 * 3 + 10 * 2)
            .padding(.horizontal, -20)
        }
    }
}

@ViewBuilder
private func colorPickerSection(selected: Binding<Int>) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        SectionLabel(text: "Color")
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
            ForEach(categoryColorOptions, id: \.self) { hex in
                Button { selected.wrappedValue = hex } label: {
                    ZStack {
                        Circle().fill(Color(hex: UInt32(hex)))
                        if hex == selected.wrappedValue {
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
