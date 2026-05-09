//
//  CardFormView.swift
//  CardPulse
//
//  Created by Assistant on 31/10/25.
//

import SwiftUI
import SwiftData

struct CardFormView: View {
    let cardToEdit: Card?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SpendingCategory.sortOrder) private var categoryRecords: [SpendingCategory]

    @State private var cardName: String
    @State private var rewardType: RewardType
    @State private var hasMinimumSpending: Bool
    @State private var minimumSpendingAmount: String
    @State private var minimumSpendingByDayOfMonth: Int
    @State private var baseRewardRate: String
    @State private var roundingBlock: Decimal
    @State private var draftRules: [DraftRule]
    @State private var editingRule: DraftRule?
    @State private var showingAddRule = false
    @State private var showingDeleteAlert = false

    @FocusState private var nameFocused: Bool
    @FocusState private var amountFocused: Bool
    @FocusState private var rateFocused: Bool

    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"

    init(card: Card? = nil) {
        self.cardToEdit = card
        if let card {
            _cardName = State(initialValue: card.name)
            _rewardType = State(initialValue: card.rewardType)
            _hasMinimumSpending = State(initialValue: card.hasMinimumSpending)
            _minimumSpendingAmount = State(initialValue: String(format: "%.0f", Double(truncating: card.minimumSpendingAmount as NSDecimalNumber)))
            _minimumSpendingByDayOfMonth = State(initialValue: card.minimumSpendingByDayOfMonth)
            _baseRewardRate = State(initialValue: Self.format(rate: card.baseRewardRate))
            _roundingBlock = State(initialValue: card.roundingBlock)
            _draftRules = State(initialValue: card.rewardRules.map {
                DraftRule(existingId: $0.id, categoryName: $0.categoryName, rate: Self.format(rate: $0.rate))
            })
        } else {
            _cardName = State(initialValue: "")
            _rewardType = State(initialValue: .none)
            _hasMinimumSpending = State(initialValue: false)
            _minimumSpendingAmount = State(initialValue: "")
            _minimumSpendingByDayOfMonth = State(initialValue: 1)
            _baseRewardRate = State(initialValue: "")
            _roundingBlock = State(initialValue: 1)
            _draftRules = State(initialValue: [])
        }
    }

    private var isValid: Bool {
        !cardName.trimmingCharacters(in: .whitespaces).isEmpty
        && !(hasMinimumSpending && minimumSpendingAmount.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        detailsSection
                        rewardSection
                        if rewardType != .none {
                            rewardRulesSection
                        }
                        minimumSpendingSection

                        if cardToEdit != nil {
                            DestructiveButton(title: "Delete Card") {
                                showingDeleteAlert = true
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(cardToEdit == nil ? "Add Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onAppear {
                if cardToEdit == nil {
                    nameFocused = true
                }
            }
            .onChange(of: rewardType) { _, newValue in
                // When the user picks a reward type for the first time, default the
                // rounding block sensibly: $5 for miles, $1 (no rounding) for cashback.
                if newValue == .miles, roundingBlock == 1, baseRewardRate.isEmpty {
                    roundingBlock = 5
                }
                if newValue == .cashback, roundingBlock == 5, baseRewardRate.isEmpty {
                    roundingBlock = 1
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Delete Card", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deleteCard() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this card? This action cannot be undone.")
        }
        .sheet(isPresented: $showingAddRule) {
            RewardRuleEditor(
                rule: nil,
                rewardType: rewardType,
                existingCategories: draftRules.map { $0.categoryName },
                availableCategories: categoryRecords.map { $0.name }
            ) { newRule in
                draftRules.append(newRule)
            }
        }
        .sheet(item: $editingRule) { rule in
            RewardRuleEditor(
                rule: rule,
                rewardType: rewardType,
                existingCategories: draftRules.filter { $0.id != rule.id }.map { $0.categoryName },
                availableCategories: categoryRecords.map { $0.name }
            ) { updated in
                if let idx = draftRules.firstIndex(where: { $0.id == updated.id }) {
                    draftRules[idx] = updated
                }
            } onDelete: {
                draftRules.removeAll { $0.id == rule.id }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var detailsSection: some View {
        FormSection("Card Details") {
            FormTextFieldRow(
                title: "Name",
                placeholder: "DBS Altitude Visa",
                text: $cardName,
                isFocused: $nameFocused
            )
        }
    }

    @ViewBuilder
    private var rewardSection: some View {
        FormSection("Reward Type") {
            rewardSelector
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
        }
    }

    @ViewBuilder
    private var rewardSelector: some View {
        HStack(spacing: 8) {
            ForEach(RewardType.allCases, id: \.self) { type in
                rewardButton(type)
            }
        }
    }

    @ViewBuilder
    private func rewardButton(_ type: RewardType) -> some View {
        let isSelected = rewardType == type
        Button {
            rewardType = type
        } label: {
            Text(title(for: type))
                .font(AppTypography.filterChip)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? color(for: type) : AppColors.backgroundCardSoft)
                )
        }
        .buttonStyle(.plain)
    }

    private func title(for type: RewardType) -> String {
        switch type {
        case .miles: return "Miles"
        case .cashback: return "Cash"
        case .none: return "None"
        }
    }

    private func color(for type: RewardType) -> Color {
        switch type {
        case .miles: return AppColors.rewardMiles
        case .cashback: return AppColors.rewardCash
        case .none: return AppColors.accent
        }
    }

    // MARK: - Reward rules

    @ViewBuilder
    private var rewardRulesSection: some View {
        FormSection("Rewards Rules") {
            baseRateRow
            FormDivider()
            roundingRow
            FormDivider()
            categoryBonusList

            Text(rewardsHelpText)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 14)
        }
    }

    private var rewardsHelpText: String {
        switch rewardType {
        case .cashback:
            return "Cashback is calculated as a percentage of each transaction. Add category bonuses for higher rates on specific spending."
        case .miles:
            return "Miles earn at your base rate per dollar, with each transaction rounded down to the nearest block. Add category bonuses to boost specific spending."
        case .none:
            return ""
        }
    }

    @ViewBuilder
    private var baseRateRow: some View {
        HStack(spacing: 12) {
            Text("Base rate")
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            TextField("0", text: $baseRewardRate, prompt: Text("0").foregroundColor(AppColors.textTertiary))
                .keyboardType(.decimalPad)
                .focused($rateFocused)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
                .onChange(of: baseRewardRate) { _, newValue in
                    baseRewardRate = sanitiseRate(newValue)
                }
            Text(rateUnitLabel)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var rateUnitLabel: String {
        switch rewardType {
        case .cashback: return "%"
        case .miles: return "mpd"
        case .none: return ""
        }
    }

    @ViewBuilder
    private var roundingRow: some View {
        HStack(spacing: 12) {
            Text("Round amount")
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            HStack(spacing: 6) {
                ForEach([Decimal(1), Decimal(5)], id: \.self) { block in
                    let isSelected = roundingBlock == block
                    Button {
                        roundingBlock = block
                    } label: {
                        Text(block == 1 ? "$1" : "$\(formatBlock(block))")
                            .font(AppTypography.filterChip)
                            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? AppColors.accent : AppColors.backgroundCardSoft)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func formatBlock(_ block: Decimal) -> String {
        let n = Double(truncating: block as NSDecimalNumber)
        return String(format: "%.0f", n)
    }

    @ViewBuilder
    private var categoryBonusList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Category bonuses")
                    .font(AppTypography.rowTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button {
                    showingAddRule = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(AppTypography.chevronTinyBold)
                        Text("Add")
                            .font(AppTypography.bannerCTA)
                    }
                    .foregroundColor(AppColors.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !draftRules.isEmpty {
                ForEach(draftRules) { rule in
                    Button {
                        editingRule = rule
                    } label: {
                        ruleRow(rule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func ruleRow(_ rule: DraftRule) -> some View {
        HStack(spacing: 12) {
            Image(systemName: MerchantUtils.icon(for: rule.categoryName, in: categoryRecords))
                .font(AppTypography.iconMedium)
                .foregroundColor(MerchantUtils.color(for: rule.categoryName, in: categoryRecords))
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(MerchantUtils.color(for: rule.categoryName, in: categoryRecords).opacity(0.15))
                )

            Text(rule.categoryName)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text("\(rule.rate.isEmpty ? "0" : rule.rate)\(rateUnitLabel)")
                .font(AppTypography.rowValue)
                .foregroundColor(AppColors.textSecondary)

            Image(systemName: "chevron.right")
                .font(AppTypography.chevronTiny)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Minimum spending

    @ViewBuilder
    private var minimumSpendingSection: some View {
        FormSection("Minimum Spending") {
            FormToggleRow(title: "Track minimum spend", isOn: $hasMinimumSpending)

            if hasMinimumSpending {
                FormDivider()
                amountRow
                FormDivider()
                statementDayRow

                Text("Your minimum spending resets on this day each month. Reach the minimum before then to earn rewards from your card issuer.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private var amountRow: some View {
        HStack(spacing: 12) {
            Text("Target")
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(CurrencyUtils.symbol(for: defaultCurrencyCode))
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textSecondary)
            TextField("0", text: $minimumSpendingAmount, prompt: Text("0").foregroundColor(AppColors.textTertiary))
                .keyboardType(.numberPad)
                .focused($amountFocused)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
                .onChange(of: minimumSpendingAmount) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue { minimumSpendingAmount = filtered }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var statementDayRow: some View {
        HStack(spacing: 12) {
            Text("Statement day")
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Menu {
                Picker("", selection: $minimumSpendingByDayOfMonth) {
                    ForEach(1...31, id: \.self) { day in
                        Text("Day \(day)").tag(day)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Day \(minimumSpendingByDayOfMonth)")
                        .foregroundColor(AppColors.accent)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppTypography.chevronTiny)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
                .foregroundColor(AppColors.textSecondary)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") { saveCard() }
                .font(AppTypography.navButton)
                .foregroundColor(isValid ? AppColors.accent : AppColors.textTertiary)
                .disabled(!isValid)
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button {
                nameFocused = false
                amountFocused = false
                rateFocused = false
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .foregroundColor(AppColors.accent)
            }
        }
    }

    // MARK: - Helpers

    private static func format(rate: Decimal) -> String {
        if rate == 0 { return "" }
        let n = Double(truncating: rate as NSDecimalNumber)
        // Show up to 4 decimal places, trim trailing zeroes for a clean display.
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 4
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: n)) ?? ""
    }

    private func sanitiseRate(_ raw: String) -> String {
        // Allow digits and at most one decimal separator. Strip everything else.
        var seenDot = false
        var result = ""
        for ch in raw {
            if ch.isNumber {
                result.append(ch)
            } else if ch == "." && !seenDot {
                result.append(ch)
                seenDot = true
            }
        }
        return result
    }

    private func parseRate(_ raw: String) -> Decimal {
        guard !raw.isEmpty else { return 0 }
        return Decimal(string: raw) ?? 0
    }

    // MARK: - Actions

    private func saveCard() {
        let parsedBaseRate = parseRate(baseRewardRate)

        if let editing = cardToEdit {
            editing.name = cardName
            editing.rewardType = rewardType
            editing.hasMinimumSpending = hasMinimumSpending
            if hasMinimumSpending, let parsed = Decimal(string: minimumSpendingAmount) {
                editing.minimumSpendingAmount = parsed
                editing.minimumSpendingByDayOfMonth = minimumSpendingByDayOfMonth
            }
            editing.baseRewardRate = parsedBaseRate
            editing.roundingBlock = roundingBlock
            reconcileRules(on: editing)
            do {
                try modelContext.save()
                AnalyticsTracker.edit("card", [
                    "reward_type": String(describing: rewardType),
                    "has_min_spend": hasMinimumSpending,
                    "rule_count": editing.rewardRules.count
                ])
                WidgetDataWriter.refresh(using: modelContext)
                dismiss()
            } catch { print("Error saving card: \(error)") }
        } else {
            let newMinimumSpendingAmount: Decimal = {
                if hasMinimumSpending, let parsed = Decimal(string: minimumSpendingAmount) { return parsed }
                return 0
            }()
            let stmtDay: Int = hasMinimumSpending ? minimumSpendingByDayOfMonth : 1
            let card = Card(
                name: cardName,
                minimumSpendingAmount: newMinimumSpendingAmount,
                hasMinimumSpending: hasMinimumSpending,
                rewardType: rewardType,
                minimumSpendingByDayOfMonth: stmtDay,
                baseRewardRate: parsedBaseRate,
                roundingBlock: roundingBlock
            )
            modelContext.insert(card)
            for draft in validRules() {
                let rule = CardRewardRule(card: card, categoryName: draft.categoryName, rate: parseRate(draft.rate))
                modelContext.insert(rule)
            }
            do {
                try modelContext.save()
                AnalyticsTracker.log(AnalyticsTracker.Event.cardAdded, [
                    "reward_type": String(describing: rewardType),
                    "has_min_spend": hasMinimumSpending,
                    "statement_day": stmtDay,
                    "rule_count": card.rewardRules.count
                ])
                WidgetDataWriter.refresh(using: modelContext)
                dismiss()
            } catch { print("Error saving card: \(error)") }
        }
    }

    private func validRules() -> [DraftRule] {
        draftRules.filter {
            !$0.categoryName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    /// Sync draft rules onto an existing card: update matched rules, insert new ones,
    /// delete any existing rules whose ids no longer appear in the draft.
    private func reconcileRules(on card: Card) {
        let drafts = validRules()
        let draftIds = Set(drafts.compactMap { $0.existingId })
        // Delete removed rules
        for rule in card.rewardRules where !draftIds.contains(rule.id) {
            modelContext.delete(rule)
        }
        // Update or insert
        for draft in drafts {
            if let existingId = draft.existingId,
               let rule = card.rewardRules.first(where: { $0.id == existingId }) {
                rule.categoryName = draft.categoryName
                rule.rate = parseRate(draft.rate)
            } else {
                let rule = CardRewardRule(card: card, categoryName: draft.categoryName, rate: parseRate(draft.rate))
                modelContext.insert(rule)
            }
        }
    }

    private func deleteCard() {
        guard let editing = cardToEdit else { return }
        let rewardTypeString = String(describing: editing.rewardType)
        for transaction in editing.transactions {
            transaction.card = nil
        }
        modelContext.delete(editing)
        do {
            try modelContext.save()
            AnalyticsTracker.log(AnalyticsTracker.Event.cardDeleted, [
                "reward_type": rewardTypeString
            ])
            WidgetDataWriter.refresh(using: modelContext)
            dismiss()
        } catch { print("Error deleting card: \(error)") }
    }
}

// MARK: - Draft rule (local-only state until persisted)

struct DraftRule: Identifiable, Hashable {
    let id: UUID
    let existingId: UUID?
    var categoryName: String
    var rate: String

    init(id: UUID = UUID(), existingId: UUID? = nil, categoryName: String, rate: String) {
        self.id = id
        self.existingId = existingId
        self.categoryName = categoryName
        self.rate = rate
    }
}

// MARK: - Single-rule editor sheet

private struct RewardRuleEditor: View {
    let rule: DraftRule?
    let rewardType: RewardType
    let existingCategories: [String]
    let availableCategories: [String]
    let onSave: (DraftRule) -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var categoryName: String
    @State private var rate: String
    @FocusState private var rateFocused: Bool

    init(rule: DraftRule?,
         rewardType: RewardType,
         existingCategories: [String],
         availableCategories: [String],
         onSave: @escaping (DraftRule) -> Void,
         onDelete: (() -> Void)? = nil) {
        self.rule = rule
        self.rewardType = rewardType
        self.existingCategories = existingCategories
        self.availableCategories = availableCategories
        self.onSave = onSave
        self.onDelete = onDelete
        _categoryName = State(initialValue: rule?.categoryName ?? availableCategories.first(where: { !existingCategories.contains($0) }) ?? "")
        _rate = State(initialValue: rule?.rate ?? "")
    }

    private var rateUnitLabel: String {
        switch rewardType {
        case .cashback: return "%"
        case .miles: return "mpd"
        case .none: return ""
        }
    }

    private var isValid: Bool {
        !categoryName.trimmingCharacters(in: .whitespaces).isEmpty
        && !rate.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        FormSection("Category") {
                            categoryRow
                        }
                        FormSection("Bonus Rate") {
                            rateRow
                        }
                        if rule != nil, let onDelete {
                            DestructiveButton(title: "Remove Bonus") {
                                onDelete()
                                dismiss()
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(rule == nil ? "Add Bonus" : "Edit Bonus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .font(AppTypography.navButton)
                        .foregroundColor(isValid ? AppColors.accent : AppColors.textTertiary)
                        .disabled(!isValid)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var categoryRow: some View {
        HStack(spacing: 12) {
            Text("Category")
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Menu {
                Picker("", selection: $categoryName) {
                    ForEach(availableCategories, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(categoryName.isEmpty ? "Pick" : categoryName)
                        .foregroundColor(AppColors.accent)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppTypography.chevronTiny)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var rateRow: some View {
        HStack(spacing: 12) {
            Text("Rate")
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            TextField("0", text: $rate, prompt: Text("0").foregroundColor(AppColors.textTertiary))
                .keyboardType(.decimalPad)
                .focused($rateFocused)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
                .onChange(of: rate) { _, newValue in
                    rate = sanitise(newValue)
                }
            Text(rateUnitLabel)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear { rateFocused = rule == nil }
    }

    private func sanitise(_ raw: String) -> String {
        var seenDot = false
        var result = ""
        for ch in raw {
            if ch.isNumber {
                result.append(ch)
            } else if ch == "." && !seenDot {
                result.append(ch)
                seenDot = true
            }
        }
        return result
    }

    private func save() {
        let updated = DraftRule(
            id: rule?.id ?? UUID(),
            existingId: rule?.existingId,
            categoryName: categoryName,
            rate: rate
        )
        onSave(updated)
        dismiss()
    }
}

#Preview {
    CardFormView()
        .modelContainer(ModelContainer.createMockContainer())
}
