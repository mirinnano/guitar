import AppKit
import GuitarToolsCore
import SwiftUI
import XCTest
@testable import GuitarToolsMacApp

@MainActor
final class SongCoachLayoutTests: XCTestCase {
    func testPracticeDeskRendersAtCompactAndWideSizes() throws {
        let chart = ChordChartParser.parse(
            "{title:切替トレーニング}\n{tempo:120}\n[C]one [Am]two | [F]three [G]four |",
            fallbackTitle: "Layout test",
            sourceURL: URL(string: "https://example.invalid/coach-layout")
        )
        for (width, height, scheme, name) in [(780, 740, ColorScheme.light, "light"), (1_040, 740, .dark, "dark"), (700, 600, .dark, "small")] {
            let root = SongCoachView(chart: chart, sourceBPM: 120, initialBeat: 0) { _, _ in }
                .environment(\.colorScheme, scheme)
            let host = NSHostingView(rootView: root)
            host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            host.frame = NSRect(x: 0, y: 0, width: width, height: height)
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            XCTAssertGreaterThan(png.count, 1_000)
            // Local review artifacts only; no windows, recording, or external uploads.
            let url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("guitar-coach-\(name).png")
            try png.write(to: url)
        }
    }
}
