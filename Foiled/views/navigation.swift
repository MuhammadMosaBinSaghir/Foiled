import SwiftUI

struct Navigation: View {
    @State var search: String = ""
    @State var selected: String? = nil
    
    var filtered: Contours {
        guard !search.isEmpty else { return library }
        return library.filter { $0.name.contains(search.uppercased()) }
    }
    
    var body: some View {
        NavigationSplitView {
            Sidebar()
                .frame(minWidth: 180)
        } detail: {
            VStack {
                Spacer()
                //Airfoil(id: selected, cord: 1000)
                ContourCircle(location: 0.5, radius: 0.01, id: selected)
                    .stroke(.primary, lineWidth: 1)
                    .frame(width: 750, height: 100)
                    
                    //.background(.red)
                Spacer()
            }
        }
    }
    
    @ViewBuilder private func Sidebar() -> some View {
        List(selection: $selected) {
            ForEach(filtered.sorted(by: { $0.name < $1.name }), id: \.name) { contour in
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(contour.name)
                            .lineLimit(1)
                        Spacer()
                        Text("\(contour.coordinates.count)")
                            .padding(4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary))
                    }
                    
                    contour
                        .stroke(.primary, lineWidth: 1)
                        .aspectRatio(1/contour.thickness.total, contentMode: .fit)
                }
                .padding(.bottom, 16)
                .padding([.top, .horizontal], 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quinary))
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: -8, bottom: 0, trailing: -8))
        }
        .scrollIndicators(.hidden)
        .searchable(text: $search, placement: .sidebar, prompt: "Airfoil")
    }
}

#Preview {
    Navigation()
}
