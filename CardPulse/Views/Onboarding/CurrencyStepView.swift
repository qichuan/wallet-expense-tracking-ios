//
//  CurrencyStepView.swift
//  CardPulse
//

import SwiftUI
import SwiftData

struct CurrencyStepView: View {
    @Binding var selectedCode: String

    private var currencies: [CurrencyInfo] {
        let sorted = CurrencyUtils.allCurrencies.sorted { $0.name < $1.name }
        let pinned = Self.defaultLocaleCode()
        guard let idx = sorted.firstIndex(where: { $0.code == pinned }) else { return sorted }
        var reordered = sorted
        let top = reordered.remove(at: idx)
        reordered.insert(top, at: 0)
        return reordered
    }

    static func defaultLocaleCode() -> String {
        let all = Set(CurrencyUtils.allCurrencies.map { $0.code })
        if let id = Locale.current.currency?.identifier, all.contains(id) { return id }
        return "USD"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Select your main\ncurrency")
                    .font(AppTypography.screenTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)

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
            if selectedCode.isEmpty { selectedCode = Self.defaultLocaleCode() }
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
}

#Preview {
    @Previewable @State var code = "USD"
    CurrencyStepView(selectedCode: $code)
        .background(AppColors.backgroundPrimary)
        .modelContainer(ModelContainer.createMockContainer())
}
