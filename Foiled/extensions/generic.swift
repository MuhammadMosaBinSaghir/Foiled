import Foundation

extension Array where Element: Equatable {
    mutating func deduplicate() {
        self = self.reduce(into: [Element]()) { result, element in
            guard !result.contains(element) else { return }
            result.append(element)
        }
    }
}
