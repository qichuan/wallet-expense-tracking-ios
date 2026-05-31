//
//  Transaction.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class Transaction {
    var id: UUID
    var merchant: String
    var amount: Decimal
    /// Empty string means "use the default currency configured in Settings".
    var currency: String = ""
    var date: Date
    var category: String?
    var note: String?
    var card: Card?
    /// When true, this transaction is part of a monthly recurring series. The materializer
    /// uses the latest recurring transaction in a `(merchant, card, currency)` group as the
    /// template for next month's instance. Toggling off on the latest instance stops the chain.
    var isRecurring: Bool = false

    /// Latitude where the transaction was made, captured from the device's location at add
    /// time when location permission is granted. `nil` when permission was off or unavailable.
    var latitude: Double?
    /// Longitude where the transaction was made. See `latitude`.
    var longitude: Double?
    /// Reverse-geocoded place name (e.g. "Tiong Bahru Bakery" or a street address) for the
    /// captured coordinate. `nil` when geocoding failed or no location was captured.
    var placeName: String?

    /// Resolved currency: falls back to the user's default when the stored value is empty.
    var resolvedCurrency: String {
        currency.isEmpty ? CurrencyUtils.defaultCurrencyCode : currency
    }

    /// Captured coordinate, present only when both latitude and longitude were stored.
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(merchant: String, amount: Decimal, date: Date, category: String? = nil, note: String? = nil, card: Card? = nil, currency: String = "", isRecurring: Bool = false, latitude: Double? = nil, longitude: Double? = nil, placeName: String? = nil) {
        self.id = UUID()
        self.merchant = merchant
        self.amount = amount
        self.currency = currency
        self.date = date
        self.category = category
        self.note = note
        self.card = card
        self.isRecurring = isRecurring
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
    }
}
