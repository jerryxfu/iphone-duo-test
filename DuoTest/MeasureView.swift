import SwiftUI

/// The whole window, with what iOS reports drawn on it: the safe area (green, dashed), the fold (red), the cameras
/// (orange), and UIKit's status bar frame (blue). Inactive regions are dashed and paler. No navigation stack, like
/// TechNexus's Schedule tab.
struct MeasureView: View {
    @Environment(\.horizontalSizeClass) private var horizontal
    @Environment(\.verticalSizeClass) private var vertical
    @Environment(\.toolbarVerticalEdge) private var edge

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            // The outer reader stays in the safe area, so its frame is the safe area; the inner one covers the window.
            GeometryReader { safeProxy in
                let safeFrame = safeProxy.frame(in: .global)
                GeometryReader { proxy in
                    let snapshot = Snapshot.make(
                        source: "measure",
                        proxy: proxy,
                        safeFrame: safeFrame,
                        horizontal: horizontal,
                        vertical: vertical,
                        edge: edge
                    )
                    let origin = snapshot.frame.rect.origin
                    let safeRect = safeFrame.offsetBy(dx: -origin.x, dy: -origin.y)

                    ZStack(alignment: .topLeading) {
                        Color(.systemGroupedBackground)
                        outline(safeRect, color: .green, dashed: true)
                        ForEach(snapshot.divisions, id: \.self) { region in
                            shade(region.frame.rect, color: .red, active: region.active)
                        }
                        ForEach(snapshot.occlusions, id: \.self) { region in
                            shade(region.frame.rect, color: .orange, active: region.active)
                        }
                        if let bar = snapshot.statusBar {
                            outline(bar.rect.offsetBy(dx: -origin.x, dy: -origin.y), color: .blue, dashed: false)
                        }
                        Readout(lines: snapshot.lines + ["", "green safe area · red fold", "orange camera · blue status bar"])
                            .position(x: safeRect.midX, y: safeRect.midY)
                    }
                    .task(id: snapshot) { Recorder.shared.record(snapshot) }
                }
                .ignoresSafeArea()
            }
        }
    }

    private func outline(_ rect: CGRect, color: Color, dashed: Bool) -> some View {
        Rectangle()
            .strokeBorder(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [6, 4] : []))
            .frame(width: max(rect.width, 2), height: max(rect.height, 2))
            .offset(x: rect.minX, y: rect.minY)
    }

    private func shade(_ rect: CGRect, color: Color, active: Bool) -> some View {
        Rectangle()
            .fill(color.opacity(active ? 0.35 : 0.12))
            .overlay(Rectangle().strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: active ? [] : [4, 3])))
            .frame(width: max(rect.width, 2), height: max(rect.height, 2))
            .offset(x: rect.minX, y: rect.minY)
    }
}
