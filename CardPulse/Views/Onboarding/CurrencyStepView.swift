//
//  CurrencyStepView.swift
//  CardPulse
//

import SwiftUI
import SwiftData

struct CurrencyStepView: View {
    let totalSteps: Int
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultCurrency") private var defaultCurrencyCode = ""
    @AppStorage("enabledCurrencies") private var enabledCurrenciesRaw = ""
    @AppStorage("hasChosenDefaultCurrency") private var hasChosenDefaultCurrency = false

    @State private var selectedCode: String = ""

    /// Preselected currency derived from the device locale (e.g. "en_SG" → SGD).
    /// Falls back to USD when the locale's currency is not in our built-in list.
    private static func localePreselectedCode() -> String {
        let all = Set(CurrencyUtils.allCurrencies.map { $0.code })
        if let id = Locale.current.currency?.identifier, all.contains(id) {
            return id
        }
        return "USD"
    }

    private var currencies: [CurrencyInfo] {
        let sorted = CurrencyUtils.allCurrencies.sorted { $0.name < $1.name }
        let pinned = Self.localePreselectedCode()
        guard let idx = sorted.firstIndex(where: { $0.code == pinned }) else {
            return sorted
        }
        var reordered = sorted
        let top = reordered.remove(at: idx)
        reordered.insert(top, at: 0)
        return reordered
    }

    var body: some View {
        OnboardingScaffold(
            step: 1,
            totalSteps: totalSteps,
            title: "Select your main\ncurrency",
            description: nil,
            primaryTitle: "Continue",
            primaryEnabled: !selectedCode.isEmpty,
            onBack: onBack,
            onSkip: nil,
            onPrimary: save
        ) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(currencies.enumerated()), id: \.element.id) { idx, info in
                        Button { selectedCode = info.code } label: {
                            currencyRow(info, selected: info.code == selectedCode)
                        }
                        .buttonStyle(.plain)

                        if idx != currencies.count - 1 {
                            Divider()
                                .background(AppColors.divider)
                                .padding(.leading, 20)
                        }
                    }
                }
                .background(AppColors.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            if selectedCode.isEmpty {
                selectedCode = Self.localePreselectedCode()
            }
        }
    }

    @ViewBuilder
    private func currencyRow(_ info: CurrencyInfo, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Text(info.code)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 54, alignment: .leading)

            Text(info.name)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            if selected {
                Image(systemName: "checkmark")
                    .font(AppTypography.iconMedium)
                    .foregroundColor(AppColors.textPrimary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func backfillTransactions(currency: String) {
        guard let transactions = try? modelContext.fetch(FetchDescriptor<Transaction>()) else { return }
        for txn in transactions where txn.currency.isEmpty {
            txn.currency = currency
        }
        try? modelContext.save()
    }

    private func save() {
        guard !selectedCode.isEmpty else { return }
        defaultCurrencyCode = selectedCode
        var codes = CurrencyUtils.defaultEnabledCurrencies
        if !codes.contains(selectedCode) {
            codes.insert(selectedCode, at: 0)
        }
        enabledCurrenciesRaw = codes.joined(separator: ",")
        backfillTransactions(currency: selectedCode)
        hasChosenDefaultCurrency = true
        onContinue()
    }
}

#Preview {
    CurrencyStepView(totalSteps: 4, onBack: {}, onContinue: {})
        .modelContainer(ModelContainer.createMockContainer())
}
