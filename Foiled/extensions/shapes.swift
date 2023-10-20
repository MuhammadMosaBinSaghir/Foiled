import SwiftUI

extension Shape {
    func boundary() -> [CGPoint] {
        let rect = CGRect(origin: .zero, size: .init(width: 1, height: 1))
        return self.path(in: rect).coordinates().normalize()
    }
}
