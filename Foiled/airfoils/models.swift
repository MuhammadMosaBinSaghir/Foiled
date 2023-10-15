import SwiftUI

let library = Contours.build()

enum Spline: Double, CaseIterable {
    case centripetal = 0.5
    case chordal = 1
    case uniform = 0
}

struct Thickness {
    var bottom: CGFloat
    var top: CGFloat
    var total: CGFloat { top - bottom }
}

struct Contour: Hashable, Decodable, Shape {
    var name: String
    var coordinates: [CGPoint]
    var thickness: Thickness {
        let ordered = coordinates.sorted(by: {$0.y < $1.y})
        return Thickness(bottom: ordered.first?.y ?? .zero, top: ordered.last?.y ?? .zero)
    }
    var splined = false
    var dotted = false
    var dot: CGFloat = 0.005
    
    private enum CodingKeys: String, CodingKey {
        case name
        case coordinates
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var confined = coordinates.map { confine(coordinate: $0, in: rect) }
        condense(&confined, until: 1)
        print(confined)
        var spline = splined ? confined.spline(by: 4, type: .centripetal) : confined
        path.move(to: spline.first ?? CGPoint(x: rect.midX, y: rect.maxY))
        _ = spline.map { path.addLine(to: $0) }
        guard dotted else { return path }
        spline.removeLast()
        let size = dot*rect.width
        spline.removeLast()
        _ = spline.map { path.addEllipse(in: CGRect(x: $0.x - size, y: $0.y - size, width: 2*size, height: 2*size)) }
        return path
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    static func == (lhs: Contour, rhs: Contour) -> Bool {
        lhs.name == rhs.name
    }
    
    init(name: String, coordinates: [CGPoint])  {
        self.name = name
        self.coordinates = coordinates
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let format = DecodingError.dataCorruptedError(forKey: .coordinates, in: container, debugDescription: "Invalid Coordinate Format")
        let empty = DecodingError.dataCorruptedError(forKey: .coordinates, in: container, debugDescription: "Empty Library")
        name = try container.decode(String.self, forKey: .name)

        let decoded = try container.decode([[String: CGFloat]].self, forKey: .coordinates)
        coordinates = try decoded.map {
            guard let x = $0["x"], let y = $0["y"] else { throw format }
            return CGPoint(x: x, y: y)
        }
        coordinates.deduplicate()
        guard let first = coordinates.first else { throw empty }
        coordinates.append(first)
    }
    
    private func confine(coordinate point: CGPoint, in rect: CGRect) -> CGPoint {
        return CGPoint(
            x: point.x * rect.width,
            y: (thickness.top - point.y) * rect.width
        )
    }
}

struct ContourCircle: Shape {
    var location: CGFloat
    var radius: CGFloat
    var id: String?
    
    var contour: Contour? {
        let name = id == nil ? "20-32C" : id
        return library.first(where: { $0.name == name } )
    }
    
    func path(in rect: CGRect) -> Path {
        var path1 = Path()
        let spline = contour?.coordinates.map { confine(coordinate: $0, in: rect) }
        guard var spline else { return path1 }
        path1.move(to: spline.first ?? CGPoint(x: rect.midX, y: rect.maxY))
        _ = spline.map { path1.addLine(to: $0) }
        var circles = a().map { confine(coordinate: $0, in: rect) }
        var path2 = Path()
        path2.move(to: circles.first ?? CGPoint(x: rect.midX, y: rect.maxY))
        _ = circles.map { path2.addLine(to: $0) }
        
        var intersection = path1.intersection(path2)
        intersection.closeSubpath()
        
        let path3 = path2.subtracting(intersection)
        
        var points2 = [CGPoint]()
        path2.forEach { element in
            if case .move(let to) = element {
                points2.append(to)
            }
            if case .line(let to) = element {
                points2.append(to)
            }
        }
        var pointsINT = [CGPoint]()
        intersection.forEach { element in
            if case .move(let to) = element {
                pointsINT.append(to)
            }
            if case .line(let to) = element {
                pointsINT.append(to)
            }
        }
        points2.removeAll { point2 in
            pointsINT.contains { INT in
                INT.equalTo(point2)
            }
        }
        let first = pointsINT.last!
        points2.insert(first, at: 1)
        let k = pointsINT.dropLast()
        points2.insert(k.last!, at: points2.count-1)
        var a = points2.dropLast().dropFirst()
        insert(Array(a), into: &spline)
        //print(spline)
        var path4 = Path()
        path4.move(to: spline.first ?? CGPoint(x: rect.midX, y: rect.maxY))
        _ = spline.map { path4.addLine(to: $0) }
        /*
        for i in 0...faa.count-2 {
            print("[(\(faa[i].x),\(faa[i].y)), (\(faa[i+1].x),\(faa[i+1].y))]")
        }
         */
        //print("\n")
        return path4
    }
    
    func insert(_ b: [CGPoint], into a: inout [CGPoint]) {
        guard let i = a.firstIndex(where: { $0.x <= b.first!.x } )
        else { return }
        a.insert(contentsOf: b, at: i)
    }
    
    func a() -> [CGPoint] {
        guard let contour else { return [] }
        guard let index = contour.coordinates.firstIndex(where: { $0.x <= location } )
        else { return [] }
        let P1 = contour.coordinates[index]
        let P2 = contour.coordinates[index - 1]
        let b = (P2.y - (P1.y/P1.x)*P2.x)/(1 - P2.x/P1.x)
        let m = (P1.y - b)/P1.x
        let center = P1.x == location ? P1 :
        CGPoint(x: location, y: m*location + b)
        var points = [CGPoint]()
        //acuracy
        for deg in stride(from: 0, through: 360, by: 20) {
            let angle = Angle(degrees: Double(deg))
            let point = CGPoint(x: center.x + radius*cos(CGFloat(angle.radians)), y: center.y + radius*sin(CGFloat(angle.radians)))
            points.append(point)
        }
        return points
    }
    
    private func confine(coordinate point: CGPoint, in rect: CGRect) -> CGPoint {
        guard let contour else { return .zero }
        return CGPoint(
            x: point.x * rect.width,
            y: (contour.thickness.top - point.y) * rect.width
        )
    }
}

func condense(_ points: inout [CGPoint], until tolerance: CGFloat) {
    guard points.count > 60 else { return }
    var areas = [CGFloat](repeating: 0, count: points.count)
    for i in 1...points.count-2 {
        areas.append(triangulate(points[i-1], points[i], points[i+1]))
    }
    areas.removeAll(where: { $0.isEqual(to: .zero) } )
    guard let smallest = areas.min() else { return }
    guard smallest <= tolerance else { return }
    guard let index = areas.firstIndex(where: { $0 == smallest } )
    else { return }
    points.remove(at: index)
    condense(&points, until: tolerance)
}

func triangulate(_ P0: CGPoint, _ P1: CGPoint, _ P2: CGPoint) -> CGFloat {
    return abs(P0.x*P1.y + P1.x*P2.y + P2.x*P0.y - P0.x*P2.y - P1.x*P0.y - P2.x*P1.y)/2
}
