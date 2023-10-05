import Foundation

extension CGPoint {
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}

extension CGPoint {
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
    func spline(by accuracy: Int = 4, type: Spline = .centripetal) -> [CGPoint] {
        func knot(_ base: Double, from pointer: CGPoint, to pointed: CGPoint) -> Double {
            pow(pointer.distance(to: pointed), type.rawValue) + base
        }
        var spline = [CGPoint]()
        for i in 1...(self.count - 3) {
            let P0 = self[i - 1]
            let P1 = self[i]
            let P2 = self[i + 1]
            let P3 = self[i + 2]
            
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
        guard let first = self.first else { return spline }
        spline.insert(first, at: 0)
        guard let last = self.last else { return spline }
        spline.append(last)
        return spline
    }
}

