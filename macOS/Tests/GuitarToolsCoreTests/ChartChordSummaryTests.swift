import AppKit
import GuitarToolsCore
import SwiftUI
import XCTest
@testable import GuitarToolsMacApp

@MainActor
final class ChartChordSummaryTests: XCTestCase {
    func testListsUniqueChordsInFirstAppearanceOrderIncludingUnsupportedSymbols() {
        let chart = makeChart(["G", "C", "G", "N.C.", "C", "Am7", "Cunknown"])
        XCTAssertEqual(ChartChordSummaryView.symbols(in: chart), ["G", "C", "Am7", "Cunknown"])
        XCTAssertTrue(ChartChordSummaryView.symbols(in: makeChart([])).isEmpty)
    }

    func testPermanentDiagramsRenderAtInspectorWidths() throws {
        let chart = makeChart(["AM7", "F#m7/A", "Bsus4", "B", "G#m", "C#add9", "C#m",
                               "A", "G#M7", "C#", "F#", "D#m", "D", "E", "G#m7"])
        for (width, scheme) in [(CGFloat(300), ColorScheme.light), (350, .dark), (430, .light)] {
            let host = NSHostingView(rootView: ChartChordSummaryView(chart: chart)
                .frame(width: width, height: 720)
                .environment(\.colorScheme, scheme)
                .background(Color(nsColor: .windowBackgroundColor)))
            host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            host.frame.size = CGSize(width: width, height: host.fittingSize.height)
            host.layoutSubtreeIfNeeded()
            XCTAssertLessThanOrEqual(host.fittingSize.width, width + 0.5)
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: "/tmp/guitar-used-chords-\(Int(width)).png"))
        }

    }

    private func makeChart(_ symbols: [String]) -> ChordChart {
        ChordChart(sourceTitle: "Summary", title: "Summary",
                   lines: [ChartLine(segments: symbols.map { ChartSegment(chord: $0, text: "") })])
    }
}
