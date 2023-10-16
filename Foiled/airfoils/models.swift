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

enum Contouring {
    case condensed, dotted, streamlined
}

struct Contour: Hashable, Decodable, Shape {
    var name: String
    var coordinates: [CGPoint]
    var options: Set<Contouring>
    var dot: CGFloat
    
    var thickness: Thickness {
        let ordered = coordinates.sorted(by: {$0.y < $1.y})
        return Thickness(bottom: ordered.first?.y ?? .zero, top: ordered.last?.y ?? .zero)
    }
    
    private enum CodingKeys: String, CodingKey {
        case name
        case coordinates
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var confined = coordinates.map { confine(coordinate: $0, in: rect) }
        var spline: [CGPoint] = switch
        (options.contains(.condensed), options.contains(.streamlined)) {
        case (true, false): confined.spline(by: 4, type: .centripetal)
        case (false, true): confined.streamlined(tolerance: 0.1)
        default: confined
        }
        path.move(to: spline.first ?? CGPoint(x: rect.midX, y: rect.maxY))
        _ = spline.map { path.addLine(to: $0) }
        guard options.contains(.dotted) else { return path }
        spline.removeLast()
        let size = dot*rect.width
        if(name == "") { print("spot: \(dot), size: \(size))") }
        spline.removeLast()
        _ = spline.map { path.addEllipse(in: CGRect(x: $0.x - size, y: $0.y - size, width: 2*size, height: 2*size)) }
        return path
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(dot)
    }
    
    static func == (lhs: Contour, rhs: Contour) -> Bool {
        lhs.name == rhs.name && lhs.dot == rhs.dot && lhs.options == rhs.options
    }
    
    private func confine(coordinate point: CGPoint, in rect: CGRect) -> CGPoint {
        return CGPoint(
            x: point.x * rect.width,
            y: (thickness.top - point.y) * rect.width
        )
    }
    
    init(name: String, coordinates: [CGPoint], options: Set<Contouring> = [], dot: CGFloat = 0.05)  {
        self.name = name
        self.coordinates = coordinates
        self.dot = dot
        self.options = options
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
        self.dot = 0.005
        self.options = []
    }
}
