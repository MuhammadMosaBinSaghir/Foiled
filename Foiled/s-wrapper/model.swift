import Foundation

protocol Structure {
    var tag: Int32 { get }
    var name: String? { get }
}

struct Point: Structure {
    let tag: Int32
    var name: String?
    let coordinate: SIMD3<Double>
}

struct Line: Structure {
    let tag: Int32
    let name: String?
    let points: [Point]
}

enum ModelErrors: Error { case undefined }

struct Model {
    let name: String
    let accuracy: Double
    private var instance: Int32
    
    var points = [Point]()
    var lines = [Line]()
    
    init(name: String, accuracy: Double) {
        var instance: Int32 = 0
        withUnsafeMutablePointer(to: &instance) { gmshInitialize(0, nil, 1, 0, $0) }
        withUnsafeMutablePointer(to: &instance) { gmshModelAdd(name, $0) }
        self.name = name
        self.accuracy = accuracy
        self.instance = instance
    }
    
    mutating func point(name: String? = nil, at vector: SIMD3<Double>) {
        _ = withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoAddPoint(vector.x, vector.y, vector.z, accuracy, -1, $0)
        }
        points.append(.init(tag: Int32(points.count + 1), name: name, coordinate: vector))
    }
    
    mutating func line(
        name: String? = nil,
        from namer: String? = nil, to named: String? = nil,
        pointer: Int32? = nil, pointed: Int32? = nil
    ) throws {
        let pointer: Point? =
        switch (namer, named, pointer, pointed) {
        case (.some, .some, _, _): points.first(where: { $0.name == namer })
        case (_, _, .some, .some): points.first(where: { $0.tag == pointer })
        default: nil
        }
        guard let pointer else { throw ModelErrors.undefined }
        let pointed: Point? =
        switch (named, pointed) {
        case (.some, _): points.first(where: { $0.name == named })
        case (_, .some): points.first(where: { $0.tag == pointed })
        default: nil
        }
        guard let pointed else { throw ModelErrors.undefined }
        _ = withUnsafeMutablePointer(to: &instance) {
            gmshModelGeoAddLine(pointer.tag, pointed.tag, -1, $0)
        }
        lines.append(.init(tag: Int32(lines.count + 1), name: name, points: [pointer, pointed]))
    }
    
    mutating func update() { withUnsafeMutablePointer(to: &instance) { gmshModelGeoSynchronize($0) } }
    
    mutating func mesh() { withUnsafeMutablePointer(to: &instance) { gmshModelMeshGenerate(2, $0) } }
    
    mutating func build(showcase: Bool = true) {
        withUnsafeMutablePointer(to: &instance) { gmshWrite(name, $0) }
        if showcase { withUnsafeMutablePointer(to: &instance) { gmshFltkRun($0) } }
        withUnsafeMutablePointer(to: &instance) { gmshFinalize($0) }
    }
}
