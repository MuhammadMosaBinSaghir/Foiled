import SwiftUI

extension Path {
    func coordinates() -> [CGPoint] {
        var coordinates = [CGPoint]()
        self.forEach {
            switch $0 {
            case .move(to: let coordinate): coordinates.append(coordinate)
            case .line(to: let coordinate): coordinates.append(coordinate)
            case .curve(to: let coordinate, control1: _, control2: _):
                coordinates.append(coordinate)
            case .quadCurve(to: let coordinate, control: _): coordinates.append(coordinate)
            case .closeSubpath: break
            }
        }
        return coordinates
    }
}

extension Shape {
    func boundary(in rect: CGRect) {
        self.path(in: rect)
    }
}

self.forEach { element in
    switch (element) {
    case .move(to: let coordinate):
    case .line(to: let coordinate):
    case .curve(to: let coordinate, _, _):
    case default:
}
*/
