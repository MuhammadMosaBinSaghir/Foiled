import SwiftUI

struct Bump<S: Shape>: Shape, View {
    var shape: S
    var size: CGSize
    var position: CGPoint
    var rect: CGRect = .zero
    var body: some View { shape }

    func path(in rect: CGRect) -> Path { shape.path(in: rect) }
}

struct Navigation: View {
    @State var selected: Contour = library.first(where: {$0.name == "20-32C"})!
    @State private var search: String = ""
    @State private var options = Set<Contouring>()

    @State private var bump: Bump = .init(shape: .rect, size: .init(width: 0.05, height: 0.05), position: .zero)
    
    private var pasteboard = NSPasteboard.general
    
    var filtered: Contours {
        guard !search.isEmpty else { return library }
        return library.filter { $0.name.contains(search.uppercased()) }
    }
    
    var body: some View {
        NavigationSplitView() {
            Sidebar()
        } detail: {
            Details()
        }
        .navigationTitle("")
        .toolbar {
            HStack(alignment: .center, spacing: 4) {
                Copy()
                Dot()
            }
        }
        .toolbarBackground(.clear, for: .automatic)
        .animation(.smooth, value: options)
    }
    
    @ViewBuilder private func Dot() -> some View {
        Button {
            dotted()
        } label: {
            Label("Dotted", systemImage: options.contains(.dotted) ? "eye" : "eye.slash")
                .frame(width: 24, height: 24)
        }
    }
    
    @ViewBuilder private func Copy() -> some View {
        Button {
            join()
            copy()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
                .frame(width: 24, height: 24)
        }
    }
    
    @ViewBuilder private func Details() -> some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    Spacer()
                    Contour(
                        name: selected.name,
                        coordinates: selected.coordinates,
                        options: options,
                        dot: 0.005
                    )
                    .stroke(.secondary, lineWidth: 1)
                    .aspectRatio(1/selected.thickness.total, contentMode: .fit)
                    .background(.blue)
                    Spacer()
                }
                .background(.green)
                bump
                    .position(bump.position)
                    .frame(width: geometry.size.width*bump.size.width, height: geometry.size.height*bump.size.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                bump.position = value.location
                            }
                    )
                    .onChange(of: geometry.frame(in: .global)) { oldValue, newValue in
                        bump.rect = newValue
                    }
            }
        }
        .background(.red)
        .padding(.horizontal, 12)
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
    
    private func copy() {
        let text = selected.boundary().parse(precision: 5)
        pasteboard.declareTypes([.string], owner: .none)
        pasteboard.setString(text, forType: .string)
    }
    private func dotted() {
        switch options.contains(.dotted) {
        case true: options.remove(.dotted)
        case false: options.insert(.dotted)
        }
    }
    private func join() {
        let path1 = selected.path(in: bump.rect)
        let path2 = bump.path(in: bump.rect)
        let path3 = path2.scale(x: bump.size.width, y: bump.size.height, anchor: .center).path(in: bump.rect)
        var horizontal = path3.coordinates().sorted(by: {$0.x < $1.x})
        var vertical = path3.coordinates().sorted(by: {$0.y < $1.y})
        var edges =
        (
            left: horizontal.first?.x ?? .zero,
            right: horizontal.last?.x ?? .zero,
            bottom: vertical.first?.y ?? .zero,
            top: vertical.last?.y ?? .zero
        )
        let center = CGPoint(
            x: 0.5*(edges.right + edges.left),
            y: 0.5*(edges.top + edges.bottom)
        )
        horizontal = path1.coordinates().sorted(by: {$0.x < $1.x})
        vertical = path1.coordinates().sorted(by: {$0.y < $1.y})
        edges =
        (
            left: horizontal.first?.x ?? .zero,
            right: horizontal.last?.x ?? .zero,
            bottom: vertical.first?.y ?? .zero,
            top: vertical.last?.y ?? .zero
        )
        let position = bump.position.relative(to: edges, in: bump.rect)
        let translate = CGAffineTransform(
            translationX: center.x < position.x ? (center.x - position.x) : -1*(center.x - position.x),
            y: center.y < position.y ? (center.y - position.y) : -1*(center.y - position.y)
        )
        let path4 = path3.transform(translate).path(in: bump.rect)
        let path5 = path1.union(path4)
        
        print(path5.coordinates().normalize().parse(precision: 5))
        selected = Contour(name: "a", coordinates: path5.coordinates().normalize())
    }
}

#Preview {
    Navigation()
}
