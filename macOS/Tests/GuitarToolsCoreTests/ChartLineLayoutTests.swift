import AppKit
import GuitarToolsCore
import SwiftUI
import XCTest
@testable import GuitarToolsMacApp

@MainActor
final class ChartLineLayoutTests: XCTestCase {
    func testWrappingKeepsPairsInOrderAndWithinReadingWidth() {
        let frames = ChartLineLayout.frames(for: [CGSize(width: 180, height: 50),
                                                  CGSize(width: 160, height: 80),
                                                  CGSize(width: 180, height: 50)], width: 350)
        XCTAssertEqual(frames.map(\.minX), [0, 180, 0])
        XCTAssertEqual(frames.map(\.minY), [0, 0, 94])
        XCTAssertTrue(frames.allSatisfy { $0.maxX <= 350 })
        XCTAssertGreaterThanOrEqual(frames[2].minY, frames[1].maxY + 14)
        XCTAssertEqual(ChartLineLayout.frames(for: [], width: 350), [])
    }

    func testLongLyricSegmentGrowsVerticallyWithoutChangingTiming() throws {
        let line = ChartLine(segments: [ChartSegment(chord: "C", text: String(repeating: "長い歌詞を読みやすく表示する ", count: 12))])
        let timeline = ChordTimelineBuilder.build(chart: ChordChart(sourceTitle: "Layout", title: "Layout", lines: [line]))
        let original = timeline
        let heights = [CGFloat(320), 900].map { width in
            let host = NSHostingView(rootView: chartLine(line).frame(width: width))
            host.frame.size = CGSize(width: width, height: 600)
            host.layoutSubtreeIfNeeded()
            let size = host.fittingSize
            XCTAssertLessThanOrEqual(size.width, width + 0.5)
            return size.height
        }
        XCTAssertGreaterThan(heights[0], heights[1], "Narrow viewports must wrap, not clip horizontally")
        XCTAssertGreaterThan(heights[1], 50)
        XCTAssertEqual(ChordTimelineBuilder.build(chart: ChordChart(sourceTitle: "Layout", title: "Layout", lines: [line])), original)
    }

    func testDenseChordLineRendersAtSmallAndLargeTextSizesWithOptionalDiagrams() throws {
        let line = ChartLine(segments: ["C", "G/B", "Am7", "Em", "F", "G", "C/E", "Dm7", "Gsus4"].map {
            ChartSegment(chord: $0, text: "歌詞の続き ")
        })
        for (width, fontSize, diagrams, scheme) in [(CGFloat(360), CGFloat(28), false, ColorScheme.light),
                                                   (CGFloat(900), CGFloat(20), false, ColorScheme.dark),
                                                   (CGFloat(360), CGFloat(20), true, ColorScheme.dark)] {
            let host = NSHostingView(rootView: chartLine(line, fontSize: fontSize, diagrams: diagrams)
                .padding(20).frame(width: width)
                .environment(\.colorScheme, scheme)
                .background(Color(nsColor: .windowBackgroundColor)))
            host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            host.frame.size = CGSize(width: width, height: host.fittingSize.height)
            host.layoutSubtreeIfNeeded()
            XCTAssertLessThanOrEqual(host.fittingSize.width, width + 0.5)
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            XCTAssertGreaterThan(png.count, 1_000)
            try png.write(to: URL(fileURLWithPath: "/tmp/guitar-chart-\(Int(width))-\(Int(fontSize))-\(diagrams).png"))
        }
    }

    func testInstrumentalBarLinesStayOnTheChordRow() {
        let instrumental = ChartLine(segments: [ChartSegment(chord: "C", text: "  │"),
                                                ChartSegment(chord: "G", text: "  │")])
        let lyric = ChartLine(segments: [ChartSegment(chord: "C", text: "歌詞"),
                                         ChartSegment(chord: "G", text: "続き")])
        let heights = [instrumental, lyric].map { line in
            let host = NSHostingView(rootView: chartLine(line).frame(width: 400))
            host.layoutSubtreeIfNeeded()
            return host.fittingSize.height
        }
        XCTAssertLessThan(heights[0], heights[1], "Instrumental bars do not need an empty lyric row")
    }

    private func chartLine(_ line: ChartLine, fontSize: CGFloat = 20, diagrams: Bool = false) -> some View {
        ViewerChartLine(line: line, lineIndex: 0, activeEvent: nil, anchors: [], calibrationMode: false,
                        showFingerings: diagrams, fontSize: fontSize, events: [], previousSymbols: [:], onAnchor: { _ in })
    }
}
