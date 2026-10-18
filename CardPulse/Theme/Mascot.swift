//
//  Mascot.swift
//  CardPulse
//
//  The CardLah! mascot: a little credit card with legs. Drawn in a fixed
//  140×132 coordinate space (ported from the design's SVG) and scaled to `size`.
//

import SwiftUI

struct Mascot: View {
    enum Mood {
        case happy, excited, worried, normal
    }

    enum Motion {
        case bob, jump, none
    }

    var mood: Mood = .happy
    var size: CGFloat = 100
    var motion: Motion = .bob

    @AppStorage("mascotColor") private var paletteRaw = MascotPalette.gold.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let canvas = CGSize(width: 140, height: 132)
    private static let ink = Color(hex: 0x0A1428)

    private var palette: MascotPalette {
        MascotPalette(rawValue: paletteRaw) ?? .gold
    }

    private var resolvedMotion: Motion {
        reduceMotion ? .none : motion
    }

    var body: some View {
        let scale = size / Self.canvas.width
        ZStack(alignment: .topLeading) {
            Ellipse()
                .fill(Self.ink.opacity(0.10))
                .frame(width: 72, height: 12)
                .position(x: 70, y: 125)
            animatedFigure
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: size, height: size * Self.canvas.height / Self.canvas.width, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    // MARK: - Motion

    @ViewBuilder
    private var animatedFigure: some View {
        switch resolvedMotion {
        case .none:
            figure
        case .bob:
            figure.keyframeAnimator(initialValue: 0.0, repeating: true) { content, y in
                content.offset(y: y)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-4, duration: 1.3)
                    CubicKeyframe(0, duration: 1.3)
                }
            }
        case .jump:
            figure.keyframeAnimator(initialValue: JumpFrame(), repeating: true) { content, frame in
                content
                    .rotationEffect(.degrees(frame.angle), anchor: .bottom)
                    .offset(y: frame.y)
            } keyframes: { _ in
                KeyframeTrack(\.y) {
                    CubicKeyframe(-18, duration: 0.385)
                    LinearKeyframe(-18, duration: 0.22)
                    CubicKeyframe(0, duration: 0.275)
                    LinearKeyframe(0, duration: 0.22)
                }
                KeyframeTrack(\.angle) {
                    CubicKeyframe(-4, duration: 0.385)
                    CubicKeyframe(4, duration: 0.22)
                    CubicKeyframe(0, duration: 0.275)
                    LinearKeyframe(0, duration: 0.22)
                }
            }
        }
    }

    private struct JumpFrame {
        var y: Double = 0
        var angle: Double = 0
    }

    // MARK: - Figure

    private var figure: some View {
        ZStack(alignment: .topLeading) {
            backCard
            arms
            CanvasShape { p in
                p.addRoundedRect(in: CGRect(x: 46, y: 100, width: 13, height: 21), cornerSize: CGSize(width: 6.5, height: 6.5))
                p.addRoundedRect(in: CGRect(x: 81, y: 100, width: 13, height: 21), cornerSize: CGSize(width: 6.5, height: 6.5))
            }
            .fill(Self.ink)
            CanvasShape { p in
                p.addRoundedRect(in: CGRect(x: 20, y: 34, width: 100, height: 76), cornerSize: CGSize(width: 24, height: 24), style: .continuous)
            }
            .fill(palette.edge)
            CanvasShape { p in
                p.addRoundedRect(in: CGRect(x: 20, y: 28, width: 100, height: 76), cornerSize: CGSize(width: 24, height: 24), style: .continuous)
            }
            .fill(palette.main)
            chip
            CanvasShape { p in
                p.move(to: CGPoint(x: 98, y: 38))
                p.addQuadCurve(to: CGPoint(x: 98, y: 48), control: CGPoint(x: 102, y: 43))
                p.move(to: CGPoint(x: 104, y: 35))
                p.addQuadCurve(to: CGPoint(x: 104, y: 51), control: CGPoint(x: 110, y: 43))
            }
            .stroke(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            eye(cx: 52, cy: 70)
            eye(cx: 88, cy: 70)
            CanvasShape { p in
                p.addEllipse(in: CGRect(x: 30, y: 80.5, width: 14, height: 9))
                p.addEllipse(in: CGRect(x: 96, y: 80.5, width: 14, height: 9))
            }
            .fill(Color(hex: 0xFF7A9A).opacity(0.55))
            mouth
            if mood == .worried {
                worriedExtras
            }
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)
    }

    private var backCard: some View {
        let shape = CanvasShape { p in
            p.addRoundedRect(in: CGRect(x: 40, y: 12, width: 80, height: 56), cornerSize: CGSize(width: 14, height: 14), style: .continuous)
        }
        return ZStack(alignment: .topLeading) {
            shape.fill(palette.back)
            CanvasShape { p in p.addRect(CGRect(x: 40, y: 24, width: 80, height: 9)) }
                .fill(Color.black.opacity(0.2))
                .clipShape(shape)
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)
        .rotationEffect(.degrees(14), anchor: UnitPoint(x: 79 / Self.canvas.width, y: 41 / Self.canvas.height))
    }

    private var arms: some View {
        let raised = mood == .excited
        return CanvasShape { p in
            if raised {
                p.move(to: CGPoint(x: 26, y: 66)); p.addLine(to: CGPoint(x: 10, y: 44))
                p.move(to: CGPoint(x: 114, y: 66)); p.addLine(to: CGPoint(x: 130, y: 44))
            } else {
                p.move(to: CGPoint(x: 24, y: 74)); p.addLine(to: CGPoint(x: 12, y: 90))
                p.move(to: CGPoint(x: 116, y: 74)); p.addLine(to: CGPoint(x: 128, y: 90))
            }
        }
        .stroke(palette.edge, style: StrokeStyle(lineWidth: 11, lineCap: .round))
    }

    private var chip: some View {
        let rect = CGRect(x: 30, y: 37, width: 19, height: 14)
        return ZStack(alignment: .topLeading) {
            CanvasShape { p in p.addRoundedRect(in: rect, cornerSize: CGSize(width: 4, height: 4)) }
                .fill(Color(hex: 0xFFF1C2))
            CanvasShape { p in p.addRoundedRect(in: rect.insetBy(dx: 1, dy: 1), cornerSize: CGSize(width: 3, height: 3)) }
                .stroke(palette.edge, lineWidth: 2)
            CanvasShape { p in
                p.move(to: CGPoint(x: 30, y: 44)); p.addLine(to: CGPoint(x: 49, y: 44))
                p.move(to: CGPoint(x: 39.5, y: 37)); p.addLine(to: CGPoint(x: 39.5, y: 51))
            }
            .stroke(palette.edge, lineWidth: 1.6)
        }
    }

    @ViewBuilder
    private func eye(cx: CGFloat, cy: CGFloat) -> some View {
        if mood == .happy || mood == .excited {
            CanvasShape { p in
                p.move(to: CGPoint(x: cx - 8, y: cy + 3))
                p.addQuadCurve(to: CGPoint(x: cx + 8, y: cy + 3), control: CGPoint(x: cx, y: cy - 8))
            }
            .stroke(Self.ink, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
        } else {
            BlinkingEye(cx: cx, cy: cy, ink: Self.ink, animated: resolvedMotion != .none)
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .happy:
            CanvasShape { p in
                p.move(to: CGPoint(x: 59, y: 84))
                p.addLine(to: CGPoint(x: 81, y: 84))
                p.addQuadCurve(to: CGPoint(x: 70, y: 96), control: CGPoint(x: 79, y: 96))
                p.addQuadCurve(to: CGPoint(x: 59, y: 84), control: CGPoint(x: 61, y: 96))
                p.closeSubpath()
            }
            .fill(Self.ink)
            CanvasShape { p in p.addEllipse(in: CGRect(x: 65, y: 89.4, width: 10, height: 5.2)) }
                .fill(Color(hex: 0xFF6B8B))
        case .excited:
            CanvasShape { p in
                p.move(to: CGPoint(x: 56, y: 82))
                p.addLine(to: CGPoint(x: 84, y: 82))
                p.addQuadCurve(to: CGPoint(x: 70, y: 99), control: CGPoint(x: 82, y: 99))
                p.addQuadCurve(to: CGPoint(x: 56, y: 82), control: CGPoint(x: 58, y: 99))
                p.closeSubpath()
            }
            .fill(Self.ink)
            CanvasShape { p in p.addEllipse(in: CGRect(x: 63, y: 90.6, width: 14, height: 6.8)) }
                .fill(Color(hex: 0xFF6B8B))
        case .worried:
            CanvasShape { p in
                p.move(to: CGPoint(x: 61, y: 92))
                p.addQuadCurve(to: CGPoint(x: 70, y: 92), control: CGPoint(x: 65.5, y: 87))
                p.addQuadCurve(to: CGPoint(x: 79, y: 92), control: CGPoint(x: 74.5, y: 97))
            }
            .stroke(Self.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        case .normal:
            CanvasShape { p in
                p.move(to: CGPoint(x: 61, y: 86))
                p.addQuadCurve(to: CGPoint(x: 79, y: 86), control: CGPoint(x: 70, y: 94))
            }
            .stroke(Self.ink, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
        }
    }

    private var worriedExtras: some View {
        ZStack(alignment: .topLeading) {
            CanvasShape { p in
                p.move(to: CGPoint(x: 43, y: 57)); p.addLine(to: CGPoint(x: 57, y: 52))
                p.move(to: CGPoint(x: 83, y: 52)); p.addLine(to: CGPoint(x: 97, y: 57))
            }
            .stroke(Self.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            CanvasShape { p in
                p.move(to: CGPoint(x: 112, y: 40))
                p.addQuadCurve(to: CGPoint(x: 112, y: 52), control: CGPoint(x: 118, y: 49))
                p.addQuadCurve(to: CGPoint(x: 112, y: 40), control: CGPoint(x: 106, y: 49))
                p.closeSubpath()
            }
            .fill(Color(hex: 0x7CC4FF))
        }
    }
}

/// Open eye that blinks every few seconds.
private struct BlinkingEye: View {
    let cx: CGFloat
    let cy: CGFloat
    let ink: Color
    let animated: Bool

    var body: some View {
        if animated {
            eye.keyframeAnimator(initialValue: 1.0, repeating: true) { content, scaleY in
                content.scaleEffect(x: 1, y: scaleY, anchor: UnitPoint(x: cx / 140, y: cy / 132))
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(1, duration: 3.9)
                    LinearKeyframe(0.1, duration: 0.13)
                    LinearKeyframe(1, duration: 0.17)
                }
            }
        } else {
            eye
        }
    }

    private var eye: some View {
        let cx = cx, cy = cy
        return ZStack(alignment: .topLeading) {
            CanvasShape { p in p.addEllipse(in: CGRect(x: cx - 9, y: cy - 10.5, width: 18, height: 21)) }
                .fill(Color.white)
            CanvasShape { p in p.addEllipse(in: CGRect(x: cx + 1 - 5.8, y: cy + 1.5 - 5.8, width: 11.6, height: 11.6)) }
                .fill(ink)
            CanvasShape { p in p.addEllipse(in: CGRect(x: cx + 1, y: cy - 3.5, width: 4, height: 4)) }
                .fill(Color.white)
        }
        .frame(width: 140, height: 132, alignment: .topLeading)
    }
}

/// A shape drawn in absolute mascot-canvas coordinates.
nonisolated private struct CanvasShape: Shape {
    let build: @Sendable (inout Path) -> Void

    func path(in rect: CGRect) -> Path {
        var path = Path()
        build(&path)
        return path
    }
}

enum MascotPalette: String, CaseIterable, Identifiable {
    case gold = "Gold"
    case pink = "Pink"
    case mint = "Mint"

    var id: String { rawValue }

    var main: Color {
        switch self {
        case .gold: return Color(hex: 0xFFC93C)
        case .pink: return Color(hex: 0xFF8FB8)
        case .mint: return Color(hex: 0x5EE2A0)
        }
    }

    var edge: Color {
        switch self {
        case .gold: return Color(hex: 0xE3A21A)
        case .pink: return Color(hex: 0xE0588F)
        case .mint: return Color(hex: 0x1FB874)
        }
    }

    var back: Color {
        switch self {
        case .gold, .pink: return AppColors.accent
        case .mint:        return Color(hex: 0xFFC93C)
        }
    }
}

#Preview("Moods") {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            Mascot(mood: .happy, size: 100)
            Mascot(mood: .excited, size: 100, motion: .jump)
        }
        HStack(spacing: 16) {
            Mascot(mood: .worried, size: 100)
            Mascot(mood: .normal, size: 100, motion: .none)
        }
    }
    .padding()
    .screenBackground()
}

#Preview("Moods — dark") {
    HStack(spacing: 16) {
        Mascot(mood: .happy, size: 90)
        Mascot(mood: .worried, size: 90)
    }
    .padding()
    .screenBackground()
    .preferredColorScheme(.dark)
}
