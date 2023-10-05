import SwiftUI
import RegexBuilder

struct Importer: View {
    @State private var show = false
    let manager = FileManager.default
    let seperator = Regex { OneOrMore(.whitespace) }
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    var body: some View {
        Button {
            show.toggle()
        } label: {
            Label("Airfoils", systemImage: "square.and.arrow.down")
        }
        .fileImporter(
            isPresented: $show,
            allowedContentTypes: [.directory]) { result in
                process(result)
            }
    }
    
    private func process(_ result: Result<URL, Error>) {
        switch result {
        case .success(let directory):
            let access = directory.startAccessingSecurityScopedResource()
            if !access { return }
            let airfoils = read(directory)
            let library = documents.appendingPathComponent("library.swift")
            write(airfoils, to: library)
            directory.stopAccessingSecurityScopedResource()
        case .failure(let error): print(error)
        }
    }
    
    private func read(_ directory: URL) -> [Airfoil] {
        var airfoils = [Airfoil]()
        do {
            let contents = try manager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            for content in contents {
                let data = try Data(contentsOf: content)
                guard let text = String(data: data, encoding: .utf8) else { break }
                let lines = text.components(separatedBy: "\n").dropLast()
                guard let name = lines.first?.trimmingCharacters(in: .newlines) else { break }
                let points: [CGPoint?] = lines.dropFirst().map { line in
                    let point = line.split(separator: seperator)
                    if point.isEmpty { return nil }
                    guard let x = Double(point[0]) else { return nil }
                    guard let y = Double(point[1]) else { return nil }
                    return CGPoint(x: CGFloat(x), y: CGFloat(y))
                }
                let coordinates = points.compactMap { $0 }
                airfoils.append(Airfoil(name: String(name), coordinates: coordinates))
            }
        } catch {
            print("Error accessing directory contents: \(error)")
        }
        return airfoils
    }
    
    private func write(_ airfoils: [Airfoil], to url: URL) {
        print(airfoils.count)
        guard var library = "".data(using: .utf8) else { return }
        for airfoil in airfoils {
            var text = """
            Airfoil(
                name: "\(airfoil.name)",
                coordinates: [\n
            """
            for j in 0...airfoil.coordinates.count-1 {
                text.append("       CGPoint(x: \(airfoil.coordinates[j].x), y: \(airfoil.coordinates[j].y)),\n")
            }
            guard let last = airfoil.coordinates.last else { break }
            text.append("       CGPoint(x: \(last.x), y: \(last.y))\n")
            text.append("   ]\n")
            text.append("),\n")
            guard let data = text.data(using: .utf8) else { break }
            library.append(data)
        }
        do {
            try library.write(to: url)
            print("Successfully wrote to file!")
        } catch {
            print("Error writing to file: \(error)")
        }
    }
}
