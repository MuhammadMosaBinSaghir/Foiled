import Foundation
import SwiftUI

//Leading Edge should be at (0, 0) and trailing should be at (1, 0)!

typealias Tag = Int32

enum Intercept: String { case upside, lowerside }

enum Dimension: Tag { case second = 2, third = 3 }

struct Point {
    var tag: Int32
    var type: String?
    let abscissa: Double
    let ordinate: Double
    
    init(from coordinate: CGPoint, as index: Int, type: String? = nil) {
        self.type = type
        self.tag = Tag(index)
        self.abscissa = coordinate.x
        self.ordinate = coordinate.y
    }
    
    init(abscissa: Double, ordinate: Double, as index: Int, type: String? = nil) {
        self.type = type
        self.tag = Tag(index)
        self.abscissa = abscissa
        self.ordinate = ordinate
    }
    
    func isAt(x: Double, y: Double) -> Bool {
        self.abscissa == x && self.ordinate == y
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

enum Geometry {
    case lines
    case circle
    case loop
    case surface
    
    func build(from start: Tag, to end: Tag, center: Tag, into instance: inout Tag) {
        guard self == .circle else { return }
        _ = withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoAddCircleArc(start, center, end, -1, 0, 0, 0, $0)
        }
    }
    
    func build(from coordinates: [CGPoint], into instance: inout Tag, tags: ClosedRange<Tag>, accuracy: Double, plane: Double, closed: Bool = true) {
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
                switch (index == tags.upperBound, closed) {
                case (true, true): gmshModelGeoAddLine(index, tags.lowerBound, -1, $0)
                default: gmshModelGeoAddLine(index, index + 1, -1, $0)
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
    let label: String
    var instance: Tag
    var contour: [Point]? = nil
    var intercept: Double = 0.175
    
    private var points: Tag = .zero
    private var lines: Tag = .zero
    private var loops: Tag = .zero
    private var surfaces: Tag = .zero
    
    init(label: String, instance: Tag, intercept: Double = 0.25) {
        self.label = label
        self.instance = instance
        self.intercept = intercept
        self.contour = nil
        self.points = .zero
        self.lines = .zero
        self.loops = .zero
        self.surfaces = .zero
    }
    
    private func intercept(from closest: [Int], at side: Intercept, on contour: inout [Point]) {
        switch contour[closest[0]].abscissa.isEqual(to: intercept) {
        case true:
            contour[closest[0]].type = side.rawValue
        case false:
            let upside = Point(from: contour[closest[0]].interpolate(to: contour[closest[1]], at: intercept, on: .horizontal), as: contour.count, type: side.rawValue)
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
        contour[leading].type = "leading"
        contour[trailing].type = "trailing"
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
            contour[trailing].type = nil
            contour.append(Point(abscissa: 1, ordinate: 0, as: contour.count + 1, type: "trailing"))
        }
        for index in contour.indices { contour[index].tag = Int32(index + 1) }
    }
    
    private mutating func points(on plane: Double, precision: Double) {
        guard let contour = self.contour else { return }
        _ = contour.map { point in
            withUnsafeMutablePointer(to: &instance) {
                gmshModelGeoAddPoint(point.abscissa, point.ordinate, plane, precision, -1, $0)
            }
        }
    }
    
    private func find(edge: String) -> Point? {
        guard let contour = self.contour else { return nil }
        guard let edge = contour.first(where: {$0.type == edge })
        else { return nil }
        return edge
    }
    
    private mutating func spline(tags: [Tag]) {
        lines.increment()
        let pointers = tags.withUnsafeBufferPointer { $0.baseAddress }
        _ = withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoAddBSpline(pointers, tags.count, lines, $0)
        }
    }
    
    private mutating func splines() {
        guard let upmost = find(edge: "upside") else { return }
        guard let lowermost = find(edge: "lowerside") else { return }
        guard let leading = find(edge: "leading") else { return }
        guard let trailing = find(edge: "trailing") else { return }
        guard let contour = self.contour else { return }
        var foremost = (contour[0].tag...upmost.tag).map { $0 }
        foremost.insert(trailing.tag, at: 0)
        spline(tags: foremost)
        spline(tags: (upmost.tag...leading.tag).map { $0 })
        spline(tags: (leading.tag...lowermost.tag).map { $0 })
        spline(tags: (lowermost.tag...trailing.tag).map { $0 })
    }

    mutating private func update() {
        withUnsafeMutablePointer(to: &instance) { gmshModelGeoSynchronize($0) }
    }
    /*
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
            CGPoint(x: leading, y: top + radius),
            CGPoint(x: leading, y: 0.5*(top + bottom))
        ]
        let tags = Tag(coordinates.count+1)...Tag(coordinates.count + points.count - 2)
        Geometry.lines.build(
            from: points,
            into: &instance,
            tags: tags,
            accuracy: accuracy.boundary,
            plane: plane,
            closed: false
        )
        Geometry.circle.build(
            from: Tag(coordinates.count + points.count - 1),
            to: Tag(coordinates.count + 1),
            center: Tag(coordinates.count + points.count),
            into: &instance
        )
        let circular = Tag(coordinates.count+1)...Tag(coordinates.count + points.count - 1)
        Geometry.loop.build(from: circular, into: &instance)
    }
    */
    /*
        let curves = (1...lines).map { line in
            withUnsafeMutablePointer(to: &instance) {
                gmshModelGeoMeshSetTransfiniteCurve(line, 100, "Progression", 1.0, $0);
            }
            return line
        }
        var pointers = curves.withUnsafeBufferPointer { $0.baseAddress }
        _ = withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoAddCurveLoop(pointers, curves.count, -1, 0, $0)
        }
        loops.increment()
        let loopz: [Tag] = [1]
        pointers = loopz.withUnsafeBufferPointer { $0.baseAddress }
        _ = withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoAddPlaneSurface(pointers, 1, 1, $0)
        }
        surfaces.increment()
        let tags: [Tag] = [trailing.tag, upmost.tag, leading.tag, lowermost.tag]
        pointers = tags.withUnsafeBufferPointer { $0.baseAddress }
        withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoMeshSetTransfiniteSurface(1, "Left", pointers, tags.count, $0);
        }
        withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoMeshSetRecombine(2, 1, 45.0, $0);
        }
    }
    */
    
    mutating func launch() {
        withUnsafeMutablePointer(to: &instance) { gmshInitialize(0, nil, 1, 0, $0) }
        withUnsafeMutablePointer(to: &instance) { gmshModelAdd(label, $0) }
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
        self.points = Tag(contour.count)
        points(on: plane, precision: precision)
        splines()
    }
    
    mutating func mesh(dimension: Dimension, showcase: Bool = true) {
        self.update()
        withUnsafeMutablePointer(to: &instance) { gmshModelMeshGenerate(dimension.rawValue, $0) }
        withUnsafeMutablePointer(to: &instance) { gmshWrite(label, $0) }
        if showcase { withUnsafeMutablePointer(to: &instance) { gmshFltkRun($0) } }
        withUnsafeMutablePointer(to: &instance) { gmshFinalize($0) }
    }
}

