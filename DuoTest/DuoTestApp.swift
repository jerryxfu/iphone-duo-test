import SwiftUI

@main
struct DuoTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Four tabs, as TechNexus has, so the tab bar takes the room the real one does.
struct ContentView: View {
    enum Page: String {
        case measure, toolbar, side, field
    }

    @State private var page = Launch.value(Page.self, "tab") ?? .measure

    var body: some View {
        TabView(selection: $page) {
            Tab("Measure", systemImage: "ruler", value: Page.measure) {
                MeasureView()
            }
            Tab("Toolbar", systemImage: "sidebar.right", value: Page.toolbar) {
                ToolbarLab()
            }
            Tab("Side by side", systemImage: "rectangle.split.2x1", value: Page.side) {
                SideBySideLab()
            }
            Tab("Field", systemImage: "sportscourt", value: Page.field) {
                FieldLab()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
