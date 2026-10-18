//
//  CardArt+Card.swift
//  CardPulse
//
//  App-target only — `Card` is a SwiftData model the widget doesn't compile.

import SwiftUI

extension CardArt {
    init(card: Card, width: CGFloat = 30, raised: Bool = false) {
        self.init(color: CardArt.color(for: card.id), width: width, raised: raised)
    }
}
