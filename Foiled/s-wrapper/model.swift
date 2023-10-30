import Foundation
import SwiftUI

typealias Tag = Int32

enum Intercept: String { case upside, lowerside }

enum Dimension: Tag { case second = 2, third = 3 }

enum Boundary: String { case c = "c-type", h = "h-type", o = "o-type" }

struct Transfinite {
    var label: TransfiniteLabel
    var points: Tag
    var type: TransfiniteType
    var parameter: Double
    
    enum TransfiniteLabel: String { case contour, inlet, vertical, wake }
    enum TransfiniteType: String { case beta = "Beta", bump = "Bump", progression = "Progression "}
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
        switch axis {
        case .vertical:
            abs(self.ordinate.distance(to: intercept)) < abs(point.ordinate.distance(to: intercept))
        case .horizontal:
            abs(self.abscissa.distance(to: intercept)) < abs(point.abscissa.distance(to: intercept))
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

struct Model {
    let label: String
    var instance: Tag
    var type: Boundary
    var intercept: Double = 0.25
    var contour: [Point]? = nil
    var boundary: [Point]? = nil
    
    private var points: Tag = .zero
    private var lines: Tag = .zero
    private var loops: Tag = .zero
    private var surfaces: Tag = .zero
    
    init(label: String, instance: Tag, intercept: Double = 0.25, boundary: Boundary) {
        self.label = label
        self.instance = instance
        self.type = boundary
        self.intercept = intercept
        self.contour = nil
        self.boundary = nil
        self.points = .zero
        self.lines = .zero
        self.loops = .zero
        self.surfaces = .zero
    }
    
    private func intercept(from closest: [Int], at side: Intercept, on contour: inout [Point]) {
        switch contour[closest[0]].abscissa.isEqual(to: intercept) {
        case true:
            contour[closest[0]].label = side.rawValue
        case false:
            let upside = Point(from: contour[closest[0]].interpolate(to: contour[closest[1]], at: intercept, on: .horizontal), as: contour.count, label: side.rawValue)
            contour.insert(upside, at: contour[closest[0]].abscissa < upside.abscissa ? closest[0] : closest[0] - 1)
        }
    }
    
    private func edges(of contour: inout [Point]) {
        let sorted = contour.sorted(by: { $0.abscissa < $1.abscissa} )
        guard let leading =
                contour.firstIndex(where: { $0.tag == sorted.first!.tag } )
        else { return }
        guard let trailing =
                contour.firstIndex(where: { $0.tag == sorted.last!.tag } )
        else { return }
        contour[leading].label = "leading"
        contour[trailing].label = "trailing"
        let first = leading < trailing ? 1..<leading : (trailing + 1)..<leading
        let second = leading < trailing ?
        (leading + 1)..<trailing : (leading + 1)..<contour.count - 1
        let closest = (upside: first.sorted(by: { contour[$0].closer(than: contour[$1], to: intercept, on: .horizontal) } ), lowerside: second.sorted(by: { contour[$0].closer(than: contour[$1], to: intercept, on: .horizontal) } )
        )
        intercept(from: closest.upside, at: .upside, on: &contour)
        intercept(from: closest.lowerside, at: .lowerside, on: &contour)
        switch contour.first!.ordinate == contour.last?.ordinate {
        case true: break
        case false:
            contour[trailing].label = nil
            contour.append(Point(abscissa: 1, ordinate: 0, as: contour.count + 1, label: "trailing"))
        }
        for index in contour.indices { contour[index].tag = Int32(index + 1) }
    }
    
    private mutating func points(from contour: [Point], on plane: Double, precision: Double) {
            points += Tag(contour.count)
        _ = contour.map { point in
            withUnsafeMutablePointer(to: &instance) {
                gmshModelGeoAddPoint(point.abscissa, point.ordinate, plane, precision, -1, $0)
            }
        }
    }
    
    private func find(edge: String, on boundary: [Point]?) -> Point? {
        guard let boundary else { return nil }
        guard let edge = boundary.first(where: {$0.label == edge })
        else { return nil }
        return edge
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
            gmshModelGeoMeshSetTransfiniteCurve(line, condition.points, condition.type.rawValue, condition.parameter, $0)
        }
    }
        
    private mutating func transfinite(surface: Tag, boundary points: [Point]) {
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
    
    mutating func launch() {
        withUnsafeMutablePointer(to: &instance) { gmshInitialize(0, nil, 1, 0, $0) }
        withUnsafeMutablePointer(to: &instance) { gmshModelAdd(label, $0) }
    }
    
    mutating private func update() {
        withUnsafeMutablePointer(to: &instance) { gmshModelGeoSynchronize($0) }
    }
    
    mutating func contour(from coordinates: [CGPoint], on plane: Double, precision: Double) {
        guard !coordinates.isEmpty else { return }
        guard (0.0...0.5).contains(intercept) else { return }
        var contour = [Point]()
        contour = coordinates.opened().enumerated().map {
            Point(from: $0.element, as: $0.offset + 1)
        }
        edges(of: &contour)
        self.contour = contour
        points(from: contour, on: plane, precision: precision)
        splines()
    }
    
    mutating func boundary(radius: Double = 10, on plane: Double, precision: Double) {
        guard let upside = find(edge: "upside", on: contour) else { return }
        guard let lowerside = find(edge: "lowerside", on: contour) else { return }
        guard let leading = find(edge: "leading", on: contour) else { return }
        guard let trailing = find(edge: "trailing", on: contour) else { return }
        
        let boundary: [Point] = switch self.type {
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
        points(from: boundary, on: plane, precision: precision)
        lines(tags: boundary.map { $0.tag })
        self.boundary = boundary
        switch self.type {
        case .c:
            arc(from: boundary.last, to: boundary.first, center: leading)
            guard let firstmost = find(edge: "firstmost", on: boundary) else { return }
            guard let lowermost = find(edge: "lowermost", on: boundary) else { return }
            guard let rightmost = find(edge: "rightmost", on: boundary) else { return }
            guard let upmost = find(edge: "upmost", on: boundary) else { return }
            guard let lastmost = find(edge: "lastmost", on: boundary) else { return }
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
        default: break
        }
    }
    
    mutating func structure(conditions: [Transfinite]) {
        switch type {
        case .c:
            guard let contour = conditions.first(where: { $0.label == .contour } )
            else { return }
            guard let inlet = conditions.first(where: { $0.label == .inlet } )
            else { return }
            guard let vertical = conditions.first(where: { $0.label == .vertical } )
            else { return }
            guard let wake = conditions.first(where: { $0.label == .wake } )
            else { return }
            let contours: [Tag] = [1, 3, 4, 9]
            let inlets: [Tag] = [10, 2]
            let verticals: [Tag] = [6, 7, 11, 12, 14, 15]
            let wakes: [Tag] = [5, 8, 13]
            _ = contours.map { transfinite(line: $0, condition: contour) }
            _ = inlets.map { transfinite(line: $0, condition: inlet) }
            _ = verticals.map { transfinite(line: $0, condition: vertical) }
            _ = wakes.map { transfinite(line: $0, condition: wake) }
            _ = (1...5).map { transfinite(surface: $0, boundary: []) }
            _ = (1...5).map { recombine($0, dimension: .second) }
        default: return
        }
    }
    
    mutating func mesh(dimension: Dimension, showcase: Bool = true) {
        self.update()
        withUnsafeMutablePointer(to: &instance) {
            gmshModelMeshGenerate(dimension.rawValue, $0)
        }
        withUnsafeMutablePointer(to: &instance) { gmshWrite(label, $0) }
        if showcase { withUnsafeMutablePointer(to: &instance) { gmshFltkRun($0) } }
        withUnsafeMutablePointer(to: &instance) { gmshFinalize($0) }
    }
}

