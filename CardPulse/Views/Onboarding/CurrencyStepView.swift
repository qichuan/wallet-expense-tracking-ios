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

    private var preselected: CurrencyInfo? {
        CurrencyUtils.allCurrencies.first { $0.code == selectedCode }
    }

    private var otherCurrencies: [CurrencyInfo] {
        CurrencyUtils.allCurrencies
            .filter { $0.code != selectedCode }
            .sorted { $0.name < $1.name }
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
                VStack(spacing: 14) {
                    if let preselected {
                        preselectedCard(preselected)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(otherCurrencies.enumerated()), id: \.element.id) { idx, info in
                            Button { selectedCode = info.code } label: {
                                currencyRow(info)
                            }
                            .buttonStyle(.plain)

                            if idx != otherCurrencies.count - 1 {
                                Divider()
                                    .background(AppColors.divider)
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .background(AppColors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
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
    private func preselectedCard(_ info: CurrencyInfo) -> some View {
        HStack(spacing: 12) {
            Text(info.code)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 54, alignment: .leading)

            Text(info.name)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Image(systemName: "checkmark")
                .font(AppTypography.iconMedium)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func currencyRow(_ info: CurrencyInfo) -> some View {
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
