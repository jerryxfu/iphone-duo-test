import SwiftUI

/// Where iOS puts toolbar buttons, and how wide the column is: Pit's Scan, a narrow Q7 header like the Schedule's,
/// the Strategy colours or tools. A list with pull to refresh, since Scan once looked left behind by one (30 Sep).
struct ToolbarLab: View {
    enum Items: String, CaseIterable, Identifiable {
        case scan = "Scan"
        case header = "Q7 header"
        case scanAndHeader = "Scan and Q7"
        case colors = "6 colours"
        case tools = "6 tools"
        case strategy = "Tools, undo, match"
        var id: Self { self }
    }

    enum Compression: String, CaseIterable, Identifiable {
        case automatic = "Automatic"
        case buttons = "Keep buttons"
        case tabs = "Keep tabs"
        var id: Self { self }

        var behavior: ToolbarVerticalCompressionBehavior {
            switch self {
            case .automatic: .automatic
            case .buttons: .prefersToolbarItems
            case .tabs: .prefersTabBar
            }
        }
    }

    /// Hiding the navigation bar takes the column's buttons with it (closed Duo, 16 Oct), so the bar stays and its
    /// title can go instead.
    enum Title: String, CaseIterable, Identifiable {
        case shown = "Shown"
        case empty = "Empty"
        case removed = "Removed"
        var id: Self { self }
    }

    // Each starts from a launch argument when there is one: `xcrun simctl launch <sim> net.jerryxf.iphone-duo-test
    // -tab toolbar -items "6 colours" -title Removed`.
    @State private var items = Launch.value(Items.self, "items") ?? .scanAndHeader
    @State private var compression = Launch.value(Compression.self, "compression") ?? .automatic
    @State private var bottom = Launch.flag("bottom")
    @State private var hideNavigationBar = Launch.flag("hideNavigationBar")
    @State private var title = Launch.value(Title.self, "title") ?? .shown
    @State private var pulls = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Buttons", selection: $items) {
                        ForEach(Items.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("When short", selection: $compression) {
                        ForEach(Compression.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Title", selection: $title) {
                        ForEach(Title.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("In the bottom bar", isOn: $bottom)
                    Toggle("Hide the navigation bar", isOn: $hideNavigationBar)
                } footer: {
                    Text("Pull down: do the buttons stay put? Pulled \(pulls) times.")
                }
                Section("Rows") {
                    ForEach(1...40, id: \.self) { Text("Row \($0)") }
                }
            }
            .refreshable {
                try? await Task.sleep(for: .seconds(1))
                pulls += 1
            }
            .overlay {
                Probe(
                    source: "toolbar",
                    extra: [
                        "items": items.rawValue,
                        "compression": compression.rawValue,
                        "bottom": "\(bottom)",
                        "hideNavigationBar": "\(hideNavigationBar)",
                        "title": title.rawValue,
                    ]
                )
            }
            .navigationTitle(title == .empty ? "" : "Toolbar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(removing: title == .removed ? .title : nil)
            .toolbar { content }
            .toolbar(hideNavigationBar ? .hidden : .automatic, for: .navigationBar)
            .toolbarVerticalCompressionBehavior(compression.behavior)
        }
    }

    @ToolbarContentBuilder
    private var content: some ToolbarContent {
        let placement: ToolbarItemPlacement = bottom ? .bottomBar : .topBarTrailing
        if items == .scan || items == .scanAndHeader {
            ToolbarItem(placement: placement) {
                Button("Scan", systemImage: "qrcode.viewfinder") {}
            }
        }
        if items == .header || items == .scanAndHeader {
            ToolbarItem(placement: placement) {
                HeaderItem()
            }
            .axisBehavior(.verticalPreferred)
            .visibilityPriority(.high)
        }
        if items == .colors {
            ToolbarItemGroup(placement: placement) {
                ForEach(Palette.all, id: \.name) { color in
                    Button {} label: {
                        Label(color.name, systemImage: "circle.fill")
                    }
                    .tint(color.color)
                }
            }
            .axisBehavior(.verticalPreferred)
        }
        if items == .tools || items == .strategy {
            ToolbarItemGroup(placement: placement) {
                ForEach(Palette.tools, id: \.title) { tool in
                    Button(tool.title, systemImage: tool.symbol) {}
                }
            }
        }
        if items == .strategy {
            ToolbarItemGroup(placement: placement) {
                Button("Undo", systemImage: "arrow.uturn.backward") {}
                Button("Redo", systemImage: "arrow.uturn.forward") {}
            }
            ToolbarItem(placement: placement) {
                Text("Q12")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            .axisBehavior(.verticalPreferred)
            ToolbarItem(placement: placement) {
                Button("Put the robots back", systemImage: "plus.square.on.square") {}
            }
            ToolbarOverflowMenu {
                Button("Turn the field around", systemImage: "arrow.up.arrow.down") {}
                Button("Clear the board", systemImage: "trash", role: .destructive) {}
            }
        }
    }
}

/// The Schedule header made narrow for the column: the match, its status as the pit map's code, the dot, the
/// freshness.
struct HeaderItem: View {
    var body: some View {
        VStack(spacing: 1) {
            Text("Q7")
                .font(.headline)
            HStack(spacing: 3) {
                Text("OD")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.blue)
                Circle()
                    .fill(.blue)
                    .frame(width: 5, height: 5)
            }
            HStack(spacing: 2) {
                Image(systemName: "arrow.clockwise")
                Text("now")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}

enum Palette {
    struct NamedColor {
        let name: String
        let color: Color
    }

    struct Tool {
        let title: String
        let symbol: String
    }

    static let all: [NamedColor] = [
        NamedColor(name: "Red", color: .red),
        NamedColor(name: "Blue", color: .blue),
        NamedColor(name: "Yellow", color: .yellow),
        NamedColor(name: "Green", color: .green),
        NamedColor(name: "White", color: .white),
        NamedColor(name: "Black", color: .black),
    ]

    /// TechNexus's order and symbols (`StrategyTool.order`).
    static let tools: [Tool] = [
        Tool(title: "Circle", symbol: "circle"),
        Tool(title: "Square", symbol: "square"),
        Tool(title: "Arrow", symbol: "arrow.up.right"),
        Tool(title: "Pen", symbol: "pencil.tip"),
        Tool(title: "Eraser", symbol: "eraser"),
        Tool(title: "Move", symbol: "hand.point.up.left"),
    ]
}
