//
//  ViewModifiers.swift
//  CardPulse
//

import SwiftUI

struct CardSurface: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppColors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.backgroundPrimary.ignoresSafeArea())
    }
}

extension View {
    func cardSurface(padding: CGFloat = 16, cornerRadius: CGFloat = 18) -> some View {
        modifier(CardSurface(padding: padding, cornerRadius: cornerRadius))
    }

    func screenBackground() -> some View {
        modifier(ScreenBackground())
    }
}
