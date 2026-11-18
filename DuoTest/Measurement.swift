import SwiftUI
import UIKit

/// A rectangle in points, rounded to a tenth, as it's written to the log.
struct Box: Codable, Equatable, Hashable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    init(_ rect: CGRect) {
        x = Self.round(rect.minX)
        y = Self.round(rect.minY)
        w = Self.round(rect.width)
        h = Self.round(rect.height)
    }

    var rect: CGRect { CGRect(x: x, y: y, width: w, height: h) }

    static func round(_ value: CGFloat) -> Double { (Double(value) * 10).rounded() / 10 }

    var text: String { "\(fmt(x)),\(fmt(y)) \(fmt(w))×\(fmt(h))" }
}

func fmt(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
}

/// One of iOS's reserved regions: the fold (a division) or a camera (an occlusion).
struct Region: Codable, Equatable, Hashable {
    var frame: Box
    var active: Bool
    /// top, leading, bottom, trailing
    var margins: [Double]

    init(_ region: ReservedRegion) {
        frame = Box(region.frame)
        active = region.isActive
        margins = [region.margins.top, region.margins.leading, region.margins.bottom, region.margins.trailing].map(Box.round)
    }
}

/// Everything iOS says about the space one view has, at one moment.
struct Snapshot: Codable, Equatable, Hashable {
    /// Which view measured it, and in which mode.
    var source: String
    /// The view's frame in the window.
    var frame: Box
    /// top, leading, bottom, trailing
    var safe: [Double]
    var horizontalClass: String
    var verticalClass: String
    /// Which side iOS would put a vertical bar on, or "none".
    var barEdge: String
    var divisions: [Region]
    var occlusions: [Region]
    /// UIKit's status bar frame, in the window.
    var statusBar: Box?
    var screen: Box?
    var orientation: String
    var extra: [String: String]

    /// [safeFrame] is the safe area in the window, for a [proxy] that ignores the safe area and so reads none.
    @MainActor
    static func make(
        source: String,
        proxy: GeometryProxy,
        safeFrame: CGRect? = nil,
        horizontal: UserInterfaceSizeClass?,
        vertical: UserInterfaceSizeClass?,
        edge: HorizontalEdge?,
        extra: [String: String] = [:]
    ) -> Snapshot {
        let frame = proxy.frame(in: .global)
        let safe: [CGFloat]
        if let safeFrame {
            safe = [
                safeFrame.minY - frame.minY,
                safeFrame.minX - frame.minX,
                frame.maxY - safeFrame.maxY,
                frame.maxX - safeFrame.maxX,
            ]
        } else {
            let insets = proxy.safeAreaInsets
            safe = [insets.top, insets.leading, insets.bottom, insets.trailing]
        }
        let scene = WindowScene.current
        return Snapshot(
            source: source,
            frame: Box(frame),
            safe: safe.map(Box.round),
            horizontalClass: name(horizontal),
            verticalClass: name(vertical),
            barEdge: edge.map { $0 == .leading ? "leading" : "trailing" } ?? "none",
            divisions: proxy.reservedRegions(kind: .division, options: .includeInactive).map(Region.init),
            occlusions: proxy.reservedRegions(kind: .occlusion, options: .includeInactive).map(Region.init),
            statusBar: scene?.statusBarManager.map { Box($0.statusBarFrame) },
            screen: scene.map { Box($0.screen.bounds) },
            orientation: scene.map { name($0.effectiveGeometry.interfaceOrientation) } ?? "unknown",
            extra: extra
        )
    }

    private static func name(_ sizeClass: UserInterfaceSizeClass?) -> String {
        switch sizeClass {
        case .compact: "compact"
        case .regular: "regular"
        default: "none"
        }
    }

    private static func name(_ orientation: UIInterfaceOrientation) -> String {
        switch orientation {
        case .portrait: "portrait"
        case .portraitUpsideDown: "upsideDown"
        case .landscapeLeft: "landscapeLeft"
        case .landscapeRight: "landscapeRight"
        default: "unknown"
        }
    }

    /// The readout, a line per fact.
    var lines: [String] {
        var lines = [
            "\(source)",
            "frame \(frame.text)",
            "safe t\(fmt(safe[0])) l\(fmt(safe[1])) b\(fmt(safe[2])) r\(fmt(safe[3]))",
            "classes \(horizontalClass) × \(verticalClass), bar \(barEdge)",
            "screen \(screen?.text ?? "?"), \(orientation)",
            "status bar \(statusBar?.text ?? "none")",
        ]
        for region in divisions {
            lines.append("fold \(region.frame.text) \(region.active ? "active" : "inactive")")
        }
        for region in occlusions {
            lines.append("occlusion \(region.frame.text) \(region.active ? "active" : "inactive")")
        }
        for (key, value) in extra.sorted(by: { $0.key < $1.key }) {
            lines.append("\(key) \(value)")
        }
        return lines
    }
}

/// Launch arguments, which iOS puts in `UserDefaults`: `-tab field -mode "Up to the top"`.
enum Launch {
    static func value<T: RawRepresentable>(_ type: T.Type, _ key: String) -> T? where T.RawValue == String {
        UserDefaults.standard.string(forKey: key).flatMap(T.init(rawValue:))
    }

    static func flag(_ key: String) -> Bool {
        UserDefaults.standard.bool(forKey: key)
    }
}

@MainActor
enum WindowScene {
    static var current: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

/// Appends every new measurement to `Documents/measurements.jsonl`, one JSON object a line, and prints it.
/// Read it with `xcrun simctl get_app_container <sim> net.jerryxf.iphone-duo-test data`.
@MainActor
final class Recorder {
    static let shared = Recorder()

    private var last: [String: Snapshot] = [:]
    private let url = URL.documentsDirectory.appending(path: "measurements.jsonl")
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()
    private let clock: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private struct Entry: Encodable {
        let time: String
        let snapshot: Snapshot
    }

    func record(_ snapshot: Snapshot) {
        guard last[snapshot.source] != snapshot else { return }
        last[snapshot.source] = snapshot
        guard let data = try? encoder.encode(Entry(time: clock.string(from: .now), snapshot: snapshot)),
            var line = String(data: data, encoding: .utf8)
        else { return }
        line += "\n"
        print(line, terminator: "")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}

/// Measures the view it's put behind and records it. Re-reads once a second too, since UIKit's status bar frame can
/// settle after the layout that SwiftUI sees.
struct Probe: View {
    let source: String
    var extra: [String: String] = [:]
    var show: Bool = false

    @Environment(\.horizontalSizeClass) private var horizontal
    @Environment(\.verticalSizeClass) private var vertical
    @Environment(\.toolbarVerticalEdge) private var edge

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            GeometryReader { proxy in
                let snapshot = Snapshot.make(
                    source: source,
                    proxy: proxy,
                    horizontal: horizontal,
                    vertical: vertical,
                    edge: edge,
                    extra: extra
                )
                Color.clear
                    .task(id: snapshot) { Recorder.shared.record(snapshot) }
                    .overlay(alignment: .center) {
                        if show { Readout(lines: snapshot.lines) }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

struct Readout: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .fixedSize()
    }
}
