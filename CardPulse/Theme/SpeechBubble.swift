//
//  SpeechBubble.swift
//  CardPulse
//

import SwiftUI

/// Rounded speech bubble with a tail on its leading edge, shown beside the mascot.
struct SpeechBubble<Content: View>: View {
    var fill: Color = AppColors.backgroundCard
    /// Distance of the tail from the bubble's bottom edge.
    var tailBottomInset: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .font(AppTypography.bubble)
            .foregroundColor(AppColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: 2)
            )
            .overlay(alignment: .bottomLeading) {
                BubbleTail()
                    .fill(fill)
                    .overlay(BubbleTail(open: true).stroke(AppColors.border, lineWidth: 2))
                    .frame(width: 10, height: 16)
                    .offset(x: -8, y: -tailBottomInset)
            }
    }
}

/// Left-pointing triangle; `open` draws only the two outer edges so the
/// side touching the bubble stays borderless.
nonisolated private struct BubbleTail: Shape {
    var open = false

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX + 1, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX + 1, y: rect.maxY))
        if !open { p.closeSubpath() }
        return p
    }
}

/// Mascot with a speech bubble to its right, aligned to the bottom.
struct MascotSays<Content: View>: View {
    var mood: Mascot.Mood
    var mascotSize: CGFloat = 80
    var motion: Mascot.Motion = .bob
    var bubbleFill: Color = AppColors.backgroundCard
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Mascot(mood: mood, size: mascotSize, motion: motion)
            SpeechBubble(fill: bubbleFill, content: content)
                .padding(.bottom, mascotSize * 0.2)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        MascotSays(mood: .worried) {
            Text("4 days left! UOB Lady's still needs S$87. I'm sweating a bit…")
        }
        MascotSays(mood: .excited, mascotSize: 112, motion: .jump, bubbleFill: AppColors.backgroundPrimary) {
            Text("Every card has hit its target. Shiok!")
        }
    }
    .padding()
    .screenBackground()
}
