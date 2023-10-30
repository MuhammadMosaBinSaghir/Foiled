import Charts
import SwiftUI

struct Navigation: View {
    @State var selected: Contour
    @State private var search: String = ""
    @State private var options = Set<Contouring>()
    
    private let pasteboard = NSPasteboard.general
    private let gridlines = Gridlines(
        style: (minor: .init(lineWidth: 0.5, lineJoin: .round, dash: [5]), major: .init(lineWidth: 0.5, lineJoin: .round, dash: [5])),
        domain: (abscissa: -0.25...1.25, ordinate: -0.5...0.5),
        quantity: (minor: 12, major: 6)
    )
    
    var filtered: Contours {
        guard !search.isEmpty else { return library }
        return library.filter { $0.name.contains(search.uppercased()) }
    }
    
    var range: [Int] {
        let size = Double(selected.definition.count)
        let coefficients: [Double] = [-0.5, -1/3, -0.25, 0, 1, 2, 3]
        return coefficients.map { Int($0*(size-1) + size) }
    }
    
    var body: some View {
        NavigationSplitView() {
            Sidebar()
        } detail: {
            Details()
                .ignoresSafeArea()
                .frame(minWidth: 1000)
        }
        .navigationTitle("")
        .toolbar { Toolbar() }
        .toolbarBackground(.clear, for: .automatic)
    }
    
    @ViewBuilder private func Buttoned() -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(.background).strokeBorder(style: .init(lineWidth: 0.5)).foregroundStyle(.secondary).shadow(radius: 4)
    }
    
    @ViewBuilder private func Copy() -> some View {
        Button {
            copy()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
                .frame(width: 24, height: 24)
        }
    }
    
    @ViewBuilder private func Dot() -> some View {
        Button {
            dotted()
        } label: {
            Label("Dotted", systemImage: options.contains(.dotted) ? "eye" : "eye.slash")
                .frame(width: 24, height: 24)
        }
    }
    
    @ViewBuilder private func Mesh() -> some View {
        Button {
            mesh()
        } label: {
            Label("Copy", systemImage: "cube.transparent")
                .frame(width: 24, height: 24)
        }
    }
    
    @ViewBuilder private func Dots() -> some View {
        Picker("Points", selection: $selected.points) {
            ForEach(range, id: \.self) { Text("\($0) points") }
        }
        .background(Buttoned())
        .frame(height: 24)
    }
    
    @ViewBuilder private func Toolbar() -> some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 0) {
                Copy()
                Mesh()
                Dot()
            }
            .background(Buttoned())
            Dots()
        }
    }
    
    @ViewBuilder private func Symbol() -> some View {
        Circle()
            .stroke(lineWidth: 0.5)
            .frame(height: 8)
            .foregroundStyle(
                options.contains(.dotted) ? Color.primary : .clear
            )
    }
    
    @ViewBuilder private func Details() -> some View {
        Chart(selected.coordinates, id: \.self) {
            LineMark(
                x: PlottableValue.value("x", $0.x),
                y: PlottableValue.value("y", $0.y)
            )
            .foregroundStyle(.primary)
            .lineStyle(StrokeStyle(lineWidth: 1))
            .symbol { Symbol() }
        }
        .chartXScale(domain: gridlines.domain.abscissa)
        .chartYScale(domain: gridlines.domain.ordinate)
        .chartXAxis {
            AxisMarks(preset: .inset, values: gridlines.major.abscissa) {
                AxisGridLine(centered: true, stroke: gridlines.style.major)
                    .foregroundStyle(.secondary)
            }
            AxisMarks(preset: .inset, values: gridlines.minor.abscissa) {
                AxisGridLine(centered: true, stroke: gridlines.style.minor)
                    .foregroundStyle(.tertiary)
                AxisValueLabel(gridlines.minor.abscissa[$0.index].formatted(.number.precision(.fractionLength(3))), anchor: .bottomTrailing, verticalSpacing: 12)
            }
        }
        .chartYAxis {
            AxisMarks(preset: .inset, values: gridlines.major.ordinate) {
                AxisGridLine(centered: true, stroke: gridlines.style.major)
                    .foregroundStyle(.secondary)
            }
            AxisMarks(preset: .inset, values: gridlines.minor.ordinate) {
                AxisGridLine(centered: true, stroke: gridlines.style.minor)
                    .foregroundStyle(.tertiary)
            }
            AxisMarks(preset: .inset, values: gridlines.minor.ordinate.dropLast(2)) {
                AxisValueLabel(gridlines.minor.ordinate[$0.index].formatted(.number.precision(.fractionLength(3))), horizontalSpacing: 12)
            }
        }
    }
    
    @ViewBuilder private func Sidebar() -> some View {
        List(selection: $selected) {
            Section {
                ForEach(filtered.sorted(by: { $0.name < $1.name }), id: \.self) { contour in
                    HStack(alignment: .center, spacing: 8) {
                        contour
                            .stroke(.secondary, lineWidth: 1)
                            .frame(width: 60, height: 60*(contour.thickness.total))
                        Text(contour.name)
                        Spacer()
                        Text("\(contour.coordinates.count)")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {}
            .collapsible(false)
        }
        .scrollIndicators(.hidden)
        .searchable(text: $search, placement: .sidebar, prompt: "Search")
    }
    
    private func mesh() {
        var model = Model(label: selected.name, instance: 1, boundary: .c)
        model.launch()
        model.contour(from: selected.coordinates, on: .zero, precision: 0.01)
        model.boundary(radius: 100, on: .zero, precision: 1)
        model.structure(conditions: [
            Transfinite(label: .contour, points: 100, type: .bump, parameter: 1),
            Transfinite(label: .inlet, points: 100, type: .progression, parameter: 1),
            Transfinite(label: .vertical, points: 100, type: .progression, parameter: 1),
            Transfinite(label: .wake, points: 100, type: .progression, parameter: 1),
        ])
        model.mesh(dimension: .second, showcase: true)
    }
    
    private func copy() {
        let text = selected.coordinates.parse(precision: 5)
        pasteboard.declareTypes([.string], owner: .none)
        pasteboard.setString(text, forType: .string)
    }
    
    private func dotted() {
        switch options.contains(.dotted) {
        case true: options.remove(.dotted)
        case false: options.insert(.dotted)
        }
    }
    
    init(selected: Contour) {
        self.selected = selected
    }
}

#Preview {
    Navigation(selected: library.first(where: {$0.name == "20-32C"})!)
}

