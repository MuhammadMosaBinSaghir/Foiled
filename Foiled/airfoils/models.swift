import SwiftUI

var library = Contours.build()

struct Airfoil: Identifiable, View {
    var id: String
    var cord: CGFloat
    var contour: Contour? { library.first(where: { $0.name == id } ) }
    
    var body: some View {
        contour
            .frame(width: cord, height: cord*(contour?.thickness.total ?? .zero))
    }
}

enum Spline: Double, CaseIterable {
    case centripetal = 0.5
    case chordal = 1
    case uniform = 0
}

struct Contour: Hashable, Decodable, Shape {
    var name: String
    var coordinates: [CGPoint]
    var thickness: (bottom: CGFloat, top: CGFloat, total: CGFloat) {
        let top = coordinates.max { $0.y < $1.y }?.y ?? .zero
        let bottom = coordinates.min { $0.y < $1.y }?.y ?? .zero
        return (bottom: bottom, top: top, total: top - bottom)
    }
    //var num: Double
    //var type: Spline
    
    private enum CodingKeys: String, CodingKey {
        case name
        case coordinates
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let confined = coordinates.map { confine(coordinate: $0, in: rect) }
        //let spline = confined.spline(by: 1, type: .centripetal) BROKEN?
        //save to library new spline or at least 200 points.
        path.move(to: confined.first ?? CGPoint(x: rect.midX, y: rect.maxY))
        _ = confined.map { path.addLine(to: $0) }
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
