//
//  TransactionFormView.swift
//  CardPulse
//
//  Created by Assistant on 31/10/25.
//

import SwiftUI
import SwiftData
import MapKit

struct TransactionFormView: View {
    let transactionToEdit: Transaction?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var cards: [Card]
    @Query(sort: \SpendingCategory.sortOrder) private var categoryRecords: [SpendingCategory]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"
    @AppStorage("enabledCurrencies") private var enabledCurrenciesRaw = "SGD,MYR,HKD,USD,EUR"
    @AppStorage("customCurrenciesRaw") private var customCurrenciesRaw = ""
    /// Mirrors the user-defined card order persisted by `CardsView`. Cards
    /// not present in the saved list keep their `@Query` relative order at
    /// the end.
    @AppStorage("cardOrder") private var cardOrderRaw: String = "[]"

    @State private var merchant: String
    @State private var amount: String
    @State private var currency: String
    @State private var selectedCard: Card?
    @State private var category: String
    @State private var note: String
    @State private var transactionDate: Date
    @State private var isRecurring: Bool
    @State private var showingDeleteAlert = false
    /// Guards against re-entrant saves. A new-transaction save waits asynchronously for a
    /// location fix before persisting; without this a second Save tap would insert a duplicate.
    @State private var isSaving = false

    /// The location text the user typed/selected. Persisted as the transaction's `placeName`.
    @State private var locationQuery: String
    /// Coordinate resolved from a picked autocomplete suggestion. Cleared when the user edits
    /// the text manually, so a stored coordinate never disagrees with the place name.
    @State private var locationLatitude: Double?
    @State private var locationLongitude: Double?
    /// The exact text last written programmatically from a suggestion selection. Lets the
    /// `locationQuery` `onChange` tell a real edit (which invalidates the coordinate) apart
    /// from the field updating itself after a pick.
    @State private var appliedLocationText: String?
    @StateObject private var locationSearch = LocationSearchCompleter()

    /// True once the user picks a category from the menu themselves. A manual
    /// choice is never overwritten by a guess.
    @State private var categoryWasEdited = false
    @State private var isGuessingCategory = false
    /// Which tier produced the current category, or nil when the user picked it
    /// themselves. Not surfaced in the UI — the guess fills in silently; this
    /// only feeds `category_source` and the override event.
    @State private var categoryGuessSource: CategoryInference.Source?
    /// Lowercased merchant the cascade last ran for, so focusing and blurring an
    /// unchanged field doesn't re-hit the network.
    @State private var lastGuessedMerchant: String?
    @State private var guessTask: Task<Void, Never>?

    @FocusState private var merchantFocused: Bool
    @FocusState private var amountFocused: Bool
    @FocusState private var noteFocused: Bool
    @FocusState private var locationFocused: Bool

    /// Cards sorted by the user's saved order from `CardsView`.
    private var orderedCards: [Card] {
        let order: [UUID] = {
            guard let data = cardOrderRaw.data(using: .utf8),
                  let strings = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return strings.compactMap { UUID(uuidString: $0) }
        }()
        let indexByID: [UUID: Int] = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return cards.sorted { lhs, rhs in
            switch (indexByID[lhs.id], indexByID[rhs.id]) {
            case let (l?, r?): return l < r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return false
            }
        }
    }

    private var enabledCurrencies: [CurrencyInfo] {
        let enabled = CurrencyUtils.enabledCurrencies(fromRaw: enabledCurrenciesRaw, customRaw: customCurrenciesRaw)
        if !currency.isEmpty, !enabled.contains(where: { $0.code == currency }),
           let info = CurrencyUtils.info(for: currency) {
            return [info] + enabled
        }
        return enabled
    }

    /// Names shown in the category picker.
    /// Uses the @Query'd `SpendingCategory` list (falling back to `MerchantUtils.defaultCategories`
    /// before the store has been seeded). If the currently-selected category is not in the
    /// list (orphan — e.g. legacy "Dining Out" or a user-deleted custom), it's prepended so
    /// the Picker can still render it.
    private var categoryNames: [String] {
        let stored = categoryRecords.map { $0.name }
        let base = stored.isEmpty ? MerchantUtils.defaultCategories : stored
        if !category.isEmpty,
           !base.contains(where: { $0.caseInsensitiveCompare(category) == .orderedSame }) {
            return [category] + base
        }
        return base
    }

    init(transaction: Transaction? = nil) {
        self.transactionToEdit = transaction
        if let transaction {
            _merchant = State(initialValue: transaction.merchant)
            _amount = State(initialValue: String(format: "%.2f", Double(truncating: transaction.amount as NSDecimalNumber)))
            _currency = State(initialValue: transaction.currency)
            _selectedCard = State(initialValue: transaction.card)
            _category = State(initialValue: transaction.category ?? "Other")
            _note = State(initialValue: transaction.note ?? "")
            _transactionDate = State(initialValue: transaction.date)
            _isRecurring = State(initialValue: transaction.isRecurring)
            let existingPlace = transaction.placeName ?? ""
            _locationQuery = State(initialValue: existingPlace)
            _locationLatitude = State(initialValue: transaction.latitude)
            _locationLongitude = State(initialValue: transaction.longitude)
            _appliedLocationText = State(initialValue: existingPlace.isEmpty ? nil : existingPlace)
        } else {
            _merchant = State(initialValue: "")
            _amount = State(initialValue: "")
            _currency = State(initialValue: "")
            _selectedCard = State(initialValue: nil)
            _category = State(initialValue: "Other")
            _note = State(initialValue: "")
            _transactionDate = State(initialValue: Date())
            _isRecurring = State(initialValue: false)
            _locationQuery = State(initialValue: "")
            _locationLatitude = State(initialValue: nil)
            _locationLongitude = State(initialValue: nil)
            _appliedLocationText = State(initialValue: nil)
        }
    }

    private var isValid: Bool {
        !merchant.trimmingCharacters(in: .whitespaces).isEmpty
        && !amount.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Merchant autocomplete

    private struct MerchantSuggestion: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let category: String?
    }

    /// Distinct past merchants in most-recent-first order. Each entry carries
    /// the category from its most recent appearance, so picking a merchant can
    /// auto-fill the category. Dedup is case-insensitive on the trimmed name.
    private var distinctMerchants: [MerchantSuggestion] {
        var seen = Set<String>()
        var ordered: [MerchantSuggestion] = []
        for tx in allTransactions {
            let trimmed = tx.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if !seen.insert(key).inserted { continue }
            ordered.append(MerchantSuggestion(name: trimmed, category: tx.category))
        }
        return ordered
    }

    /// Up to 5 matches for the current merchant input. Suggestions appear
    /// only when adding (not editing) and the user has typed at least 3
    /// characters. An exact match is filtered out — there's nothing to
    /// suggest if the user has already typed the full name.
    private var merchantSuggestions: [MerchantSuggestion] {
        guard transactionToEdit == nil, merchantFocused else { return [] }
        let query = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.count >= 3 else { return [] }
        let matches = distinctMerchants.filter {
            let n = $0.name.lowercased()
            return n.contains(query) && n != query
        }
        return Array(matches.prefix(5))
    }

    private func applyMerchantSuggestion(_ s: MerchantSuggestion) {
        let queryLength = merchant.trimmingCharacters(in: .whitespacesAndNewlines).count
        let suggestionRank = merchantSuggestions.firstIndex(of: s) ?? -1
        let suggestionCount = merchantSuggestions.count
        let categoryAutoFilled = (s.category?.isEmpty == false)

        merchant = s.name
        if let cat = s.category, !cat.isEmpty {
            category = cat
            categoryGuessSource = .history
        }
        // The suggestion already carries the merchant's own category, so the
        // blur that follows has nothing left to work out.
        lastGuessedMerchant = s.name.lowercased()
        merchantFocused = false

        AnalyticsTracker.log(AnalyticsTracker.Event.merchantSuggestionSelected, [
            "query_length": queryLength,
            "suggestion_rank": suggestionRank,
            "suggestion_count": suggestionCount,
            "category_auto_filled": categoryAutoFilled,
            "suggested_merchant": merchant,
            "suggested_category": s.category ?? "n/a"
        ])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        merchantSection
                        amountSection
                        detailsSection
                        locationSection
                        recurringSection
                        noteSection

                        if transactionToEdit != nil {
                            DestructiveButton(title: "Delete Transaction") {
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
            .navigationTitle(transactionToEdit == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onChange(of: merchantFocused) { _, focused in
                if !focused { guessCategoryIfNeeded() }
            }
            .onAppear {
                if transactionToEdit == nil {
                    merchantFocused = true
                    // Ask for location the first time the user adds a transaction, so we can
                    // record where it was made. No-op once a decision has been made.
                    LocationManager.shared.requestPermission()
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deleteTransaction() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var merchantSection: some View {
        FormSection("Merchant") {
            FormTextFieldRow(
                title: "Name",
                placeholder: "Apple Store",
                text: $merchant,
                isFocused: $merchantFocused
            )
            if !merchantSuggestions.isEmpty {
                FormDivider()
                ForEach(merchantSuggestions) { suggestion in
                    Button {
                        applyMerchantSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(AppTypography.rowMeta)
                                .foregroundColor(AppColors.textSecondary)
                            Text(suggestion.name)
                                .font(AppTypography.rowTitle)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if let cat = suggestion.category, !cat.isEmpty {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(MerchantUtils.color(for: cat, in: categoryRecords))
                                        .frame(width: 6, height: 6)
                                    Text(cat)
                                        .font(AppTypography.rowMeta)
                                        .foregroundColor(AppColors.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if suggestion != merchantSuggestions.last {
                        FormDivider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var amountSection: some View {
        FormSection("Amount") {
            HStack(spacing: 12) {
                Text(CurrencyUtils.symbol(for: currency.isEmpty ? defaultCurrencyCode : currency))
                    .font(AppTypography.amount)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(minWidth: 36, alignment: .leading)

                TextField("", text: $amount, prompt: Text("0.00").foregroundColor(AppColors.textTertiary))
                    .font(AppTypography.amount)
                    .foregroundColor(AppColors.textPrimary)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .onChange(of: amount) { _, newValue in
                        let formatted = formatAmountInput(newValue)
                        if formatted != newValue { amount = formatted }
                    }

                Menu {
                    Picker("", selection: $currency) {
                        Text("Default (\(defaultCurrencyCode))").tag("")
                        ForEach(enabledCurrencies) { info in
                            Text("\(info.name) (\(info.code))").tag(info.code)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(currency.isEmpty ? defaultCurrencyCode : currency)
                            .font(AppTypography.pillBold)
                        Image(systemName: "chevron.down")
                            .font(AppTypography.chevronTinyBold)
                    }
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppColors.accentSoft)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        FormSection("Details") {
            categoryRow
            FormDivider()

            FormDateRow(title: "Date", date: $transactionDate)
            FormDivider()

            cardRow
        }
    }

    @ViewBuilder
    private var cardRow: some View {
        HStack(spacing: 12) {
            Text("Card")
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            // Button-based items (instead of `Picker`) avoid the ~1s
            // selection-binding delay that `Picker` introduces inside `Menu`.
            Menu {
                Button {
                    selectedCard = nil
                } label: {
                    if selectedCard == nil {
                        Label("None", systemImage: "checkmark")
                    } else {
                        Text("None")
                    }
                }
                ForEach(orderedCards) { card in
                    Button {
                        selectedCard = card
                    } label: {
                        if selectedCard?.id == card.id {
                            Label(card.name, systemImage: "checkmark")
                        } else {
                            Text(card.name)
                        }
                    }
                }
            } label: {
                ZStack {
                    ForEach(orderedCards, id: \.self) { card in
                        HStack {
                            Text(card.name)
                            Image(systemName: "chevron.up.chevron.down")
                        }
                    }
                }
                .hidden()
                .overlay(alignment: .trailing) {
                    HStack(spacing: 4) {
                        Text(selectedCard?.name ?? "None")
                            .foregroundColor(AppColors.accent)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(AppTypography.chevronTiny)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var categoryRow: some View {
        HStack(spacing: 12) {
            Text("Category")
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            if isGuessingCategory {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppColors.accent)
                    Text("Guessing…")
                        .font(AppTypography.rowValue)
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                categoryMenu
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.2), value: isGuessingCategory)
    }

    @ViewBuilder
    private var categoryMenu: some View {
        Menu {
            ForEach(categoryNames, id: \.self) { cat in
                Button {
                    selectCategory(cat)
                } label: {
                    Label(cat, systemImage: MerchantUtils.icon(for: cat, in: categoryRecords))
                }
            }
        } label: {
            ZStack {
                ForEach(categoryNames, id: \.self) { cat in
                    HStack(spacing: 6) {
                        Image(systemName: MerchantUtils.icon(for: category, in: categoryRecords))
                            .font(AppTypography.rowMeta)
                            .foregroundColor(MerchantUtils.color(for: category, in: categoryRecords))
                        Text(cat)
                            .foregroundColor(AppColors.accent)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(AppTypography.chevronTiny)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .hidden()
            .overlay(alignment: .trailing) {
                HStack(spacing: 6) {
                    Image(systemName: MerchantUtils.icon(for: category, in: categoryRecords))
                        .font(AppTypography.rowMeta)
                        .foregroundColor(MerchantUtils.color(for: category, in: categoryRecords))
                    Text(category)
                        .foregroundColor(AppColors.accent)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppTypography.chevronTiny)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    /// A hand-picked category is final: it locks out every later guess,
    /// including the one an in-flight request is about to apply.
    private func selectCategory(_ cat: String) {
        if let overridden = categoryGuessSource, cat != category {
            AnalyticsTracker.log(AnalyticsTracker.Event.categoryGuessOverridden, [
                "source": overridden.rawValue,
                "guessed_category": category,
                "chosen_category": cat
            ])
        }
        category = cat
        categoryWasEdited = true
        categoryGuessSource = nil
    }

    @ViewBuilder
    private var locationSection: some View {
        FormSection("Location") {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(AppTypography.iconMedium)
                    .foregroundColor(locationLatitude != nil ? AppColors.accent : AppColors.textTertiary)
                TextField(
                    "",
                    text: $locationQuery,
                    prompt: Text("Search address or place").foregroundColor(AppColors.textTertiary)
                )
                .font(AppTypography.rowValue)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.leading)
                .focused($locationFocused)
                .submitLabel(.search)
                if !locationQuery.isEmpty {
                    Button {
                        clearLocation()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(AppTypography.rowMeta)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if locationFocused, !locationSearch.results.isEmpty {
                FormDivider()
                ForEach(Array(locationSearch.results.enumerated()), id: \.offset) { index, completion in
                    Button {
                        applyLocationCompletion(completion, rank: index)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(AppTypography.rowMeta)
                                .foregroundColor(AppColors.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(AppTypography.rowTitle)
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(AppTypography.rowMeta)
                                        .foregroundColor(AppColors.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index != locationSearch.results.count - 1 {
                        FormDivider()
                    }
                }
            }
        }
        .onChange(of: locationQuery) { _, newValue in
            locationSearch.query = newValue
            // A change that matches the text we just wrote from a selection is the field
            // catching up, not a user edit — leave the resolved coordinate intact.
            guard newValue != appliedLocationText else { return }
            locationLatitude = nil
            locationLongitude = nil
        }
    }

    private func clearLocation() {
        locationQuery = ""
        locationLatitude = nil
        locationLongitude = nil
        appliedLocationText = nil
        locationSearch.clearResults()
    }

    private func applyLocationCompletion(_ completion: MKLocalSearchCompletion, rank: Int) {
        let display = completion.subtitle.isEmpty
            ? completion.title
            : "\(completion.title), \(completion.subtitle)"
        appliedLocationText = display
        locationQuery = display
        locationFocused = false
        locationSearch.clearResults()

        AnalyticsTracker.log(AnalyticsTracker.Event.locationSuggestionSelected, [
            "suggestion_rank": rank,
            "is_editing": transactionToEdit != nil
        ])

        Task {
            if let coordinate = await locationSearch.resolve(completion) {
                locationLatitude = coordinate.latitude
                locationLongitude = coordinate.longitude
            }
        }
    }

    @ViewBuilder
    private var recurringSection: some View {
        FormSection("Recurring") {
            FormToggleRow(title: "Repeat monthly", isOn: $isRecurring)
            if isRecurring {
                Text(recurringHelpText)
                    .font(AppTypography.rowMeta)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var recurringHelpText: String {
        let day = Calendar.current.component(.day, from: transactionDate)
        let ordinal = Self.ordinalDay(day)
        if day >= 29 {
            return "Repeats on the \(ordinal) each month (or the last day in shorter months). Turn off to stop the chain."
        }
        return "Repeats on the \(ordinal) each month. Turn off to stop the chain."
    }

    private static func ordinalDay(_ day: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: day)) ?? "\(day)"
    }

    @ViewBuilder
    private var noteSection: some View {
        FormSection("Note") {
            FormNoteEditor(
                text: $note,
                placeholder: "This transaction is about…",
                isFocused: $noteFocused
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
                .foregroundColor(AppColors.textSecondary)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") { saveTransaction() }
                .font(AppTypography.navButton)
                .foregroundColor(isValid && !isSaving ? AppColors.accent : AppColors.textTertiary)
                .disabled(!isValid || isSaving)
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button {
                merchantFocused = false
                amountFocused = false
                noteFocused = false
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .foregroundColor(AppColors.accent)
            }
        }
    }

    // MARK: - Category inference

    /// Runs the shared `CategoryInference` cascade when the merchant field loses
    /// focus while adding. Editing is left alone — a stored category is the
    /// user's own decision, not something to second-guess.
    private func guessCategoryIfNeeded() {
        guard transactionToEdit == nil, !categoryWasEdited else { return }
        let name = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = name.lowercased()
        guard key.count >= 2, key != lastGuessedMerchant else { return }
        lastGuessedMerchant = key
        // Whatever we decide below supersedes any request still in the air for
        // the previous merchant.
        guessTask?.cancel()

        // Tier 1 is a local SwiftData fetch, so run it inline: a merchant the
        // user has categorised before fills instantly, with no spinner and no
        // network round-trip.
        if let known = CategoryInference.categoryFromHistory(merchantName: name, in: modelContext) {
            category = known
            categoryGuessSource = .history
            isGuessingCategory = false
            return
        }

        // Snapshot the categories on the main actor — SwiftData models must not
        // cross the await into the request.
        let options = CategoryInference.options(from: categoryRecords)
        let amountValue = Decimal(string: amount)
        let currencyCode = currency.isEmpty ? defaultCurrencyCode : currency
        let cardName = selectedCard?.name

        isGuessingCategory = true
        guessTask = Task { @MainActor in
            let remote = await CategoryInference.remoteCategory(
                merchantName: name,
                amount: amountValue,
                currency: currencyCode,
                cardName: cardName,
                options: options
            )
            // A newer blur superseded us; that task owns the spinner now.
            guard !Task.isCancelled else { return }
            isGuessingCategory = false
            // The user picked a category while we were waiting — theirs wins.
            guard !categoryWasEdited else { return }

            let source: CategoryInference.Source = remote == nil ? .heuristic : .remote
            category = remote ?? CategoryInference.heuristicCategory(for: name)
            categoryGuessSource = source
            AnalyticsTracker.log(AnalyticsTracker.Event.categoryGuessed, [
                "source": source.rawValue,
                "merchant": name,
                "category": category
            ])
        }
    }

    // MARK: - Actions

    private func formatAmountInput(_ input: String) -> String {
        let filtered = input.filter { $0.isNumber || $0 == "." }
        let parts = filtered.components(separatedBy: ".")
        if parts.count > 1 {
            let integerPart = parts[0]
            let decimalPart = String(parts[1].prefix(2))
            return "\(integerPart).\(decimalPart)"
        }
        return filtered
    }

    private func saveTransaction() {
        guard !isSaving, let amountDecimal = Decimal(string: amount) else { return }
        isSaving = true
        if let editing = transactionToEdit {
            editing.merchant = merchant
            editing.amount = amountDecimal
            editing.currency = currency
            editing.date = transactionDate
            editing.category = category.isEmpty ? nil : category
            editing.note = note.isEmpty ? nil : note
            editing.card = selectedCard
            editing.isRecurring = isRecurring
            let trimmedPlace = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            editing.placeName = trimmedPlace.isEmpty ? nil : trimmedPlace
            editing.latitude = locationLatitude
            editing.longitude = locationLongitude
            do {
                try modelContext.save()
                if isRecurring {
                    RecurringMaterializer.materialize(in: modelContext)
                }
                WidgetDataWriter.refresh(using: modelContext)
                dismiss()
            } catch {
                isSaving = false
                print("Error saving transaction: \(error)")
            }
        } else {
            let trimmedPlace = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            // A toolbar tap doesn't resign first responder, so Save can be hit
            // without the merchant field ever blurring. Kick the cascade off now
            // if it hasn't run; it's a no-op once it has.
            guessCategoryIfNeeded()
            Task {
                // Let an in-flight guess land rather than persisting the "Other"
                // default — bounded by CategoryInference's own timeouts.
                await guessTask?.value

                if !trimmedPlace.isEmpty {
                    // User picked/typed a location — honour it and skip the GPS capture entirely.
                    persistNewTransaction(
                        amount: amountDecimal,
                        latitude: locationLatitude,
                        longitude: locationLongitude,
                        placeName: trimmedPlace
                    )
                } else {
                    // Capture where the transaction was made (best-effort) before persisting. Returns
                    // nil quickly when location permission is off or no fix is available in time.
                    let location = await LocationManager.capture()
                    persistNewTransaction(
                        amount: amountDecimal,
                        latitude: location?.latitude,
                        longitude: location?.longitude,
                        placeName: location?.placeName
                    )
                }
            }
        }
    }

    @MainActor
    private func persistNewTransaction(amount amountDecimal: Decimal, latitude: Double?, longitude: Double?, placeName: String?) {
        let transaction = Transaction(
            merchant: merchant,
            amount: amountDecimal,
            date: transactionDate,
            category: category.isEmpty ? nil : category,
            note: note.isEmpty ? nil : note,
            card: selectedCard,
            currency: currency,
            isRecurring: isRecurring,
            latitude: latitude,
            longitude: longitude,
            placeName: placeName
        )
        modelContext.insert(transaction)
        AnalyticsTracker.log("add_wallet_transaction", [
            "type": "manual",
            "merchant": merchant,
            "amount": amount,
            "currency": currency,
            "has_location": latitude != nil,
            "category_source": categoryGuessSource?.rawValue ?? "manual"
        ])
        do {
            try modelContext.save()
            if isRecurring {
                RecurringMaterializer.materialize(in: modelContext)
            }
            WidgetDataWriter.refresh(using: modelContext)
            dismiss()
        } catch {
            isSaving = false
            print("Error saving transaction: \(error)")
        }
    }

    private func deleteTransaction() {
        guard let editing = transactionToEdit else { return }
        modelContext.delete(editing)
        do { try modelContext.save(); WidgetDataWriter.refresh(using: modelContext); dismiss() }
        catch { print("Error deleting transaction: \(error)") }
    }
}

#Preview {
    TransactionFormView()
        .modelContainer(ModelContainer.createMockContainer())
}
