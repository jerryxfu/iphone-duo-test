# iPhone Duo test

A small app that measures what iOS 27.1 reports on the iPhone Duo, for TechNexus's Duo layouts (TechNexus #87). It
draws and logs the safe area, the regions iOS asks content to keep clear of (the fold, the cameras), where toolbar
buttons go, Apple's side-by-side container, and stand-ins for TechNexus's Strategy board.

It needs Xcode-beta 27.1: every Duo API is in the iOS 27.1 SDK. It has no Kotlin, so building it can't leave a Kotlin
framework that Xcode 27.0 then refuses, as TechNexus's can.

## Tabs

- **Measure**: the whole window, with the safe area (green, dashed), the fold (red), the cameras and anything else iOS
  reports as covered (orange), and UIKit's status bar frame (blue). Inactive regions are paler and dashed
- **Toolbar**: a list in a navigation stack with toolbar buttons: Scan, a narrow Q7 header like the Schedule's, the six
  colours, the tools. Pickers for which buttons, what shrinks first when the column is short, and the title
- **Side by side**: `ArrangementView` with a Schedule and a Pit stand-in, each showing its own size
- **Field**: the Strategy board in five layouts, from More: *As now* (TechNexus's `StrategyLayout`, ported), *Rail at the
  edge*, *Up to the top*, *Tools in the bar*, *Colours in the bar*. The field shows its size in points

## Building and running

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild -project DuoTest.xcodeproj -scheme DuoTest -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build ARCHS=arm64 build
xcrun simctl install <sim> build/Build/Products/Debug-iphonesimulator/DuoTest.app
xcrun simctl launch <sim> net.jerryxf.iphone-duo-test -tab field -mode "Up to the top"
```

It signs to run locally, with no team, so it runs on simulators only. Launch arguments pick the starting state: `-tab`
(`measure`, `toolbar`, `side`, `field`), `-mode`, `-items`, `-compression`, `-title`, `-axes`, `-bottom YES`.
Folding and turning the simulator is done in Xcode's Device Hub; `simctl` can't.

Every new measurement is appended to `Documents/measurements.jsonl` in the app's container, one JSON object a line:

```bash
cat "$(xcrun simctl get_app_container <sim> net.jerryxf.iphone-duo-test data)/Documents/measurements.jsonl"
```

## What it found

iOS 27.1 simulator, Xcode-beta 27.1 (27A9269), 16 Oct 2026. Points throughout.

### Closed, upright

- **The screen is 466 × 678.** The column down the right is **84 wide**; the safe area is 382 × 644, from the very top
  (top margin 0) to 34 above the bottom
- **iOS reports the camera and the clock as one region to keep clear**, 84 × 170 at the top right, besides the camera's
  own 37 × 37 circle. UIKit's status bar frame is a useless 466 × 2 strip across the top
- **Toolbar buttons go into the column**, in a glass pill under the clock: Scan, and the narrow Q7 header (Q7, OD and its
  dot, "↻ now") with `axisBehavior(.verticalPreferred)`, which fits once its last line can't wrap
- **Hiding the navigation bar hides the column's buttons too.** Removing the title instead (`.toolbar(removing:
  .title)`) keeps them and leaves a 24-point bar at the top, against 82 with a title
- **The column holds about four buttons before "…"** with the tab bar beside them: four of six colours, or four tools.
  With `.toolbarVerticalCompressionBehavior(.prefersToolbarItems)` the tab bar shrinks to the selected tab alone, and
  all six colours fit, or six tools and undo
- **Side by side shows only the first view** (the Schedule), as Apple describes for a space taller than wide
- **Field**: *As now* 290 × 596, colours in a row under the field. *Colours in the bar* 298 × 612, about 5% more, with
  the tab bar down to one button. *Tools in the bar* 279 × 572

### Open, upright, flat

- **The screen is 669 × 951**, regular by regular, with no vertical bar: the tab bar is at the bottom. The safe area
  leaves 82 at the top and 83 at the bottom, nothing at the sides
- **iOS reports only the clock's corner as covered**: 134 × 82 at the top right. The rest of the top band is free
- **The fold is reported while flat**, inactive: 669 × 40 across the middle, at 455.5. The inner camera is an inactive
  37 × 58 region at the right edge, at 611, 677
- **Toolbar buttons sit in the top band, left of the clock**, in a horizontal bar that adds no height: the toolbar tab's
  content starts at 82 with the title removed, as without any bar
- **Side by side shows only the first view**, the space being taller than wide
- **Field**: *As now* 379 × 778, one rail of everything beside it. *Rail at the edge* the same size. *Up to the top*
  419 × 860, about 22% more: the field from 4 below the top of the screen, left of the clock's corner, the rail at the
  right edge from under it. *Tools in the bar* 359 × 738, the tools in the top band and the colours in a row under the
  field

### Folded like a laptop, upright

- **The fold turns active**, still 669 × 40 at 455.5, so the halves are 82 to 455.5 above it and 495.5 to 868 below
  (373.5 and 372.5 tall, inside the bars). Nothing else changes: the screen size, the safe area, the toolbar in the top
  band, the field's layouts, which take no notice of the fold
- **Side by side, allowed both ways, stacks the two views around the fold**: the first above it, the second below, the
  fold's 40 between them. Flat, the same setting stacks them too, 393 each with no gap, so a layout only for the folded
  phone has to check the fold itself (`reservedRegions(kind: .division)`, `isActive`)
- **Side by side only** keeps a single view, as flat

### Open in landscape, flat

- **The screen is 951 × 669**, regular by regular, and the column is back on the right, 84 wide: the safe area leaves
  nothing at the top or the left, 34 at the bottom and 84 at the right. The clock's corner is 84 × 120 at the top right
- **The fold is a vertical band**, 40 × 669 at 455.5, inactive while flat. The inner camera is an inactive 58 × 37
  region at 677, 21
- **Side by side splits into two equal halves**, 433.5 wide each, the Schedule left and the Pit right, under a 82-high
  bar that holds the title over the left half; the toolbar buttons are in the column. Flat, the split is at the middle
  of the safe area (433.5), not at the fold (455.5 to 495.5)
- **Field**: *As now* 859 × 418, one row of every control under it. *Tools in the bar*, the colours in a row under the
  field from its left edge: the same 859 × 418. Next to the tab bar the column holds four tools and "…"; with the tab bar
  shrunk to one button it holds all six tools, then "…" (redo, the match, the robots), then undo. *Colours in the bar*
  811 × 395, since the rail beside the field costs width

### Folded like a book, in landscape

- **The fold turns active**, still 40 × 669 at 455.5. Nothing else changes: the screen, the safe area, the column
- **Side by side moves the split onto the fold** by itself: the Schedule takes the left page, 0 to 455.5, and the Pit the
  right one, 495.5 to 867, 371.5 wide since the column is on that side too
- **Field**: unchanged, 859 × 418 across the fold, in *As now* and *Tools in the bar*

### Closed, in landscape

- **The screen is 678 × 466**, compact by compact. The column is on the right, 84 wide, with no clock in it; the camera
  is at the bottom right, inside an 84 × 82 region to keep clear
- **Scan and the Q7 header fit at the top of the column**
- **The column is short**: next to the tab bar it holds one tool and "…"; with the tab bar shrunk, four tools and "…"
- **Side by side shows only the first view**, though the space is wider than tall: compact by compact
- **Field**: *As now* 586 × 285. *Tools in the bar*, with the colours from the field's left edge and the match and the
  robots button against its right edge underneath (Jerry, 16 Oct): the same size, four tools in the column

### What it means for TechNexus

- **Nothing has to guess**: the fold, the clock's corner and the cameras all come from `reservedRegions`, and the
  column's side from `toolbarVerticalEdge`, `nil` on the open phone upright
- **Into the column means a toolbar item in a navigation stack**, its title removed: the Schedule gains a 24-point bar
  at the top of the closed phone, against the header's height now. On the open phone upright the same items sit in the
  clock's band, left of the clock, at no cost
- **More than four buttons in the column means the tab bar shrinking** to the selected tab
  (`.toolbarVerticalCompressionBehavior(.prefersToolbarItems)`), as it would for the six colours or the six tools
- **Schedule and Pit side by side** comes from `ArrangementView` with `.split.axes(.horizontal)`: two halves only on the
  open phone in landscape, at the fold when folded like a book, a single view everywhere else measured here
