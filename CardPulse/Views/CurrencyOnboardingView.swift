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
            Color(red: 0.05, green: 0.1, blue: 0.2)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.teal)

                    Text("Choose Your Currency")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Select the default currency for your spending. You can add more currencies in Settings later.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
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
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("\(info.name)  \(info.symbol)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    Spacer()
                                    if selectedCode == info.code {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.teal)
                                            .font(.title3)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.white.opacity(0.3))
                                            .font(.title3)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if info.code != currencies.last?.code {
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                }

                // Continue button
                Button {
                    guard !selectedCode.isEmpty else { return }
                    defaultCurrencyCode = selectedCode
                    // Ensure the chosen currency is in the enabled list
                    var codes = enabledCurrenciesRaw
                        .components(separatedBy: ",")
                        .filter { !$0.isEmpty }
                    if !codes.contains(selectedCode) {
                        codes.insert(selectedCode, at: 0)
                        enabledCurrenciesRaw = codes.joined(separator: ",")
                    }
                    // Backfill any transactions that the migration left with an empty currency
                    // (happens when the user was new and hadn't chosen a currency at migration time)
                    backfillTransactions(currency: selectedCode)
                    hasChosenDefaultCurrency = true
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(selectedCode.isEmpty ? .white.opacity(0.4) : Color(red: 0.05, green: 0.1, blue: 0.2))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedCode.isEmpty ? Color.white.opacity(0.1) : Color.teal)
                        .cornerRadius(14)
                }
                .disabled(selectedCode.isEmpty)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    CurrencyOnboardingView()
}
