import SwiftUI

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.equalTo(rhs)
    }
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func *(point: CGPoint, scalar: CGFloat) -> CGPoint {
        return CGPoint(x: point.x * scalar, y: point.y * scalar)
    }
    static func *(scalar: CGFloat, point: CGPoint) -> CGPoint {
        return point*scalar
    }
    
    func distance(to point: CGPoint) -> CGFloat {
        let dx = self.x - point.x
        let dy = self.y - point.y
        return sqrt(dx*dx + dy*dy)
    }
}

extension Array where Element == CGPoint {
    func tessellate() -> [CGFloat] {
        var areas = [CGFloat](repeating: 0, count: self.count)
        let triangulate = { (P0: CGPoint, P1: CGPoint, P2: CGPoint) -> CGFloat in
            abs(P0.x*P1.y + P1.x*P2.y + P2.x*P0.y - P0.x*P2.y - P1.x*P0.y - P2.x*P1.y)/2
        }
        for i in 1...self.count-2 {
            areas.append(triangulate(self[i-1], self[i], self[i+1]))
        }
        return areas
    }
    
    private mutating func streamline(to size: Int = 60, tolerance: CGFloat = 0.1) {
        guard self.count > size else { return }
        var areas = self.tessellate()
        areas.removeAll(where: { $0.isEqual(to: .zero) } )
        guard let smallest = areas.min() else { return }
        guard smallest <= tolerance else { return }
        guard let index = areas.firstIndex(where: { $0 == smallest } )
        else { return }
        self.remove(at: index)
        streamline(to: size, tolerance: tolerance)
    }
    
    mutating func seal() {
        guard self.count > 0 else { return }
        self.append(self.first!)
    }
    
    mutating func streamlined(until size: Int = 60, tolerance: CGFloat = 0.1) -> Self {
        streamline(to: size, tolerance: tolerance)
        seal()
        return self
    }
    
    func spline(by accuracy: Int = 4, type: Spline = .centripetal) -> [CGPoint] {
        guard self.count > 3 else { return self }
        var spline = [CGPoint]()
        for i in 0...self.count - 2 {
            let P0 = self[i == 0 ? self.count - 3 : i - 1]
            let P1 = self[i]
            let P2 = self[i+1]
            let P3 = self[i == (self.count - 2) ? 1 : i + 2]
            
            let t0 = 0.0
            let t1 = knot(t0, from: P0, to: P1)
            let t2 = knot(t1, from: P1, to: P2)
            let t3 = knot(t2, from: P2, to: P3)
            
            let step = (t2 - t1) / Double(accuracy + 1)
            
            for t in stride(from: t1, to: t2, by: step) {
                let A1 = (t1 - t) / (t1 - t0) * P0 + (t - t0) / (t1 - t0) * P1
                let A2 = (t2 - t) / (t2 - t1) * P1 + (t - t1) / (t2 - t1) * P2
                let A3 = (t3 - t) / (t3 - t2) * P2 + (t - t2) / (t3 - t2) * P3
                let B1 = (t2 - t) / (t2 - t0) * A1 + (t - t0) / (t2 - t0) * A2
                let B2 = (t3 - t) / (t3 - t1) * A2 + (t - t1) / (t3 - t1) * A3
                let point = (t2 - t) / (t2 - t1) * B1 + (t - t1) / (t2 - t1) * B2
                spline.append(point)
            }
        }
        spline.append(self.last!)
        return spline
        
        func knot(_ base: Double, from pointer: CGPoint, to pointed: CGPoint) -> Double {
            pow(pointer.distance(to: pointed), type.rawValue) + base
        }
    }
}
