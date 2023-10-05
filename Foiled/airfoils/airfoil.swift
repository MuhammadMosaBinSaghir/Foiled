import SwiftUI

enum Spline: Double, CaseIterable {
    case centripetal = 0.5
    case chordal = 1
    case uniform = 0
}

struct Airfoil: Shape {
    let name: String
    let coordinates: [CGPoint]
    //var num: Double
    //var type: Spline
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let confined = coordinates.map { confine(coordinate: $0, in: rect) }
        let spline = confined.spline(by: 0, type: .centripetal)
        path.move(to: confined.first ?? CGPoint(x: rect.midX, y: rect.maxY))
        _ = spline.map { path.addLine(to: $0) }
        return path
    }
    
    private func confine(coordinate point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: point.x * rect.width, y: -point.y * rect.height + rect.midY)
    }
}
