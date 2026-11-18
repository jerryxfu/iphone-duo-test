import SwiftUI

/// Apple's side-by-side container with a Schedule and a Pit stand-in: when it splits, which way, and around the fold.
/// Each half shows and records its own size.
struct SideBySideLab: View {
    enum Axes: String, CaseIterable, Identifiable {
        case horizontal = "Side by side only"
        case both = "Either way"
        var id: Self { self }

        var style: SplitArrangementViewStyle {
            switch self {
            case .horizontal: .split.axes(.horizontal)
            case .both: .split.axes([.horizontal, .vertical])
            }
        }
    }

    @State private var axes = Launch.value(Axes.self, "axes") ?? .horizontal

    var body: some View {
        NavigationStack {
            ArrangementView {
                pane("Schedule", tint: .purple, row: "Qualification")
            } secondary: {
                pane("Pit", tint: .teal, row: "Team")
            }
            .arrangementViewStyle(axes.style)
            .navigationTitle("Side by side")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Split", selection: $axes) {
                            ForEach(Axes.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Label("Split", systemImage: "rectangle.split.2x1")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Scan", systemImage: "qrcode.viewfinder") {}
                }
            }
        }
    }

    private func pane(_ name: String, tint: Color, row: String) -> some View {
        List(1...30, id: \.self) { index in
            Text("\(row) \(index)")
        }
        .scrollContentBackground(.hidden)
        .background(tint.opacity(0.15))
        .overlay {
            Probe(source: "side.\(name)", extra: ["axes": axes.rawValue], show: true)
        }
    }
}
