import SwiftUI

// Start-up delayed because all airfoils are loaded in from library
// Should have an easy to update the library
// Mapping in 0-1 should be pre-computed
// A way to update orientation and edge and it should be visual
// Fix animations

let library = Contours.build()

enum Contouring { case dotted }

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

struct Contour: Decodable, Shape {
    var name: String
    let definition: [CGPoint]
    var options: Set<Contouring>
    var dot: CGFloat
    var points: Int
    //var edge: Edge
    
    var thickness: Thickness {
        let ordered = coordinates.sorted(by: {$0.y < $1.y})
        return Thickness(bottom: ordered.first?.y ?? .zero, top: ordered.last?.y ?? .zero)
    }
    
    private enum CodingKeys: String, CodingKey {
        case name
        case coordinates
    }
    
    var coordinates: [CGPoint] {
        var coordinates = definition
        let size = (points - coordinates.count)/(coordinates.count-1)
        return switch points - coordinates.count {
        case let difference where difference < 0:
            coordinates.streamlined(until: points-1)
        default:
            coordinates.spline(by: size, type: .centripetal)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var confined = coordinates.map { confine(coordinate: $0, in: rect) }
        path.move(to: confined.first ?? CGPoint(x: rect.midX, y: rect.maxY))
        _ = confined.map { path.addLine(to: $0) }
        guard options.contains(.dotted) else { return path }
        confined.removeLast()
        let size = dot*rect.width
        _ = confined.map { path.addEllipse(in: CGRect(x: $0.x - size, y: $0.y - size, width: 2*size, height: 2*size)) }
        return path
    }
    
    private func confine(coordinate point: CGPoint, in rect: CGRect) -> CGPoint {
        return CGPoint(
            x: point.x * rect.width,
            y: (thickness.top - point.y) * rect.width
        )
    }
    
    init(name: String, coordinates: [CGPoint], options: Set<Contouring> = [], dot: CGFloat = 0.05)  {
        self.name = name
        self.definition = coordinates
        self.points = coordinates.count
        self.dot = dot
        self.options = options
        //self.edge = edge
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let format = DecodingError.dataCorruptedError(forKey: .coordinates, in: container, debugDescription: "Invalid Coordinate Format")
        let empty = DecodingError.dataCorruptedError(forKey: .coordinates, in: container, debugDescription: "Empty Library")
        name = try container.decode(String.self, forKey: .name)

        let decode = try container.decode([[String: CGFloat]].self, forKey: .coordinates)
        var decoded = try decode.map {
            guard let x = $0["x"], let y = $0["y"] else { throw format }
            return CGPoint(x: x, y: y)
        }
        decoded.deduplicate()
        guard let first = decoded.first else { throw empty }
        decoded.append(first)
        definition = decoded.map(in: 0...1)
        points = definition.count
        dot = 0.005
        options = []
    }
}
