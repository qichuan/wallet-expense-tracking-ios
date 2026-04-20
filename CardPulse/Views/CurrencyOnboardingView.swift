//
//  CurrencyOnboardingView.swift
//  CardPulse
//

import SwiftUI
import SwiftData

struct CurrencyOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultCurrency") private var defaultCurrencyCode = ""
    @AppStorage("enabledCurrencies") private var enabledCurrenciesRaw = ""
    @AppStorage("hasChosenDefaultCurrency") private var hasChosenDefaultCurrency = false

    @State private var selectedCode: String = ""

    private var currencies: [CurrencyInfo] { CurrencyUtils.allCurrencies }

    private func backfillTransactions(currency: String) {
        guard let transactions = try? modelContext.fetch(FetchDescriptor<Transaction>()) else { return }
        for txn in transactions where txn.currency.isEmpty {
            txn.currency = currency
        }
        try? modelContext.save()
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    BrandMark(size: 56)

                    Text("Choose Your Currency")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Select the default currency for your spending. You can add more currencies in Settings later.")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 60)
                .padding(.bottom, 32)

                // Currency list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(currencies) { info in
                            Button {
                                selectedCode = info.code
                            } label: {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(info.code)
                                            .font(AppTypography.rowTitle)
                                            .foregroundColor(AppColors.textPrimary)
                                        Text("\(info.name)  \(info.symbol)")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    Spacer()
                                    if selectedCode == info.code {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.accent)
                                            .font(AppTypography.iconRadio)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(AppColors.textTertiary)
                                            .font(AppTypography.iconRadio)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if info.code != currencies.last?.code {
                                Divider()
                                    .background(AppColors.divider)
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .background(AppColors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 20)
                }

                // Continue button
                Button {
                    guard !selectedCode.isEmpty else { return }
                    defaultCurrencyCode = selectedCode
                    // Start from the full default enabled set and add the selection if not already present
                    var codes = CurrencyUtils.defaultEnabledCurrencies
                    if !codes.contains(selectedCode) {
                        codes.insert(selectedCode, at: 0)
                    }
                    enabledCurrenciesRaw = codes.joined(separator: ",")
                    // Backfill any transactions that the migration left with an empty currency
                    // (happens when the user was new and hadn't chosen a currency at migration time)
                    backfillTransactions(currency: selectedCode)
                    hasChosenDefaultCurrency = true
                } label: {
                    Text("Get Started")
                        .font(AppTypography.headline)
                        .foregroundColor(selectedCode.isEmpty ? AppColors.textTertiary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedCode.isEmpty ? AppColors.backgroundCard : AppColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(selectedCode.isEmpty)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    CurrencyOnboardingView()
}
