import SwiftUI

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.equalTo(rhs)
    }
    static func +(lhs: Self, rhs: Self) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func *(point: Self, scalar: CGFloat) -> Self {
        return CGPoint(x: point.x * scalar, y: point.y * scalar)
    }
    static func *(scalar: CGFloat, point: Self) -> Self {
        return point*scalar
    }
    
    func distance(to point: Self) -> CGFloat {
        let dx = self.x - point.x
        let dy = self.y - point.y
        return sqrt(dx*dx + dy*dy)
    }
    
    func relative(to edges: (left: CGFloat, right: CGFloat, bottom: CGFloat, top: CGFloat), in rect: CGRect) -> Self {
        let shift = 0.5*(rect.height + edges.bottom - edges.top)
        let top = edges.top + shift
        let bottom = edges.bottom - shift
        return CGPoint(
            x: (self.x + 0.5*rect.width)*(edges.right-edges.left)/rect.width + edges.left,
            y: (self.y + 0.5*rect.height)*(top-bottom)/rect.height + bottom - 0.5*(edges.top - edges.bottom)
        )
    }
}

extension Array where Element == CGPoint {
    func range() -> (abscissas: ClosedRange<CGFloat>, ordinates: ClosedRange<CGFloat>) {
        let lengths = self.sorted(by: {$0.x < $1.x})
        let heights = self.sorted(by: {$0.y < $1.y})
        return (
            abscissas: lengths[0].x...lengths[count-1].x,
            ordinates: heights[0].y...lengths[count-1].y
        )
    }
    
    func map(in abscissas: ClosedRange<CGFloat> = 1...1, and ordinates: ClosedRange<CGFloat> = 1...1) -> [CGPoint] {
        let range = self.range()
        let defaulted = (abscissas: abscissas == 1...1, ordinates: ordinates == 1...1)
        switch defaulted {
        case (true, true): return self
        default: return self.map { CGPoint(
            x:  defaulted.abscissas ? $0.x : ($0.x - range.abscissas.lowerBound)*(abscissas.upperBound - abscissas.lowerBound)/(range.abscissas.upperBound - range.abscissas.lowerBound) + abscissas.lowerBound,
            y:  defaulted.ordinates ? $0.y : ($0.y - range.ordinates.lowerBound)*(ordinates.upperBound - ordinates.lowerBound)/(range.ordinates.upperBound - range.ordinates.lowerBound) + ordinates.lowerBound
        ) }
        }
    }
    
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
    
    private mutating func streamline(to size: Int) {
        guard self.count > size else { return }
        var areas = self.tessellate()
        areas.removeAll(where: { $0.isEqual(to: .zero) } )
        guard let smallest = areas.min() else { return }
        guard let index = areas.firstIndex(where: { $0 == smallest } )
        else { return }
        self.remove(at: index)
        streamline(to: size)
    }
    
    mutating func close() {
        guard self[0] != self[count - 1] else { return }
        self.append(self[0])
    }
    
    mutating func open() {
        guard self[0] == self[count - 1] else { return }
        self.removeLast()
    }
    
    func opened() -> Self {
        guard self[0] == self[count - 1] else { return self }
        return Array(self.dropLast())
    }
    
    mutating func streamlined(until size: Int) -> Self {
        streamline(to: size)
        close()
        return self
    }
    
    func spline(by accuracy: Int = 4, type: Spline = .centripetal) -> [CGPoint] {
        guard accuracy > 0 else { return self }
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
    
    func parse(precision digits: Int) -> String {
        let coordinates = self.map {
            "(\(Double($0.x).formatted(.number.precision(.significantDigits(digits)))), \(Double($0.y).formatted(.number.precision(.significantDigits(digits))))),"
        }
        var text = coordinates.reduce("[") { $0 + $1 }
        text.removeLast()
        text.append("]")
        return text
    }
}
