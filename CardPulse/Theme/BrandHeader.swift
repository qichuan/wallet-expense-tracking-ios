//
//  BrandHeader.swift
//  CardPulse
//

import SwiftUI

struct BrandHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            BrandMark(size: 30)
            Text(title)
                .font(AppTypography.screenTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

extension BrandHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

#Preview {
    VStack(alignment: .leading) {
        BrandHeader(title: "Home")
        BrandHeader(title: "Cards") {
            Image(systemName: "plus")
                .font(.title3)
                .foregroundColor(.white)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppColors.backgroundPrimary)
}
