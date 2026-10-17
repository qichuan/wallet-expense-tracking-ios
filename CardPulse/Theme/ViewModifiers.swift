//
//  ViewModifiers.swift
//  CardPulse
//

import SwiftUI

/// The "chunky" surface used across the app: a filled rounded rect with a 2pt
/// outline and a thicker bottom edge (`lip`), like a pressable sticker.
/// The lip is drawn below the frame, so callers add `.padding(.bottom, lip)`.
struct ChunkyBackground: View {
    var fill: Color = AppColors.backgroundCard
    var edge: Color = AppColors.border
    var cornerRadius: CGFloat = 24
    var lip: CGFloat = 3
    var outlined: Bool = true

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(edge).offset(y: lip)
            shape.fill(fill)
            if outlined {
                shape.strokeBorder(edge, lineWidth: 2)
            }
        }
    }
}

struct CardSurface: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(ChunkyBackground(cornerRadius: cornerRadius))
            .padding(.bottom, 3)
    }
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.backgroundPrimary.ignoresSafeArea())
    }
}

extension View {
    func cardSurface(padding: CGFloat = 16, cornerRadius: CGFloat = 24) -> some View {
        modifier(CardSurface(padding: padding, cornerRadius: cornerRadius))
    }

    /// Compact list-row variant of `cardSurface` (smaller radius and edge).
    func chunkyRow(padding: CGFloat = 12) -> some View {
        self
            .padding(.horizontal, padding + 2)
            .padding(.vertical, padding)
            .background(ChunkyBackground(cornerRadius: 18, lip: 2))
            .padding(.bottom, 2)
    }

    /// Solid colored chunky surface with no outline, e.g. the blue recap hero.
    func chunkyFill(_ fill: Color, edge: Color, cornerRadius: CGFloat = 24, padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(ChunkyBackground(fill: fill, edge: edge, cornerRadius: cornerRadius, lip: 5, outlined: false))
            .padding(.bottom, 5)
    }

    func screenBackground() -> some View {
        modifier(ScreenBackground())
    }

    /// Chunky card that also clips its content (e.g. form rows with dividers).
    func chunkySurface(fill: Color = AppColors.backgroundCard, cornerRadius: CGFloat = 20) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(fill)
            .clipShape(shape)
            .overlay(shape.strokeBorder(AppColors.border, lineWidth: 2))
            .background(shape.fill(AppColors.border).offset(y: 3))
            .padding(.bottom, 3)
    }

    /// Clear background and no separator, for chunky rows inside a plain `List`.
    func plainListRow() -> some View {
        self
            .listRowBackground(AppColors.clear)
            .listRowSeparator(.hidden)
    }
}

/// Rounded progress bar on the warm track color.
struct ChunkyProgressBar: View {
    let progress: Double
    var color: Color = AppColors.accent
    var height: CGFloat = 10
    var highlight: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.track)
                let width = geo.size.width * CGFloat(max(0, min(1, progress)))
                Capsule()
                    .fill(color)
                    .frame(width: width)
                    .overlay(alignment: .top) {
                        if highlight && width > 16 {
                            Capsule()
                                .fill(Color.white.opacity(0.45))
                                .frame(height: 3)
                                .padding(.horizontal, 6)
                                .padding(.top, 3)
                        }
                    }
                    .animation(.easeOut(duration: 0.5), value: progress)
            }
        }
        .frame(height: height)
    }
}

/// Capsule pill with an outline and bottom edge, used for header stats and filter chips.
struct ChunkyPill<Content: View>: View {
    var fill: Color = AppColors.backgroundCard
    var edge: Color = AppColors.border
    var lip: CGFloat = 0
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ChunkyBackground(fill: fill, edge: edge, cornerRadius: 999, lip: lip))
            .padding(.bottom, lip)
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Chunky card")
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        Text("Chunky row")
            .frame(maxWidth: .infinity, alignment: .leading)
            .chunkyRow()
        Text("Hero")
            .foregroundColor(AppColors.onAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .chunkyFill(AppColors.accent, edge: AppColors.accentEdge)
        ChunkyProgressBar(progress: 0.6, height: 14, highlight: true)
        ChunkyPill { Text("12") }
    }
    .padding()
    .screenBackground()
}
