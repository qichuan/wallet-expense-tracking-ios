// Swift:Sequence+Uniqued.swift
import Foundation

extension Sequence where Element: Hashable {
    /// Returns elements in their first-seen order, removing duplicates.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        var result: [Element] = []
        result.reserveCapacity(underestimatedCount)
        for element in self {
            if seen.insert(element).inserted {
                result.append(element)
            }
        }
        return result
    }
}
