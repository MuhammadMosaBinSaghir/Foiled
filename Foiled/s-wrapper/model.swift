import Foundation

// Surface & Loop should pull from common source
// Call as reference, there's too much data-duplication
typealias Tag = Int32
    
enum Geometry {
    case lines
    case loop
    case surface
    
    func build(from coordinates: [CGPoint], into instance: inout Tag, tags: ClosedRange<Tag>, accuracy: Double, plane: Double) {
        guard self == .lines else { return }
        _ = coordinates.map { coordinate in
            withUnsafeMutablePointer(to: &instance) {
                gmshModelGeoAddPoint(
                    coordinate.x, coordinate.y, plane, accuracy, -1, $0
                )
            }
        }
        _ = tags.map { index in
            _ = withUnsafeMutablePointer(to: &instance) {
                switch index == coordinates.count {
                case true: gmshModelGeoAddLine(index, 1, -1, $0)
                case false: gmshModelGeoAddLine(index, index + tags.lowerBound, -1, $0)
                }
            }
        }
    }
    
    func build(from range: ClosedRange<Tag>, into instance: inout Tag) {
        guard self != .lines else { return }
        let tags = range.map { $0 }
        let pointers = tags.withUnsafeBufferPointer { $0.baseAddress }
        withUnsafeMutablePointer(to: &instance) {
            switch self {
            case .loop: gmshModelGeoAddCurveLoop(pointers, tags.count, -1, 0, $0)
            case .surface: gmshModelGeoAddPlaneSurface(pointers, tags.count, -1, $0)
            default: return
            }
        }
    }
}

struct Model {
    let name: String
    let plane: Double
    let accuracy: (boundary: Double, contour: Double)
    private var instance: Tag
    private var coordinates: [CGPoint]
    
    init(contour: Contour, plane: Double = .zero, accuracy: (boundary: Double, contour: Double)) {
        self.name = contour.name
        self.coordinates = contour.coordinates
        self.plane = plane
        self.accuracy = accuracy
        self.instance = 0
        withUnsafeMutablePointer(to: &instance) { gmshInitialize(0, nil, 1, 0, $0) }
        withUnsafeMutablePointer(to: &instance) { gmshModelAdd(name, $0) }
    }
    
    mutating func contour() {
        coordinates.open()
        Geometry.lines.build(
            from: coordinates,
            into: &instance, 
            tags: 1...Tag(coordinates.count),
            accuracy: accuracy.contour,
            plane: plane
        )
        Geometry.loop.build(from: 1...Tag(coordinates.count), into: &instance)
    }
    
    mutating func boundary(radius: Double = 1) {
        guard !coordinates.isEmpty else { return }
        let sorted = coordinates.sorted(by: {$0.y < $1.y})
        let bottom = sorted.first!.y
        let top = sorted.last!.y
        let leading: Double = 0
        let trailing: Double = 1
        let points: [CGPoint] = [
            CGPoint(x: leading, y: bottom - radius),
            CGPoint(x: trailing + radius, y: bottom - radius),
            CGPoint(x: trailing + radius, y: top + radius),
            CGPoint(x: leading, y: top + radius)
        ]
        let tags = Tag(coordinates.count + 1)...Tag(coordinates.count + points.count)
        Geometry.lines.build(
            from: points,
            into: &instance, 
            tags: tags,
            accuracy: accuracy.boundary,
            plane: plane
        )
        Geometry.loop.build(from: tags, into: &instance)
    }
    /*
    mutating func surface(from loops: [Loop], as name: String? = nil) {
        let tags =  loops.map { $0.tag }
        let pointers = tags.withUnsafeBufferPointer { $0.baseAddress }
        _ = withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoAddPlaneSurface(pointers, tags.count, -1, $0);
        }
        surfaces.append(Surface(tag: Tag(surfaces.count + 1), name: name, loops: loops))
    }
    */
    mutating func update() { withUnsafeMutablePointer(to: &instance) { gmshModelGeoSynchronize($0) } }
    
    mutating func mesh() { withUnsafeMutablePointer(to: &instance) { gmshModelMeshGenerate(2, $0) } }
    
    mutating func build(showcase: Bool = true) {
        withUnsafeMutablePointer(to: &instance) { gmshWrite(name, $0) }
        if showcase { withUnsafeMutablePointer(to: &instance) { gmshFltkRun($0) } }
        withUnsafeMutablePointer(to: &instance) { gmshFinalize($0) }
    }
}
