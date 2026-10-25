//
//  AdaptiveLayout.swift
//  CardPulse
//
//  Screens choose their layout from the space they're given, never from the
//  device, idiom or orientation. On iPhone Duo the same scene moves between the
//  outer and inner displays as it folds, and Split View or iPhone Mirroring can
//  hand it any size, so layout must follow the current size every time it changes.
//

import SwiftUI

/// How many columns a screen has room for.
nonisolated enum LayoutWidth: Equatable, Sendable {
    /// One column: an iPhone, iPhone Duo's outer display, or half of Split View.
    case compact
    /// Two columns side by side, like iPhone Duo's inner display.
    case expanded

    /// Narrowest width that gets two columns, so each keeps roughly the
    /// 320pt the phone layouts are designed around.
    static let expandedMinWidth: CGFloat = 640

    init(width: CGFloat) {
        self = width >= Self.expandedMinWidth ? .expanded : .compact
    }
}

extension View {
    /// Keeps `layoutWidth` in step with this view's width through every fold,
    /// rotation and Split View resize, not just at launch.
    func readLayoutWidth(_ layoutWidth: Binding<LayoutWidth>) -> some View {
        onGeometryChange(for: LayoutWidth.self) { proxy in
            LayoutWidth(width: proxy.size.width)
        } action: { newValue in
            layoutWidth.wrappedValue = newValue
        }
    }
}
