import Foundation
import SwiftUI

typealias Tag = Int32

enum Intercept: String { case upside, lowerside }

enum Dimension: Tag { case first = 1, second = 2, third = 3 }

enum TransfiniteSector { case inner, outer }
enum TransfiniteLabel: String { case contour, inlet, wake, walls }
enum TransfiniteType: String { case beta = "Beta", bump = "Bump", progression = "Progression "}

struct Transfinite {
    var label: TransfiniteLabel
    var accuracy: Double
    var type: TransfiniteType
    var stretch: Double
    
    var points: Tag {
        guard accuracy > .zero else { return 1 }
        return Tag(1/accuracy)
    }
    
    mutating func update(_ accuracy: Double, _ stretch: Double) {
        self.accuracy = accuracy
        self.stretch = stretch
    }
    
    func reversed() -> Self {
        return Self.init(label: self.label, accuracy: self.accuracy, type: self.type, stretch: -1*self.stretch)
    }
    
    func stretch(to sector: TransfiniteSector, reversed: Bool = false) -> Self {
        let factor: Double = switch reversed { case true: -1; case false: 1 }
        return Self.init(label: self.label, accuracy: self.accuracy, type: self.type, stretch: sector == .inner ? factor*self.stretch : 20*factor*self.stretch)
    }
    
    func bump(reversed: Bool = false) -> Self {
        let factor: Double = switch reversed { case true: -1; case false: 1 }
        return Self.init(label: self.label, accuracy: self.accuracy, type: .bump, stretch: factor*self.stretch/4.75)
    }
}

enum MeshType: String { case c = "c-type", h = "h-type", o = "o-type" }

enum MeshFormat: CaseIterable, LosslessStringConvertible {
    case cgns, msh, stl, vtk, su2
    
    var description: String {
        switch self {
        case .cgns: "cgns"
        case .msh: "msh"
        case .stl: "stl"
        case .vtk: "vtk"
        case .su2: "su2"
        }
    }
    
    init?(_ description: String) {
        let format: Self? = switch description {
        case "cgns": .cgns
        case "msh": .msh
        case "stl": .stl
        case "vtk": .vtk
        case "su2": .su2
        default: nil
        }
        guard let formatted = format else { return nil }
        self = formatted
    }
}

struct Point {
    var tag: Int32
    var label: String?
    let abscissa: Double
    let ordinate: Double
    
    init(from coordinate: CGPoint, as index: Int, label: String? = nil) {
        self.label = label
        self.tag = Tag(index)
        self.abscissa = coordinate.x
        self.ordinate = coordinate.y
    }
    
    init(abscissa: Double, ordinate: Double, as index: Tag, label: String? = nil) {
        self.label = label
        self.tag = index
        self.abscissa = abscissa
        self.ordinate = ordinate
    }
    
    init(abscissa: Double, ordinate: Double, as index: Int, label: String? = nil) {
        self.label = label
        self.tag = Tag(index)
        self.abscissa = abscissa
        self.ordinate = ordinate
    }
    
    func closer(than point: Self, to intercept: Double, on axis: Axis) -> Bool {
        return switch axis {
        case .vertical:
            abs(self.ordinate.distance(to: intercept)) < abs(point.ordinate.distance(to: intercept))
        case .horizontal:
            abs(self.abscissa.distance(to: intercept)) <= abs(point.abscissa.distance(to: intercept))
        }
    }
    
    func interpolate(to point: Self, at intercept: Double, on axis: Axis) -> CGPoint {
        let m = (point.ordinate - self.ordinate)/(point.abscissa - self.abscissa)
        let b = self.ordinate - m*self.abscissa
        return switch axis {
        case .vertical: CGPoint(x: (intercept - b)/m, y: intercept)
        case .horizontal: CGPoint(x: intercept, y: m*intercept + b)
        }
    }
}

struct Boundary {
    var accuracy: Double
    var plane: Double
    var radius: Double
    var points: [Point]?
    
    var contour: Transfinite
    var inlet: Transfinite
    var wake: Transfinite
    var walls: Transfinite
    
    init(accuracy: Double = 1, plane: Double = .zero, radius: Double = 1, points: [Point]? = nil) {
        self.accuracy = accuracy
        self.plane = plane
        self.radius = radius
        self.points = points
        self.contour = .init(label: .contour, accuracy: 0.1, type: .bump, stretch: 1)
        self.inlet = .init(label: .inlet, accuracy: 0.1, type: .progression, stretch: 1)
        self.wake = .init(label: .wake, accuracy: 0.1, type: .progression, stretch: 1)
        self.walls = .init(label: .walls, accuracy: 0.1, type: .progression, stretch: 1)
    }
    
    mutating func radius(_ radius: Double) { self.radius = radius }
    mutating func plane(_ plane: Double) { self.plane = plane }
    mutating func accuracy(_ accuracy: Double) { self.accuracy = accuracy }
    mutating func points(from points: [Point]) { self.points = points }
    mutating func contour(accuracy: Double, stretch: Double) {
        contour.update(accuracy, stretch)
        print(contour)
    }
    mutating func inlet(accuracy: Double, stretch: Double) {
        inlet.update(accuracy, stretch)
    }
    mutating func walls(accuracy: Double, stretch: Double) {
        walls.update(accuracy, stretch)
    }
    mutating func wake(accuracy: Double, stretch: Double) { wake.update(accuracy, stretch) }
}

struct Model {
    let label: String
    var instance: Tag
    var type: MeshType
    var boundary: Boundary
    var intercept: Double = 0.175
    var contour: [Point]? = nil
    
    private var points: Tag = .zero
    private var lines: Tag = .zero
    private var loops: Tag = .zero
    private var surfaces: Tag = .zero
    private var groups: Tag = .zero
    
    init(label: String, instance: Tag = 1, intercept: Double = 0.175, type: MeshType = .c) {
        self.label = label
        self.instance = instance
        self.type = type
        self.intercept = intercept
        self.contour = nil
        self.points = .zero
        self.lines = .zero
        self.loops = .zero
        self.surfaces = .zero
        self.groups = .zero
        self.boundary = Boundary.init()
        self.launch()
    }
    
    mutating private func launch() {
        withUnsafeMutablePointer(to: &instance) { gmshInitialize(0, nil, 1, 0, $0) }
        withUnsafeMutablePointer(to: &instance) { gmshModelAdd(label, $0) }
    }
    
    private func intercept(from closest: [Int], at side: Intercept, on contour: inout [Point]) {
        switch contour[closest[0]].abscissa.isEqual(to: intercept) {
        case true:
            contour[closest[0]].label = side.rawValue
        case false:
            let interpolated = contour[closest[0]].interpolate(to: contour[closest[1]], at: intercept, on: .horizontal)
            let point = Point(from: interpolated, as: contour.count + 1, label: side.rawValue)
            switch side {
            case .upside:  contour.insert(point, at: closest[0])
            case .lowerside:  contour.insert(point, at: closest[0] + 1)
            }
        }
    }
    
    private func edges(of contour: inout [Point]) {
        let sorted = contour.sorted(by: { $0.abscissa < $1.abscissa} )
        guard let leading = contour.firstIndex(where: { $0.tag == sorted.first!.tag } )
        else { return }
        guard let trailing = contour.firstIndex(where: { $0.tag == sorted.last!.tag } )
        else { return }
        contour[leading].label = "leading"
        contour[trailing].label = "trailing"
        let first = leading < trailing ? 1..<leading : (trailing + 1)..<leading
        var closest = first.sorted(by: { contour[$0].closer(than: contour[$1], to: intercept, on: .horizontal) } )
        intercept(from: closest, at: .upside, on: &contour)
        let second = leading < trailing ?
        (leading + 2)..<(trailing + 1) : (leading + 2)..<contour.count - 1
        closest = second.sorted(by: { contour[$0].closer(than: contour[$1], to: intercept, on: .horizontal) })
        intercept(from: closest, at: .lowerside, on: &contour)
        switch contour.first!.ordinate == contour.last?.ordinate {
        case true: break
        case false:
            contour[trailing].label = nil
            contour.append(Point(abscissa: 1, ordinate: 0, as: contour.count + 1, label: "trailing"))
        }
        for index in contour.indices { contour[index].tag = Int32(index + 1) }
    }
    
    private func find(edge: String, on boundary: [Point]?) -> Point? {
        guard let boundary else { return nil }
        guard let edge = boundary.first(where: {$0.label == edge })
        else { return nil }
        return edge
    }
    
    mutating private func update() {
        withUnsafeMutablePointer(to: &instance) { gmshModelGeoSynchronize($0) }
    }
    
    private mutating func points(from contour: [Point], on plane: Double, accuracy: Double) {
            points += Tag(contour.count)
        _ = contour.map { point in
            withUnsafeMutablePointer(to: &instance) {
                gmshModelGeoAddPoint(point.abscissa, point.ordinate, plane, accuracy, -1, $0)
            }
        }
    }
    
    private mutating func arc(from beginning: Point?, to end: Point?, center: Point) {
        guard let beginning else { return }
        guard let end else { return }
        lines.increment()
        _ = withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoAddCircleArc(beginning.tag, center.tag, end.tag, lines, 0, 0, 0, $0)
        }
    }
    
    private mutating func line(from beginning: Tag, to end: Tag) {
        lines.increment()
        _ = withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoAddLine(beginning, end, lines, $0)
        }
    }
    
    private mutating func lines(tags: [Tag]) {
        _ = (tags[0]...tags.beforeLast(1)).map { tag in
            line(from: tag, to: tag + 1)
        }
    }
        
    private mutating func spline(tags: [Tag]) {
        lines.increment()
        let pointers = tags.withUnsafeBufferPointer { $0.baseAddress }
        _ = withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoAddBSpline(pointers, tags.count, lines, $0)
        }
    }
    
    private mutating func loop(over tags: [Tag]) {
        loops.increment()
        let pointers = tags.withUnsafeBufferPointer { $0.baseAddress }
        _ = withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoAddCurveLoop(pointers, tags.count, loops, 0, $0)
        }
    }
    
    private mutating func surface(from tags: [Tag]) {
        surfaces.increment()
        let pointers = tags.withUnsafeBufferPointer { $0.baseAddress }
        _ = withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoAddPlaneSurface(pointers, tags.count, surfaces, $0)
        }
    }
 
    private mutating func splines() {
        guard let upmost = find(edge: "upside", on: contour) else { return }
        guard let lowermost = find(edge: "lowerside", on: contour) else { return }
        guard let trailing = find(edge: "trailing", on: contour) else { return }
        guard let contour = self.contour else { return }
        var foremost = (contour[0].tag...upmost.tag).map { $0 }
        foremost.insert(trailing.tag, at: 0)
        spline(tags: foremost)
        spline(tags: (upmost.tag...lowermost.tag).map { $0 })
        spline(tags: (lowermost.tag...trailing.tag).map { $0 })
    }

    private mutating func transfinite(line: Tag, condition: Transfinite) {
        withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoMeshSetTransfiniteCurve(line, condition.points, condition.type.rawValue, condition.stretch, $0)
        }
    }
        
    private mutating func transfinite(surface: Tag, edges points: [Point]) {
        let tags = points.map { $0.tag }
        let pointers = tags.withUnsafeBufferPointer { $0.baseAddress }
        withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoMeshSetTransfiniteSurface(surface, "Left", pointers, points.count, $0)
        }
    }
    
    private mutating func recombine(_ surface: Tag, dimension: Dimension) {
        withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoMeshSetRecombine(dimension.rawValue, surface, 45.0, $0)
        }
    }
    
    mutating private func group(tags: [Tag], as label: String, dimension: Dimension) {
        groups.increment()
        let pointer = tags.withUnsafeBufferPointer { $0.baseAddress }
        _ = withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoAddPhysicalGroup(dimension.rawValue, pointer, tags.count, groups, label, $0)
        }
    }
    
    mutating private func save() {
        withUnsafeMutablePointer(to: &instance) {
            gmshOptionSetNumber("Mesh.SaveAll", 1, $0)
        }
    }
    
    mutating func contour(from coordinates: [CGPoint], on plane: Double, accuracy: Double) {
        guard !coordinates.isEmpty else { return }
        guard (0.0...0.5).contains(intercept) else { return }
        var contour = [Point]()
        contour = coordinates.opened().enumerated().map {
            Point(from: $0.element, as: $0.offset + 1)
        }
        edges(of: &contour)
        self.contour = contour
        points(from: contour, on: plane, accuracy: accuracy)
        splines()
    }
    
    mutating func bound() {
        let radius = boundary.radius
        let plane = boundary.plane
        let accuracy = boundary.accuracy
        
        guard let upside = find(edge: "upside", on: contour) else { return }
        guard let lowerside = find(edge: "lowerside", on: contour) else { return }
        guard let leading = find(edge: "leading", on: contour) else { return }
        guard let trailing = find(edge: "trailing", on: contour) else { return }
        
        let definition: [Point] = switch self.type {
        case .c: [
            Point(abscissa: leading.abscissa, ordinate: -0.5*radius, as: points + 1, label: "firstmost"),
            Point(abscissa: trailing.abscissa, ordinate: -0.5*radius, as: points + 2, label: "lowermost"),
            Point(abscissa: trailing.abscissa + radius, ordinate: -0.5*radius, as: points + 3),
            Point(abscissa: trailing.abscissa + radius, ordinate: trailing.ordinate, as: points + 4, label: "rightmost"),
            Point(abscissa: trailing.abscissa + radius, ordinate: 0.5*radius, as: points + 5),
            Point(abscissa: trailing.abscissa, ordinate: 0.5*radius, as: points + 6, label: "upmost"),
            Point(abscissa: leading.abscissa, ordinate: 0.5*radius, as: points + 7, label: "lastmost")
        ]
        default: []
        }
        points(from: definition, on: plane, accuracy: accuracy)
        lines(tags: definition.map { $0.tag })
        self.boundary.points(from: definition)
        switch self.type {
        case .c:
            arc(from: definition.last, to: definition.first, center: leading)
            guard let firstmost = find(edge: "firstmost", on: definition) else { return }
            guard let lowermost = find(edge: "lowermost", on: definition) else { return }
            guard let rightmost = find(edge: "rightmost", on: definition) else { return }
            guard let upmost = find(edge: "upmost", on: definition) else { return }
            guard let lastmost = find(edge: "lastmost", on: definition) else { return }
            line(from: firstmost.tag, to: lowerside.tag)
            line(from: trailing.tag, to: lowermost.tag)
            line(from: rightmost.tag, to: trailing.tag)
            line(from: upmost.tag, to: trailing.tag)
            line(from: upside.tag, to: lastmost.tag)
            loop(over: [11, -2, 15, 10])
            loop(over: [11, 3, 12, -4])
            loop(over: [12, 5, 6, 13])
            loop(over: [7, 8, 14, -13])
            loop(over: [14, 1, 15, -9])
            _ = (1...5).map { surface(from: [$0]) }
            save()
        default: break
        }
    }
    
    mutating func structure() {
        switch type {
        case .c:
            _ = [1, 3].map { transfinite(line: $0, condition: boundary.contour.stretch(to: .inner))}
            _ = [9, 4].map { transfinite(line: $0, condition: boundary.contour.stretch(to: .outer))}
            _ = [2, 10].map { transfinite(line: $0, condition: boundary.inlet) }
            transfinite(line: 13, condition: boundary.wake)
            transfinite(line: 8, condition: boundary.wake.bump())
            transfinite(line: 5, condition: boundary.wake.bump(reversed: true))
            _ = [15, 7].map { transfinite(line: $0, condition: boundary.walls.reversed())}
            _ = [6, 11].map { transfinite(line: $0, condition: boundary.walls)}
            transfinite(line: 14, condition: boundary.walls)
            transfinite(line: 12, condition: boundary.walls.reversed())
            _ = (1...5).map { transfinite(surface: $0, edges: []) }
            _ = (1...5).map { recombine($0, dimension: .second) }
            let farfield: [Tag] = [4, 5, 6, 7, 8, 9, 10]
            let wall: [Tag] = [1, 2, 3]
            group(tags: farfield, as: "farfield", dimension: .first)
            group(tags: wall, as: "wall", dimension: .first)
        default: return
        }
    }

    mutating func mesh(dimension: Dimension, format: MeshFormat = .msh, showcase: Bool = false) {
        self.update()
        withUnsafeMutablePointer(to: &instance) {
            gmshModelMeshGenerate(dimension.rawValue, $0)
        }
        withUnsafeMutablePointer(to: &instance) { gmshWrite(label + ".\(format)", $0) }
        if showcase { withUnsafeMutablePointer(to: &instance) { gmshFltkRun($0) } }
        withUnsafeMutablePointer(to: &instance) { gmshFinalize($0) }
    }
}

