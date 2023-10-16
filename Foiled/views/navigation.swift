import SwiftUI

struct Navigation: View {
    @State var search: String = ""
    @State var options = Set<Contouring>()
    @State var selected: Contour = library.first(where: {$0.name == "20-32C"})!
    
    var filtered: Contours {
        guard !search.isEmpty else { return library }
        return library.filter { $0.name.contains(search.uppercased()) }
    }
    
    var body: some View {
        NavigationSplitView() {
            Sidebar()
        } detail: {
            VStack {
                Contour(
                    name: selected.name,
                    coordinates: selected.coordinates,
                    options: options,
                    dot: 0.005
                )
                .stroke(.primary, lineWidth: 1)
                .aspectRatio(1/selected.thickness.total, contentMode: .fit)
            }
            .padding(.horizontal, 16)
        }
        .toolbar { Dots() }
        .navigationTitle("")
        .toolbarBackground(.clear, for: .windowToolbar)
        .animation(.smooth, value: options)
    }
    
    @ViewBuilder private func Dots() -> some View {
        Button {
            switch options.contains(.dotted) {
            case true: options.remove(.dotted)
            case false: options.insert(.dotted)
            }
        } label: {
            Label("Dotted", systemImage: options.contains(.dotted) ? "eye" : "eye.slash")
                .frame(width: 32, height: 32)
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
}

#Preview {
    Navigation()
}
