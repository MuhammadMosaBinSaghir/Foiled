import SwiftUI

extension Tag { mutating func increment() { self = self + 1 } }

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

extension Array where Element: Equatable {
    mutating func deduplicate() {
        self = self.reduce(into: [Element]()) { result, element in
            guard !result.contains(element) else { return }
            result.append(element)
        }
    }
}
