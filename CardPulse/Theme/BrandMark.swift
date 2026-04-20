//
//  BrandMark.swift
//  CardPulse
//

import SwiftUI

struct BrandMark: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            // Back card (blue, tilted slightly left)
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(AppColors.accent)
                .frame(width: size * 0.9, height: size * 0.62)
                .offset(x: -size * 0.12, y: -size * 0.04)
                .rotationEffect(.degrees(-6))

            // Front card (gold)
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(AppColors.brandGold)
                .frame(width: size * 0.9, height: size * 0.62)
                .offset(x: size * 0.14, y: size * 0.14)
                .rotationEffect(.degrees(8))

            // Wave marks
            HStack(spacing: size * 0.06) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(AppColors.onAccent)
                        .frame(width: size * 0.06, height: size * (0.14 + CGFloat(i) * 0.06))
                }
            }
            .offset(x: size * 0.28, y: size * 0.02)
        }
        .frame(width: size * 1.2, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        BrandMark(size: 24)
        BrandMark(size: 36)
        BrandMark(size: 48)
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}
