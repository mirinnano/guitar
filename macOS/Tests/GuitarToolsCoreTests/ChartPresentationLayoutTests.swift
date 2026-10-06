import AppKit
import GuitarToolsCore
import SwiftUI
import XCTest
@testable import GuitarToolsMacApp

@MainActor
final class ChartPresentationLayoutTests: XCTestCase {
    func testSearchAndLongRecentTitlesRenderInNarrowAndWideLayouts() throws {
        let recent = [ChordWikiSearchResult(
            title: "Little Busters!（PCゲーム「リトルバスターズ!」OP）",
            url: URL(string: "https://ja.chordwiki.org/wiki/Little%20Busters!")!, artist: "Rita")]
        for (width, scheme) in [(CGFloat(420), ColorScheme.light), (800, .dark)] {
            try render(ChartSearchStateView(query: .constant("Little Busters!"),
                submittedQuery: nil, error: nil, onSearch: {}, recentCharts: recent,
                onOpenRecent: { _ in }), width: width, scheme: scheme, name: "search")
        }
        try render(ChartSearchStateView(query: .constant("検索語"), submittedQuery: "検索語",
            error: "接続を確認して、もう一度検索してください。", onSearch: {}),
            width: 420, scheme: .light, highContrast: true, name: "search-error")
    }

    func testChartAndFloatingTransportRenderWithLongTitleAndActiveLoop() async throws {
        let chart = ChordChartParser.parse(String(repeating: "[C]歌詞の続き [G/B]長い歌詞 [Am7]次のコード [F]おわり\n", count: 16),
            fallbackTitle: "長い曲名でも譜面と再生コントロールを読みやすく表示する")
        let model = ChordWikiViewerModel(client: PresentationClient(chart: chart))
        model.open(ChordWikiSearchResult(title: chart.title, url: URL(string: "https://ja.chordwiki.org/wiki/Layout")!))
        for _ in 0..<100 where model.chart == nil { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertNotNil(model.chart)
        model.useFourBarLoop()
        defer { model.stop() }
        for (width, scheme) in [(CGFloat(380), ColorScheme.light), (880, .dark)] {
            try render(ChordWikiViewerView(model: model), width: width, scheme: scheme,
                name: "viewer")
        }
    }

    private func render<V: View>(_ view: V, width: CGFloat, scheme: ColorScheme,
                                highContrast: Bool = false, name: String) throws {
        let host = NSHostingView(rootView: view
            .environment(\.colorScheme, scheme)
            .frame(width: width, height: 720)
            .background(Color(nsColor: .windowBackgroundColor)))
        host.appearance = NSAppearance(named: highContrast ? .accessibilityHighContrastAqua : (scheme == .dark ? .darkAqua : .aqua))
        // Validate layout in a window-backed context without showing a test window.
        // System-composited glass still needs visual checking in the running app.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 720),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = host.appearance
        window.contentView = host
        defer { window.contentView = nil; window.close() }
        host.frame.size = CGSize(width: width, height: 720)
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        XCTAssertLessThanOrEqual(host.fittingSize.width, width + 0.5)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(png.count, 1_000)
        try png.write(to: URL(fileURLWithPath: "/tmp/guitar-liquid-\(name)-\(Int(width)).png"))
    }
}

private struct PresentationClient: ChordWikiClientProtocol {
    let chart: ChordChart
    func search(query: String) async throws -> [ChordWikiSearchResult] { [] }
    func loadChart(_ result: ChordWikiSearchResult) async throws -> ChordChart { chart }
}
