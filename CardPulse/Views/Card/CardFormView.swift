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
    @State private var maxMilesCap: String
    @State private var maxCashbackCap: String
    @State private var foreignRewardRate: String
    @State private var draftRules: [DraftRule]
    @State private var editingRule: DraftRule?
    @State private var showingAddRule = false
    @State private var draftCurrencyRules: [DraftCurrencyRule]
    @State private var editingCurrencyRule: DraftCurrencyRule?
    @State private var showingAddCurrencyRule = false
    @State private var showingDeleteAlert = false

    @FocusState private var nameFocused: Bool
    @FocusState private var amountFocused: Bool
    @FocusState private var rateFocused: Bool
    @FocusState private var foreignRateFocused: Bool
    @FocusState private var capFocused: Bool

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
            _maxMilesCap = State(initialValue: Self.format(rate: card.maxMilesCap))
            _maxCashbackCap = State(initialValue: Self.format(rate: card.maxCashbackCap))
            _foreignRewardRate = State(initialValue: Self.format(rate: card.foreignRewardRate))
            _draftRules = State(initialValue: card.rewardRules.map {
                DraftRule(existingId: $0.id, categoryName: $0.categoryName, rate: Self.format(rate: $0.rate))
            })
            _draftCurrencyRules = State(initialValue: card.currencyRules.map {
                DraftCurrencyRule(existingId: $0.id, currencyCode: $0.currencyCode, rate: Self.format(rate: $0.rate))
            })
        } else {
            _cardName = State(initialValue: "")
            _rewardType = State(initialValue: .none)
            _hasMinimumSpending = State(initialValue: false)
            _minimumSpendingAmount = State(initialValue: "")
            _minimumSpendingByDayOfMonth = State(initialValue: 1)
            _baseRewardRate = State(initialValue: "")
            _roundingBlock = State(initialValue: 1)
            _maxMilesCap = State(initialValue: "")
            _maxCashbackCap = State(initialValue: "")
            _foreignRewardRate = State(initialValue: "")
            _draftRules = State(initialValue: [])
            _draftCurrencyRules = State(initialValue: [])
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
                        billingCycleSection
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
        .sheet(isPresented: $showingAddCurrencyRule) {
            CurrencyRuleEditor(
                rule: nil,
                rewardType: rewardType,
                existingCurrencies: draftCurrencyRules.map { $0.currencyCode },
                defaultCurrencyCode: defaultCurrencyCode
            ) { newRule in
                draftCurrencyRules.append(newRule)
            }
        }
        .sheet(item: $editingCurrencyRule) { rule in
            CurrencyRuleEditor(
                rule: rule,
                rewardType: rewardType,
                existingCurrencies: draftCurrencyRules.filter { $0.id != rule.id }.map { $0.currencyCode },
                defaultCurrencyCode: defaultCurrencyCode
            ) { updated in
                if let idx = draftCurrencyRules.firstIndex(where: { $0.id == updated.id }) {
                    draftCurrencyRules[idx] = updated
                }
            } onDelete: {
                draftCurrencyRules.removeAll { $0.id == rule.id }
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
            foreignRateRow
            FormDivider()
            currencyRateList
            FormDivider()
            roundingRow
            FormDivider()
            capRow
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
            return "Cashback is calculated as a percentage of each transaction. Add category bonuses for higher rates on specific spending. Foreign and currency rates replace the base rate for spending in those currencies."
        case .miles:
            return "Miles earn at your base rate per dollar, with each transaction rounded down to the nearest block. Add category bonuses to boost specific spending. Foreign and currency rates replace the base rate for spending in those currencies."
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
    private var foreignRateRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Foreign rate")
                    .font(AppTypography.rowTitle)
                    .foregroundColor(AppColors.textPrimary)
                Text("Spending not in \(defaultCurrencyCode)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            TextField("Base", text: $foreignRewardRate,
                      prompt: Text("Base").foregroundColor(AppColors.textTertiary))
                .keyboardType(.decimalPad)
                .focused($foreignRateFocused)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
                .onChange(of: foreignRewardRate) { _, newValue in
                    foreignRewardRate = sanitiseRate(newValue)
                }
            Text(rateUnitLabel)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

    @ViewBuilder
    private var capRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cycle cap")
                    .font(AppTypography.rowTitle)
                    .foregroundColor(AppColors.textPrimary)
                Text("Max \(rewardType == .miles ? "miles" : "cashback") per cycle")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            if rewardType == .cashback {
                Text(CurrencyUtils.symbol(for: defaultCurrencyCode))
                    .font(AppTypography.rowTitle)
                    .foregroundColor(AppColors.textSecondary)
                TextField("None", text: $maxCashbackCap,
                          prompt: Text("None").foregroundColor(AppColors.textTertiary))
                    .keyboardType(.decimalPad)
                    .focused($capFocused)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
                    .onChange(of: maxCashbackCap) { _, newValue in
                        maxCashbackCap = sanitiseRate(newValue)
                    }
            } else {
                TextField("None", text: $maxMilesCap,
                          prompt: Text("None").foregroundColor(AppColors.textTertiary))
                    .keyboardType(.decimalPad)
                    .focused($capFocused)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
                    .onChange(of: maxMilesCap) { _, newValue in
                        maxMilesCap = sanitiseRate(newValue)
                    }
                Text("miles")
                    .font(AppTypography.rowTitle)
                    .foregroundColor(AppColors.textSecondary)
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
    private var currencyRateList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Currency rates")
                    .font(AppTypography.rowTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button {
                    showingAddCurrencyRule = true
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

            if !draftCurrencyRules.isEmpty {
                ForEach(draftCurrencyRules) { rule in
                    Button {
                        editingCurrencyRule = rule
                    } label: {
                        currencyRuleRow(rule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func currencyRuleRow(_ rule: DraftCurrencyRule) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(AppTypography.iconMedium)
                .foregroundColor(AppColors.accent)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(AppColors.accent.opacity(0.15))
                )

            Text(rule.currencyCode)
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
    private var billingCycleSection: some View {
        FormSection("Billing Cycle") {
            statementDayRow

            Text("Your billing cycle resets on this day each month.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private var minimumSpendingSection: some View {
        FormSection("Minimum Spending") {
            FormToggleRow(title: "Track minimum spend", isOn: $hasMinimumSpending)

            if hasMinimumSpending {
                FormDivider()
                amountRow

                Text("Reach the minimum before your statement day to earn rewards from your card issuer.")
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
                foreignRateFocused = false
                capFocused = false
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
            editing.minimumSpendingByDayOfMonth = minimumSpendingByDayOfMonth
            if hasMinimumSpending, let parsed = Decimal(string: minimumSpendingAmount) {
                editing.minimumSpendingAmount = parsed
            }
            editing.baseRewardRate = parsedBaseRate
            editing.roundingBlock = roundingBlock
            editing.maxMilesCap = parseRate(maxMilesCap)
            editing.maxCashbackCap = parseRate(maxCashbackCap)
            editing.foreignRewardRate = parseRate(foreignRewardRate)
            reconcileRules(on: editing)
            reconcileCurrencyRules(on: editing)
            do {
                try modelContext.save()
                AnalyticsTracker.edit("card", [
                    "reward_type": String(describing: rewardType),
                    "has_min_spend": hasMinimumSpending,
                    "rule_count": editing.rewardRules.count,
                    "currency_rule_count": editing.currencyRules.count
                ])
                WidgetDataWriter.refresh(using: modelContext)
                dismiss()
            } catch { print("Error saving card: \(error)") }
        } else {
            let newMinimumSpendingAmount: Decimal = {
                if hasMinimumSpending, let parsed = Decimal(string: minimumSpendingAmount) { return parsed }
                return 0
            }()
            let stmtDay: Int = minimumSpendingByDayOfMonth
            let card = Card(
                name: cardName,
                minimumSpendingAmount: newMinimumSpendingAmount,
                hasMinimumSpending: hasMinimumSpending,
                rewardType: rewardType,
                minimumSpendingByDayOfMonth: stmtDay,
                baseRewardRate: parsedBaseRate,
                roundingBlock: roundingBlock,
                maxMilesCap: parseRate(maxMilesCap),
                maxCashbackCap: parseRate(maxCashbackCap),
                foreignRewardRate: parseRate(foreignRewardRate)
            )
            modelContext.insert(card)
            for draft in validRules() {
                let rule = CardRewardRule(card: card, categoryName: draft.categoryName, rate: parseRate(draft.rate))
                modelContext.insert(rule)
            }
            for draft in validCurrencyRules() {
                let rule = CardCurrencyRule(card: card, currencyCode: draft.currencyCode, rate: parseRate(draft.rate))
                modelContext.insert(rule)
            }
            do {
                try modelContext.save()
                AnalyticsTracker.log(AnalyticsTracker.Event.cardAdded, [
                    "reward_type": String(describing: rewardType),
                    "has_min_spend": hasMinimumSpending,
                    "statement_day": stmtDay,
                    "rule_count": card.rewardRules.count,
                    "currency_rule_count": card.currencyRules.count
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

    private func validCurrencyRules() -> [DraftCurrencyRule] {
        draftCurrencyRules.filter {
            !$0.currencyCode.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    /// Sync draft currency rules onto an existing card: update matched rules, insert
    /// new ones, delete any existing rules whose ids no longer appear in the draft.
    private func reconcileCurrencyRules(on card: Card) {
        let drafts = validCurrencyRules()
        let draftIds = Set(drafts.compactMap { $0.existingId })
        for rule in card.currencyRules where !draftIds.contains(rule.id) {
            modelContext.delete(rule)
        }
        for draft in drafts {
            if let existingId = draft.existingId,
               let rule = card.currencyRules.first(where: { $0.id == existingId }) {
                rule.currencyCode = draft.currencyCode
                rule.rate = parseRate(draft.rate)
            } else {
                let rule = CardCurrencyRule(card: card, currencyCode: draft.currencyCode, rate: parseRate(draft.rate))
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

// MARK: - Draft currency rule (local-only state until persisted)

struct DraftCurrencyRule: Identifiable, Hashable {
    let id: UUID
    let existingId: UUID?
    var currencyCode: String
    var rate: String

    init(id: UUID = UUID(), existingId: UUID? = nil, currencyCode: String, rate: String) {
        self.id = id
        self.existingId = existingId
        self.currencyCode = currencyCode
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

// MARK: - Single currency-rule editor sheet

private struct CurrencyRuleEditor: View {
    let rule: DraftCurrencyRule?
    let rewardType: RewardType
    let existingCurrencies: [String]
    let defaultCurrencyCode: String
    let onSave: (DraftCurrencyRule) -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var currencyCode: String
    @State private var rate: String
    @FocusState private var rateFocused: Bool

    init(rule: DraftCurrencyRule?,
         rewardType: RewardType,
         existingCurrencies: [String],
         defaultCurrencyCode: String,
         onSave: @escaping (DraftCurrencyRule) -> Void,
         onDelete: (() -> Void)? = nil) {
        self.rule = rule
        self.rewardType = rewardType
        self.existingCurrencies = existingCurrencies
        self.defaultCurrencyCode = defaultCurrencyCode
        self.onSave = onSave
        self.onDelete = onDelete
        let available = Self.availableCurrencyCodes(excluding: existingCurrencies, defaultCode: defaultCurrencyCode)
        _currencyCode = State(initialValue: rule?.currencyCode ?? available.first ?? "")
        _rate = State(initialValue: rule?.rate ?? "")
    }

    /// Currencies the user can pick: every known currency except the default
    /// (which the base rate covers) and ones that already have a rule.
    private static func availableCurrencyCodes(excluding existing: [String], defaultCode: String) -> [String] {
        CurrencyUtils.allAvailableCurrencies
            .map { $0.code }
            .filter { $0 != defaultCode && !existing.contains($0) }
    }

    private var pickerCodes: [String] {
        var codes = Self.availableCurrencyCodes(excluding: existingCurrencies, defaultCode: defaultCurrencyCode)
        // Keep the rule's current currency selectable when editing.
        if let current = rule?.currencyCode, !codes.contains(current) {
            codes.insert(current, at: 0)
        }
        return codes
    }

    private var rateUnitLabel: String {
        switch rewardType {
        case .cashback: return "%"
        case .miles: return "mpd"
        case .none: return ""
        }
    }

    private var isValid: Bool {
        !currencyCode.trimmingCharacters(in: .whitespaces).isEmpty
        && !rate.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        FormSection("Currency") {
                            currencyRow
                        }
                        FormSection("Rate") {
                            rateRow

                            Text("Replaces the base rate for spending in this currency.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                                .padding(.bottom, 14)
                        }
                        if rule != nil, let onDelete {
                            DestructiveButton(title: "Remove Rate") {
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
            .navigationTitle(rule == nil ? "Add Currency Rate" : "Edit Currency Rate")
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
    private var currencyRow: some View {
        HStack(spacing: 12) {
            Text("Currency")
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Menu {
                Picker("", selection: $currencyCode) {
                    ForEach(pickerCodes, id: \.self) { code in
                        Text(CurrencyUtils.info(for: code)?.displayName ?? code).tag(code)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currencyCode.isEmpty ? "Pick" : currencyCode)
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
        let updated = DraftCurrencyRule(
            id: rule?.id ?? UUID(),
            existingId: rule?.existingId,
            currencyCode: currencyCode,
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
