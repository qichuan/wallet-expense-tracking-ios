//
//  CardArt.swift
//  CardPulse
//

import SwiftUI

/// Tiny credit-card glyph with a gold chip. `Card` has no color field, so the
/// color is picked from a fixed palette by a stable hash of the card's id.
struct CardArt: View {
    let color: Color
    var width: CGFloat = 30
    var raised: Bool = false

    init(color: Color, width: CGFloat = 30, raised: Bool = false) {
        self.color = color
        self.width = width
        self.raised = raised
    }

    init(card: Card, width: CGFloat = 30, raised: Bool = false) {
        self.init(color: CardArt.color(for: card.id), width: width, raised: raised)
    }

    var body: some View {
        let height = width * 0.7
        RoundedRectangle(cornerRadius: width * 0.16, style: .continuous)
            .fill(color)
            .frame(width: width, height: height)
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
                    .fill(Color(hex: 0xFFD98A))
                    .frame(width: width * 0.25, height: width * 0.2)
                    .offset(x: width * 0.16, y: height * 0.29)
            }
            .shadow(color: raised ? AppColors.textPrimary.opacity(0.18) : .clear, radius: 0, x: 0, y: 3)
            .accessibilityHidden(true)
    }

    static let palette: [Color] = [
        Color(hex: 0x2E6DFF), Color(hex: 0x14B8A6), Color(hex: 0x6D28D9), Color(hex: 0xDC2626),
        Color(hex: 0xF59E0B), Color(hex: 0xEC4899), Color(hex: 0x0EA5E9), Color(hex: 0x64748B),
    ]

    /// Stable across launches (unlike `hashValue`, which is seeded per process).
    static func color(for id: UUID) -> Color {
        let sum = id.uuidString.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFFFFFF }
        return palette[sum % palette.count]
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(0..<CardArt.palette.count, id: \.self) { i in
            CardArt(color: CardArt.palette[i], width: 46, raised: true)
        }
    }
    .padding()
    .screenBackground()
}
