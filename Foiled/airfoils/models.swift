import SwiftUI

let library = Contours.build()

enum Contouring {
    case condensed, dotted, streamlined
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

struct Bimp: Hashable {
    var location: CGFloat
    var radius: CGFloat
    var points: Int
    
    private func locate(at location: CGFloat, between P1: CGPoint, and P2: CGPoint) -> CGPoint {
        CGPoint(
            x: location,
            y: (location*(P1.y - P2.y) + P1.x*P2.y - P2.x*P1.y)/(P1.x - P2.x)
        )
    }
    
    func dent(_ contour: [CGPoint]) -> [CGPoint] {
        guard !contour.isEmpty else { return [] }
        guard let cord = contour.max(by: {$0.x < $1.x})?.x else { return [] }
        let relative = location*cord
        guard let index = contour.firstIndex(where: { $0.x <= relative } )
        else { return [] }
        let center = contour[index].x == relative ?
        contour[index] :
        locate(at: relative, between: contour[index], and: contour[index - 1])
        let step: CGFloat = 2 * .pi / Double(points + 1)
        var bump = [CGPoint]()
        for radian in stride(from: CGFloat.zero, through: 2 * .pi, by: step) {
            bump.append(
                CGPoint(
                    x: center.x + radius*cord*cos(radian),
                    y: center.y + radius*cord*sin(radian)
                )
            )
        }
        return bump
    }
}

struct Contour: Decodable, Shape {
    var name: String
    var coordinates: [CGPoint]
    var options: Set<Contouring>
    var dot: CGFloat
    var bumps: Set<Bimp>
    
    var thickness: Thickness {
        let ordered = coordinates.sorted(by: {$0.y < $1.y})
        return Thickness(bottom: ordered.first?.y ?? .zero, top: ordered.last?.y ?? .zero)
    }
    
    private enum CodingKeys: String, CodingKey {
        case name
        case coordinates
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var confined = coordinates.map { confine(coordinate: $0, in: rect) }
        var spline: [CGPoint] = switch
        (options.contains(.condensed), options.contains(.streamlined)) {
        case (true, false): confined.spline(by: 4, type: .centripetal)
        case (false, true): confined.streamlined(tolerance: 0.1)
        default: confined
        }
        path.move(to: spline.first ?? CGPoint(x: rect.midX, y: rect.maxY))
        _ = spline.map { path.addLine(to: $0) }
        guard !bumps.isEmpty else { return path }
        var bumps = bumps.map { $0.dent(spline) }
        let circles = bumps.map { bump in
            Path { path in
                path.move(to: bump[0])
                _ = bump.map { point in
                    path.addLine(to: point)
                }
            }
        }
        let intersections = circles.map { path.intersection($0).coordinates() }
        for i in bumps.indices {
            bumps[i].removeAll { point in
                intersections[i].contains(where: {$0.roughlyEquals(point, tolerance: 0.01)})
            }
            bumps[i].removeFirst()
        }
        var camber = [CGPoint]()
        if name != "NACA 0012" {
            for i in 0..<(spline.count-2)/2 {
                let j = spline.count - 2 - i
                if (spline[i].x == spline[j].x) {
                    camber.append(CGPoint(x: spline[i].x, y: 0.5*(spline[i].y - spline[j].y) + spline[j].y))
                }
            }
        } else {
            guard let y = spline.first(where: {$0.x == 0} )?.y else { return path }
            for i in 0..<(spline.count-2)/2 {
                camber.append(CGPoint(x: spline[i].x, y: y))
            }
        }
        guard !camber.isEmpty else { return path }
        let original = spline
        for i in bumps.indices {
            let j = original.firstIndex(where: { $0.x <= bumps[i][0].x} )!
            let P1 = camber[j]
            let P2 = camber[j+1]
            var keep = [CGPoint]()
            for m in bumps[i].indices {
                let point = CGPoint(
                    x: bumps[i][m].x,
                    y: (bumps[i][m].x*(P1.y - P2.y) + P1.x*P2.y - P2.x*P1.y)/(P1.x - P2.x)
                )
                if (point.y > bumps[i][m].y) { keep.append(bumps[i][m]) }
            }
            bumps[i] = keep
            guard let first = bumps[i].first else { continue }
            guard let last = bumps[i].last else { continue }
            var upper = [CGPoint](repeating: .zero, count: (original.count-2)/2 + 1)
            for i in 0...(original.count-2)/2 {
                upper[i] = original[i]
            }
            guard let k = upper.firstIndex(where: { $0.x < first.x}) else { continue }
            guard let l = upper.lastIndex(where: { $0.x > last.x}) else { continue }
            spline.removeSubrange(l+1..<k)
            let n = spline.firstIndex(where: { $0.x <= bumps[i][0].x} )!
            spline.insert(contentsOf: bumps[i].reversed(), at: n)
        }
        var bumpy = Path { path in
            path.move(to: spline[0])
            _ = spline.map { point in
                path.addLine(to: point)
            }
        }
        guard options.contains(.dotted) else { return bumpy }
        spline.removeLast()
        let size = dot*rect.width
        _ = spline.map { bumpy.addEllipse(in: CGRect(x: $0.x - size, y: $0.y - size, width: 2*size, height: 2*size)) }
        return bumpy
    }
    
    private func confine(coordinate point: CGPoint, in rect: CGRect) -> CGPoint {
        return CGPoint(
            x: point.x * rect.width,
            y: (thickness.top - point.y) * rect.width
        )
    }
    
    init(name: String, coordinates: [CGPoint], options: Set<Contouring> = [], dot: CGFloat = 0.05, bumps: Set<Bimp> = [])  {
        self.name = name
        self.coordinates = coordinates
        self.dot = dot
        self.options = options
        self.bumps = bumps
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
        self.dot = 0.005
        self.options = []
        self.bumps = []
    }
    
    func join<S: Shape>(with shape: S) -> Self {
        Contour(name: "a", coordinates: self.union(shape).boundary())
    }
}

// DOUBLE AT BEGINING
/*
struct ContourCircle: Shape {
    func path(in rect: CGRect) -> Path {
        //var path1 = Path()
        //let spline = contour?.coordinates.map { confine(coordinate: $0, in: rect) }
        //guard var spline else { return path1 }
        //path1.move(to: spline.first ?? CGPoint(x: rect.midX, y: rect.maxY))
        //_ = spline.map { path1.addLine(to: $0) }

 

        let first = pointsINT.last!
        points2.insert(first, at: 1)
        let k = pointsINT.dropLast()
        points2.insert(k.last!, at: points2.count-1)
        var a = points2.dropLast().dropFirst()
        insert(Array(a), into: &spline)
 
 
        //print(spline)
        var path4 = Path()
        path4.move(to: spline.first ?? CGPoint(x: rect.midX, y: rect.maxY))
        _ = spline.map { path4.addLine(to: $0) }
        /*
        for i in 0...faa.count-2 {
            print("[(\(faa[i].x),\(faa[i].y)), (\(faa[i+1].x),\(faa[i+1].y))]")
        }
         */
        //print("\n")
        return path4
    }
    
    func insert(_ b: [CGPoint], into a: inout [CGPoint]) {
        guard let i = a.firstIndex(where: { $0.x <= b.first!.x } )
        else { return }
        a.insert(contentsOf: b, at: i)
    }
}
*/

//  Round-off errors because of the multiplication with .rect make it hard to check if two points are equal in the path. Right now, I'm using tolerances to get beyond that fact, but if they're too many points in the bumps, the tolerances will delete the wrong points.

//  It's not a perfect circle near the contour

func convertStringToCGPoints(_ input: String) -> [CGPoint] {
    // Remove the "[" and "]" characters and split the string by ","
    let cleanedString = input.replacingOccurrences(of: "[\\[\\]]", with: "", options: .regularExpression)
    var components = cleanedString.components(separatedBy: ")")

    // Create an array of CGPoint objects from the components
    components.removeFirst()
    var cgPoints = [CGPoint]()

    for component in components {
        let values = component.components(separatedBy: ", ")
        if values.count == 3 {
            let sx = values[1].replacingOccurrences(of: "(", with: "").trimmingCharacters(in: .whitespaces)
            guard let x = Double(sx) else { continue }
            guard let y = Double(values[2]) else { continue }
            let cgPoint = CGPoint(x: x, y: y)
            cgPoints.append(cgPoint)
        }
    }
    guard let largest = cgPoints.max(by: {$0.x < $1.x}) else { return [] }
    var normalized = cgPoints.map { CGPoint(x: $0.x/largest.x, y: $0.y/largest.x)}
    normalized.append(normalized[0])
    guard let max = normalized.max(by: {$0.y < $1.y})?.y else { return [] }
    var upsidedown = normalized.map { CGPoint(x: $0.x, y: -1*$0.y + max) }
    //upsidedown = upsidedown.reversed()
    //print(upsidedown)
    //let te = upsidedown[upsidedown.count-2]
    //upsidedown.insert(te, at: 0)
    //upsidedown.removeLast()
    //upsidedown = upsidedown.reversed()
    upsidedown = upsidedown.reversed()
    print(upsidedown)
    /*
    for point in upsidedown {
        print("[\(point.x), \(point.y)],")
    }
     */
    return cgPoints
}

func pri() {
    let coords = "[(617.5, 37.053871154785156), (616.8656616210938, 36.96173095703125), (614.9651489257812, 36.6864128112793), (611.806396484375, 36.231231689453125), (607.4022827148438, 35.60158920288086), (601.7709350585938, 34.804832458496094), (594.935546875, 33.850067138671875), (586.9241333007812, 32.747901916503906), (577.7696533203125, 31.51022720336914), (567.5097045898438, 30.149930953979492), (556.1864624023438, 28.6806697845459), (543.846435546875, 27.116655349731445), (530.5403442382812, 25.472457885742188), (516.3228759765625, 23.762893676757812), (501.2524719238281, 22.002914428710938), (485.3910217285156, 20.207597732543945), (475.4750061035156, 18.446456909179688), (475.4422607421875, 17.811538696289062), (475.34442138671875, 17.183349609375), (475.1825256347656, 16.56854820251465), (474.958251953125, 15.973654747009277), (474.67401123046875, 15.404973983764648), (474.3327941894531, 14.868532180786133), (473.938232421875, 14.37001895904541), (473.4945068359375, 13.914715766906738), (473.0063171386719, 13.507450103759766), (472.4788513183594, 13.15254020690918), (471.91766357421875, 12.85374641418457), (471.3287353515625, 12.614236831665039), (470.71832275390625, 12.43655014038086), (470.0928649902344, 12.32257080078125), (469.458984375, 12.273505210876465), (468.8234558105469, 12.289875030517578), (468.19293212890625, 12.371505737304688), (467.5741882324219, 12.517532348632812), (466.97369384765625, 12.726407051086426), (466.39788818359375, 12.995916366577148), (465.85284423828125, 13.323202133178711), (465.3443298339844, 13.704795837402344), (464.87774658203125, 14.136652946472168), (464.45806884765625, 14.6141939163208), (464.0896911621094, 15.13235855102539), (463.77655029296875, 15.685653686523438), (463.5219421386719, 16.268213272094727), (463.32861328125, 16.873863220214844), (463.19854736328125, 17.496183395385742), (463.09228515625, 17.775890350341797), (463.125, 17.140972137451172), (463.09228515625, 16.506052017211914), (462.99444580078125, 15.877861976623535), (462.83251953125, 15.263062477111816), (462.6082458496094, 14.668168067932129), (462.3240051269531, 14.0994873046875), (461.9827880859375, 13.5630464553833), (461.5882263183594, 13.064532279968262), (461.1445007324219, 12.60922908782959), (460.65631103515625, 12.201964378356934), (460.12884521484375, 11.847053527832031), (459.5676574707031, 11.548259735107422), (458.978759765625, 11.30875015258789), (458.3683166503906, 11.131063461303711), (457.74285888671875, 11.017084121704102), (457.1089782714844, 10.968018531799316), (456.47344970703125, 10.98438835144043), (455.84295654296875, 11.066019058227539), (455.22418212890625, 11.212045669555664), (454.62371826171875, 11.420920372009277), (454.0478820800781, 11.6904296875), (453.5028381347656, 12.017715454101562), (452.99432373046875, 12.399309158325195), (452.52777099609375, 12.83116626739502), (452.1080627441406, 13.308708190917969), (451.73968505859375, 13.826871871948242), (451.4265441894531, 14.380167007446289), (451.17193603515625, 14.962727546691895), (450.9786071777344, 15.568377494812012), (450.84857177734375, 16.190696716308594), (433.72686767578125, 14.762550354003906), (415.3814697265625, 12.980008125305176), (396.597900390625, 11.240673065185547), (377.4533386230469, 9.561408042907715), (358.0264587402344, 7.959585666656494), (338.3970947265625, 6.453053951263428), (318.64593505859375, 5.060052394866943), (298.85406494140625, 3.799055576324463), (279.1029052734375, 2.688547372817993), (259.4735412597656, 1.7467296123504639), (240.04666137695312, 0.9911749362945557), (220.90211486816406, 0.43843498826026917), (202.11854553222656, 0.10362425446510315), (183.7731475830078, 0.0), (165.94129943847656, 0.13856172561645508), (148.6962890625, 0.5276942849159241), (132.10897827148438, 1.1728780269622803), (116.24752044677734, 2.076486110687256), (101.1771011352539, 3.2376880645751953), (86.95964050292969, 4.652468204498291), (73.65355682373047, 6.313769817352295), (61.31354522705078, 8.211759567260742), (49.990299224853516, 10.334211349487305), (39.730350494384766, 12.66698932647705), (30.575862884521484, 15.194615364074707), (22.564451217651367, 17.90089225769043), (15.72903823852539, 20.76956558227539), (10.097710609436035, 23.784963607788086), (5.693610191345215, 26.93263053894043), (2.5348331928253174, 30.19987678527832), (0.6343600153923035, 33.57624816894531), (0.0, 37.053871154785156), (0.6343600153923035, 40.531497955322266), (2.5348331928253174, 43.907867431640625), (5.693610191345215, 47.175113677978516), (10.097710609436035, 50.32278060913086), (15.72903823852539, 53.33818054199219), (22.564451217651367, 56.206851959228516), (30.575862884521484, 58.91313171386719), (39.730350494384766, 61.440757751464844), (49.990299224853516, 63.77353286743164), (61.31354522705078, 65.89598846435547), (73.65355682373047, 67.79397583007812), (86.95964050292969, 69.45527648925781), (101.1771011352539, 70.87005615234375), (116.24752044677734, 72.03125762939453), (132.10897827148438, 72.93486785888672), (148.6962890625, 73.58004760742188), (165.94129943847656, 73.96918487548828), (183.7731475830078, 74.10774230957031), (202.11854553222656, 74.00411987304688), (220.90211486816406, 73.6693115234375), (240.04666137695312, 73.11656951904297), (259.4735412597656, 72.36101531982422), (279.1029052734375, 71.41919708251953), (298.85406494140625, 70.3086929321289), (318.64593505859375, 69.04769134521484), (338.3970947265625, 67.65469360351562), (358.0264587402344, 66.14816284179688), (377.4533386230469, 64.54633331298828), (396.597900390625, 62.86707305908203), (415.3814697265625, 61.12773895263672), (433.72686767578125, 59.34519577026367), (451.5586853027344, 57.535831451416016), (468.8037109375, 55.715606689453125), (485.3910217285156, 53.900150299072266), (501.2524719238281, 52.10483169555664), (516.3228759765625, 50.344852447509766), (530.5403442382812, 48.63528823852539), (543.846435546875, 46.991092681884766), (556.1864624023438, 45.42707443237305), (567.5097045898438, 43.95781326293945), (577.7696533203125, 42.59751892089844), (586.9241333007812, 41.359840393066406), (594.935546875, 40.2576789855957), (601.7709350585938, 39.302913665771484), (607.4022827148438, 38.50615692138672), (611.806396484375, 37.87651443481445), (614.9651489257812, 37.421329498291016), (616.8656616210938, 37.14601516723633), (617.5, 37.053871154785156)]"
    let points = convertStringToCGPoints(coords)
    
}
