import SwiftUI

let library = Contours.build()

struct Airfoil: Identifiable, View {
    var id: String
    var cord: CGFloat
    var contour: Contour? { library.first(where: { $0.name == id } ) }
    
    var body: some View {
        contour?
            .stroke(.primary, lineWidth: 1)
            .frame(width: cord, height: cord*(contour?.thickness.total ?? .zero))
    }
}

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
    var dotted = true
    var dot: CGFloat = 0.005
    
    private enum CodingKeys: String, CodingKey {
        case name
        case coordinates
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let confined = coordinates.map { confine(coordinate: $0, in: rect) }
        var spline = confined.spline(by: 4, type: .centripetal)
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
