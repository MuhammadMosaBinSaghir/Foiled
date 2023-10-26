import Foundation

enum ImportingError: Error {
    case empty, format
}

enum ExportingError: Error {
    case parsing
}

typealias Contours = Set<Contour>

extension Contour: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(dot)
        hasher.combine(options)
        hasher.combine(points)
    }
    
    static func == (lhs: Contour, rhs: Contour) -> Bool {
        lhs.name == rhs.name && lhs.dot == rhs.dot && lhs.options == rhs.options && rhs.points == lhs.points
    }
}

extension Set where Element == Contour {
    static func build() -> Contours {
        guard let url = Bundle.main.url(forResource: "library", withExtension: "json")
        else { return [] }
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let library = try? JSONDecoder().decode(Set<Contour>.self, from: data)
        else { return [] }
        return library
    }
    
    func write(to directory: URL, as file: String) throws {
        guard var library = "[".data(using: .utf8) else { throw ExportingError.parsing }
        let parsed: [Bool] = self.map { contour in
            var text = """
            {
                "name": "\(contour.name)",
                "coordinates": [\n
            """
            for i in 0...contour.coordinates.count-2 {
                text.append("       {\"x\": \(contour.coordinates[i].x), \"y\": \(contour.coordinates[i].y)},\n")
            }
            guard let last = contour.coordinates.last else { return false }
            text.append("       {\"x\": \(last.x), \"y\": \(last.y)}\n")
            text.append("   ]\n")
            text.append("},\n")
            guard let data = text.data(using: .utf8) else { return false }
            library.append(data)
            return true
        }
        guard parsed.contains(true) else { throw ExportingError.parsing }
        guard var library = String(data: library, encoding: .utf8)
        else { throw ExportingError.parsing }
        library.removeLast(2)
        library.append("]")
        guard let library = library.data(using: .utf8)
        else { throw ExportingError.parsing }
        try? library.write(to: directory.appendingPathComponent(file))
    }
    
    static func extract(from directory: URL, format: String) throws -> Contours {
        switch format {
        case ".dat":
            guard let contents: [URL] = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ) else { throw ImportingError.empty }
            let contours: [Contour?] = contents.map { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                guard let text = String(data: data, encoding: .utf8) else { return nil }
                let lines = text.components(separatedBy: "\n").dropLast()
                guard var name = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() else { return nil }
                name.replace(/\s{2,}/, with: "")
                let points: [CGPoint?] = lines.dropFirst().map { line in
                    let point = line.split(separator: /\s+/)
                    guard !point.isEmpty else { return nil }
                    guard let x = Double(point[0]) else { return nil }
                    guard let y = Double(point[1]) else { return nil }
                    return CGPoint(x: CGFloat(x), y: CGFloat(y))
                }
                let coordinates = points.compactMap { $0 }
                return Contour(name: String(name), coordinates: coordinates)
            }
            guard !contours.isEmpty else { throw ImportingError.empty }
            return Set(contours.compactMap { $0 })
        default: throw ImportingError.format
        }
    }
}
