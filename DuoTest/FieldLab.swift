import SwiftUI

/// A stand-in for TechNexus's Strategy tab, in five layouts, chosen from More (the rail's last button, or the system's
/// overflow menu when the bar has buttons):
/// - As now: `StrategyLayout`'s choice, ported below, centred in the safe area.
/// - Rail at the edge: the same, with the rail against the right edge.
/// - Up to the top: upright only. The rail at the right edge; the field from the top of the screen down, kept clear of
///   the status bar and the cameras by what iOS reports, as big as that allows.
/// - Tools in the bar: the tools, undo and redo as system toolbar buttons; under the field, the colours from its left
///   edge and the match with the robots button against its right edge (Jerry, 16 Oct).
/// - Colours in the bar: the colours as system toolbar buttons; the rest in the rail at the right edge.
/// In both bar layouts the tab bar shrinks to one button before any of the tools or colours go into "…": next to it, the
/// column holds four (16 Oct).
/// The field shows its size in points, and each layout is recorded.
struct FieldLab: View {
    enum Mode: String, CaseIterable, Identifiable {
        case now = "As now"
        case railAtEdge = "Rail at the edge"
        case upToTop = "Up to the top"
        case toolsInBar = "Tools in the bar"
        case colorsInBar = "Colours in the bar"
        var id: Self { self }

        var usesBar: Bool { self == .toolsInBar || self == .colorsInBar }
    }

    @State private var mode = Launch.value(Mode.self, "mode") ?? .now

    @Environment(\.horizontalSizeClass) private var horizontal
    @Environment(\.verticalSizeClass) private var vertical
    @Environment(\.toolbarVerticalEdge) private var edge

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                // The outer reader stays in the safe area, so its frame is the safe area; the inner one covers the window.
                GeometryReader { safeProxy in
                    let safeFrame = safeProxy.frame(in: .global)
                    GeometryReader { proxy in
                        let snapshot = Snapshot.make(
                            source: "field",
                            proxy: proxy,
                            safeFrame: safeFrame,
                            horizontal: horizontal,
                            vertical: vertical,
                            edge: edge
                        )
                        let origin = snapshot.frame.rect.origin
                        let plan = FieldPlan(
                            mode: mode,
                            safe: safeFrame.offsetBy(dx: -origin.x, dy: -origin.y),
                            snapshot: snapshot
                        )
                        let recorded = recordable(snapshot, plan)
                        ZStack(alignment: .topLeading) {
                            Color(.systemGroupedBackground)
                            FieldDrawing(upright: plan.upright)
                                .frame(width: plan.field.width, height: plan.field.height)
                                .position(x: plan.field.midX, y: plan.field.midY)
                            ForEach(Array(plan.buttons.enumerated()), id: \.offset) { _, placed in
                                control(placed.kind)
                                    .frame(width: placed.rect.width, height: placed.rect.height)
                                    .position(x: placed.rect.midX, y: placed.rect.midY)
                            }
                        }
                        .task(id: recorded) { Recorder.shared.record(recorded) }
                    }
                    .ignoresSafeArea()
                }
            }
            .toolbar { barContent }
            .toolbar(removing: .title)
            .toolbar(mode.usesBar ? .automatic : .hidden, for: .navigationBar)
            .toolbarVerticalCompressionBehavior(mode.usesBar ? .prefersToolbarItems : .automatic)
        }
    }

    @ToolbarContentBuilder
    private var barContent: some ToolbarContent {
        if mode == .toolsInBar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ForEach(Palette.tools, id: \.title) { tool in
                    Button(tool.title, systemImage: tool.symbol) {}
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Undo", systemImage: "arrow.uturn.backward") {}
                Button("Redo", systemImage: "arrow.uturn.forward") {}
            }
            ToolbarOverflowMenu {
                modePicker
                Button("Turn the field around", systemImage: "arrow.up.arrow.down") {}
                Button("Clear the board", systemImage: "trash", role: .destructive) {}
            }
        }
        if mode == .colorsInBar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ForEach(Palette.all, id: \.name) { color in
                    Button {} label: {
                        Label(color.name, systemImage: "circle.fill")
                    }
                    .tint(color.color)
                }
            }
            .axisBehavior(.verticalPreferred)
        }
    }

    /// The measurement under this layout's name, with the field's size and place.
    private func recordable(_ snapshot: Snapshot, _ plan: FieldPlan) -> Snapshot {
        var recorded = snapshot
        recorded.source = "field.\(mode.rawValue)"
        recorded.extra = [
            "field": "\(fmt(Box.round(plan.field.width)))×\(fmt(Box.round(plan.field.height)))",
            "fieldBox": Box(plan.field).text,
        ]
        return recorded
    }

    private var modePicker: some View {
        Picker("Layout", selection: $mode) {
            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.inline)
    }

    @ViewBuilder
    private func control(_ kind: FieldPlan.Kind) -> some View {
        switch kind {
        case .symbol(let symbol, let selected):
            ButtonFace(selected: selected) {
                Image(systemName: symbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(selected ? Color.white : Color.primary)
            }
        case .text(let text):
            ButtonFace(selected: false) {
                Text(text)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
        case .color(let color, let selected):
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
                .padding(3.5)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 2.5).opacity(selected ? 1 : 0))
        case .more:
            Menu {
                modePicker
            } label: {
                ButtonFace(selected: false) {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.primary)
                }
            }
        }
    }
}

private struct ButtonFace<Content: View>: View {
    let selected: Bool
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: FieldPlan.buttonWidth - 2, height: FieldPlan.buttonHeight - 2)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            )
    }
}

/// A field like TechNexus's: grey, red's wall at the bottom upright or on the left lying down, its size in points.
private struct FieldDrawing: View {
    let upright: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Rectangle().fill(Color(white: 0.42))
                if upright {
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.blue.opacity(0.8)).frame(height: size.height * 0.06)
                        Spacer()
                        Rectangle().fill(Color.white.opacity(0.6)).frame(height: 2)
                        Spacer()
                        Rectangle().fill(Color.red.opacity(0.8)).frame(height: size.height * 0.06)
                    }
                } else {
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.red.opacity(0.8)).frame(width: size.width * 0.06)
                        Spacer()
                        Rectangle().fill(Color.white.opacity(0.6)).frame(width: 2)
                        Spacer()
                        Rectangle().fill(Color.blue.opacity(0.8)).frame(width: size.width * 0.06)
                    }
                }
                Text("\(Int(size.width.rounded()))×\(Int(size.height.rounded()))")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

/// Where the field and its controls go, in the window's coordinates (the view ignores the safe area and reads it).
struct FieldPlan {
    enum Group: CaseIterable {
        case tools, colors, history, match, more

        var count: Int {
            switch self {
            case .tools: 6
            case .colors: 6
            case .history: 2
            case .match: 2
            case .more: 1
            }
        }
    }

    enum Kind {
        case symbol(String, selected: Bool)
        case text(String)
        case color(Color, selected: Bool)
        case more
    }

    struct Placed {
        let rect: CGRect
        let kind: Kind
    }

    static let buttonWidth: CGFloat = 44
    static let buttonHeight: CGFloat = 36
    static let spacing: CGFloat = 2
    static let groupGap: CGFloat = 8
    static let margin: CGFloat = 4
    /// The field image's long side over its short side, from TechNexus's `StrategyField`: 18.774 m by 9.143 m.
    static let fieldAspect: CGFloat = 18.774 / 9.143

    var upright = true
    var field = CGRect.zero
    var buttons: [Placed] = []

    /// [safe] is the safe area in the view's own coordinates.
    init(mode: FieldLab.Mode, safe: CGRect, snapshot: Snapshot) {
        // Only what SwiftUI reports as occluded: UIKit's status bar frame on the closed Duo is a 2-point strip across
        // the top, while the occlusions cover the camera and the clock (16 Oct).
        let avoid = snapshot.occlusions.filter(\.active).map(\.frame.rect)

        switch mode {
        case .now:
            asNow(in: safe, railAtEdge: false)
        case .railAtEdge:
            asNow(in: safe, railAtEdge: true)
        case .upToTop:
            if safe.height > safe.width {
                upToTop(in: safe, avoid: avoid)
            } else {
                asNow(in: safe, railAtEdge: true)
            }
        case .toolsInBar:
            toolsInBar(in: safe)
        case .colorsInBar:
            colorsInBar(in: safe)
        }
    }

    // MARK: - The layouts

    /// TechNexus's `StrategyTabView` with `StrategyLayout`'s choice: rails and field in a row, rows under it, centred.
    private mutating func asNow(in safe: CGRect, railAtEdge: Bool) {
        let m = Self.margin
        let choice = Self.choose(size: safe.size)
        upright = choice.upright
        let leadingWidth = Self.railWidth(choice.leadingColumns)
        let trailingWidth = Self.railWidth(choice.trailingColumns)
        let leadingHeight = choice.leading.isEmpty ? 0 : max(choice.field.height, Self.railHeight(choice.leading, columns: choice.leadingColumns))
        let trailingHeight = choice.trailing.isEmpty ? 0 : max(choice.field.height, Self.railHeight(choice.trailing, columns: choice.trailingColumns))

        let rowWidth = (leadingWidth > 0 ? leadingWidth + m : 0) + choice.field.width + (trailingWidth > 0 ? m + trailingWidth : 0)
        let rowHeight = max(choice.field.height, leadingHeight, trailingHeight)
        let blockHeight = rowHeight + CGFloat(choice.rows.count) * (m + Self.buttonHeight)
        let x0 = safe.minX + (safe.width - rowWidth) / 2
        let y0 = safe.minY + (safe.height - blockHeight) / 2

        var fieldX = x0 + (leadingWidth > 0 ? leadingWidth + m : 0)
        var trailingX = fieldX + choice.field.width + m
        if railAtEdge, trailingWidth > 0 {
            trailingX = safe.maxX - m - trailingWidth
            let left = safe.minX + m + (leadingWidth > 0 ? leadingWidth + m : 0)
            fieldX = left + (trailingX - m - left - choice.field.width) / 2
        }
        field = CGRect(x: fieldX, y: y0 + (rowHeight - choice.field.height) / 2, width: choice.field.width, height: choice.field.height)

        if !choice.leading.isEmpty {
            let rect = CGRect(x: x0, y: y0 + (rowHeight - leadingHeight) / 2, width: leadingWidth, height: leadingHeight)
            buttons += Self.rail(choice.leading, columns: choice.leadingColumns, in: rect)
        }
        if !choice.trailing.isEmpty {
            let rect = CGRect(x: trailingX, y: y0 + (rowHeight - trailingHeight) / 2, width: trailingWidth, height: trailingHeight)
            buttons += Self.rail(choice.trailing, columns: choice.trailingColumns, in: rect)
        }
        for (index, row) in choice.rows.enumerated() {
            let width = Self.rowWidth(row)
            let y = y0 + rowHeight + m + CGFloat(index) * (Self.buttonHeight + m)
            buttons += Self.row(row, at: CGPoint(x: safe.midX - width / 2, y: y))
        }
    }

    /// Upright: one rail of everything at the right edge of the safe area, and the field from the top of the screen
    /// down to the safe area's bottom, as big as it can be while clear of the status bar and the cameras.
    private mutating func upToTop(in safe: CGRect, avoid: [CGRect]) {
        let m = Self.margin
        upright = true
        let groups = Group.allCases
        let railRoom = safe.height - 2 * m
        let columns = (1...6).first { Self.railHeight(groups, columns: $0) <= railRoom } ?? 6
        let railWidth = Self.railWidth(columns)
        let railX = safe.maxX - m - railWidth
        buttons += Self.rail(groups, columns: columns, in: CGRect(x: railX, y: safe.minY + m, width: railWidth, height: railRoom))

        let aspect = 1 / Self.fieldAspect
        let left = safe.minX + m
        let right = railX - m
        let top = m
        let bottom = safe.maxY - m

        // Either keep the field's top at the screen's top and its right edge left of whatever is up there, or start it
        // below everything up there; the bigger field wins.
        let inTheWay = avoid.filter { $0.maxX > left && $0.minY < bottom && $0.maxY > top }
        let besideRight = inTheWay.map { $0.minX - m }.reduce(right, min)
        let belowTop = inTheWay.map { $0.maxY + m }.reduce(top, max)
        let besides = Self.fit(aspect: aspect, in: CGRect(x: left, y: top, width: besideRight - left, height: bottom - top), alignRight: true)
        let below = Self.fit(aspect: aspect, in: CGRect(x: left, y: belowTop, width: right - left, height: bottom - belowTop), alignRight: true)
        field = besides.width * besides.height >= below.width * below.height ? besides : below
    }

    /// The tools are in the system's bar; under the field, the colours from its left edge and the match from its right.
    private mutating func toolsInBar(in safe: CGRect) {
        let m = Self.margin
        upright = safe.height > safe.width
        let aspect = upright ? 1 / Self.fieldAspect : Self.fieldAspect
        let box = CGRect(x: safe.minX + m, y: safe.minY + m, width: safe.width - 2 * m, height: safe.height - 3 * m - Self.buttonHeight)
        var fitted = Self.fit(aspect: aspect, in: box, alignRight: false)
        fitted.origin.x = box.minX + (box.width - fitted.width) / 2
        fitted.origin.y = box.minY + (box.height - fitted.height) / 2
        field = fitted
        buttons += Self.row([.colors], at: CGPoint(x: fitted.minX, y: fitted.maxY + m))
        buttons += Self.row([.match], at: CGPoint(x: fitted.maxX - Self.rowWidth([.match]), y: fitted.maxY + m))
    }

    /// The colours are in the system's bar; everything else in one rail at the right edge, the field filling the rest.
    private mutating func colorsInBar(in safe: CGRect) {
        let m = Self.margin
        upright = safe.height > safe.width
        let groups: [Group] = [.tools, .history, .match, .more]
        let railRoom = safe.height - 2 * m
        let columns = (1...6).first { Self.railHeight(groups, columns: $0) <= railRoom } ?? 6
        let railWidth = Self.railWidth(columns)
        let railX = safe.maxX - m - railWidth
        buttons += Self.rail(groups, columns: columns, in: CGRect(x: railX, y: safe.minY + m, width: railWidth, height: railRoom))

        let aspect = upright ? 1 / Self.fieldAspect : Self.fieldAspect
        let box = CGRect(x: safe.minX + m, y: safe.minY + m, width: railX - m - (safe.minX + m), height: railRoom)
        var fitted = Self.fit(aspect: aspect, in: box, alignRight: true)
        fitted.origin.y = box.minY + (box.height - fitted.height) / 2
        field = fitted
    }

    // MARK: - StrategyLayout, ported

    struct Choice {
        var upright: Bool
        var field: CGSize
        var leading: [Group]
        var leadingColumns: Int
        var trailing: [Group]
        var trailingColumns: Int
        var rows: [[Group]]
    }

    private struct Candidate {
        var leading: [Group] = []
        var trailing: [Group] = []
        var rows: [[Group]] = []
    }

    static func choose(size: CGSize) -> Choice {
        let upright = size.height > size.width
        let aspect = upright ? 1 / fieldAspect : fieldAspect
        let candidates: [Candidate] = [
            Candidate(trailing: [.tools, .colors, .history, .match, .more]),
            Candidate(trailing: [.tools, .history, .match, .more], rows: [[.colors]]),
            Candidate(leading: [.tools, .history, .match, .more], trailing: [.colors]),
            Candidate(rows: [[.tools, .colors, .history, .match, .more]]),
            Candidate(rows: [[.tools, .history, .match, .more], [.colors]]),
        ]
        var best: Choice?
        for candidate in candidates {
            guard let choice = fit(candidate, in: size, aspect: aspect, upright: upright) else { continue }
            if let current = best, current.field.width * current.field.height >= choice.field.width * choice.field.height {
                continue
            }
            best = choice
        }
        return best
            ?? Choice(
                upright: upright,
                field: .zero,
                leading: [],
                leadingColumns: 0,
                trailing: [],
                trailingColumns: 0,
                rows: candidates.last!.rows
            )
    }

    private static func fit(_ candidate: Candidate, in size: CGSize, aspect: CGFloat, upright: Bool) -> Choice? {
        let rowsHeight = CGFloat(candidate.rows.count) * (buttonHeight + margin)
        let boxHeight = size.height - 2 * margin - rowsHeight
        guard boxHeight > 0 else { return nil }
        guard candidate.rows.allSatisfy({ rowWidth($0) <= size.width - 2 * margin }) else { return nil }

        func columns(_ rail: [Group]) -> Int? {
            if rail.isEmpty { return 0 }
            return (1...6).first { railHeight(rail, columns: $0) <= boxHeight }
        }
        func width(_ columns: Int) -> CGFloat {
            columns == 0 ? 0 : railWidth(columns) + margin
        }
        guard let leading = columns(candidate.leading), let trailing = columns(candidate.trailing) else { return nil }

        let boxWidth = size.width - 2 * margin - width(leading) - width(trailing)
        guard boxWidth > 0 else { return nil }
        let field =
            boxWidth / boxHeight > aspect
            ? CGSize(width: boxHeight * aspect, height: boxHeight)
            : CGSize(width: boxWidth, height: boxWidth / aspect)
        return Choice(
            upright: upright,
            field: field,
            leading: candidate.leading,
            leadingColumns: leading,
            trailing: candidate.trailing,
            trailingColumns: trailing,
            rows: candidate.rows
        )
    }

    static func railWidth(_ columns: Int) -> CGFloat {
        columns == 0 ? 0 : CGFloat(columns) * buttonWidth + CGFloat(columns - 1) * spacing
    }

    static func railHeight(_ groups: [Group], columns: Int) -> CGFloat {
        let lines = groups.map { group -> CGFloat in
            let count = CGFloat((group.count + columns - 1) / columns)
            return count * buttonHeight + (count - 1) * spacing
        }
        return lines.reduce(0, +) + CGFloat(groups.count - 1) * groupGap
    }

    static func rowWidth(_ groups: [Group]) -> CGFloat {
        let widths = groups.map { CGFloat($0.count) * buttonWidth + CGFloat($0.count - 1) * spacing }
        return widths.reduce(0, +) + CGFloat(groups.count - 1) * groupGap
    }

    // MARK: - Placing buttons

    /// The biggest rectangle of [aspect] (width over height) in [box], at its top, against its right or left edge.
    private static func fit(aspect: CGFloat, in box: CGRect, alignRight: Bool) -> CGRect {
        guard box.width > 0, box.height > 0 else { return .zero }
        let size =
            box.width / box.height > aspect
            ? CGSize(width: box.height * aspect, height: box.height)
            : CGSize(width: box.width, height: box.width / aspect)
        return CGRect(x: alignRight ? box.maxX - size.width : box.minX, y: box.minY, width: size.width, height: size.height)
    }

    /// A rail's groups spread down [rect], the first at the top and the last at the bottom.
    private static func rail(_ groups: [Group], columns: Int, in rect: CGRect) -> [Placed] {
        let heights = groups.map { railHeight([$0], columns: columns) }
        let free = rect.height - heights.reduce(0, +)
        let between = groups.count > 1 ? max(groupGap, free / CGFloat(groups.count - 1)) : 0
        var placed: [Placed] = []
        var y = rect.minY
        for (group, height) in zip(groups, heights) {
            for (index, kind) in kinds(group).enumerated() {
                let line = CGFloat(index / columns)
                let column = CGFloat(index % columns)
                let frame = CGRect(
                    x: rect.minX + column * (buttonWidth + spacing),
                    y: y + line * (buttonHeight + spacing),
                    width: buttonWidth,
                    height: buttonHeight
                )
                placed.append(Placed(rect: frame, kind: kind))
            }
            y += height + between
        }
        return placed
    }

    /// A row of groups from [origin], left to right.
    private static func row(_ groups: [Group], at origin: CGPoint) -> [Placed] {
        var placed: [Placed] = []
        var x = origin.x
        for group in groups {
            for kind in kinds(group) {
                placed.append(Placed(rect: CGRect(x: x, y: origin.y, width: buttonWidth, height: buttonHeight), kind: kind))
                x += buttonWidth + spacing
            }
            x += groupGap - spacing
        }
        return placed
    }

    private static func kinds(_ group: Group) -> [Kind] {
        switch group {
        case .tools:
            Palette.tools.map { .symbol($0.symbol, selected: $0.title == "Pen") }
        case .colors:
            Palette.all.map { .color($0.color, selected: $0.name == "Red") }
        case .history:
            [.symbol("arrow.uturn.backward", selected: false), .symbol("arrow.uturn.forward", selected: false)]
        case .match:
            [.text("Q12"), .symbol("plus.square.on.square", selected: false)]
        case .more:
            [.more]
        }
    }
}
