import AppKit
import GuitarToolsCore
import SwiftUI
import XCTest
@testable import GuitarToolsMacApp

@MainActor
final class ChordVoicingLayoutTests: XCTestCase {
    func testPickerAndSelectedInlineDiagramRenderWithoutWindows() throws {
        let defaults = UserDefaults(suiteName: "guitar-voicing-layout-\(UUID().uuidString)")!
        defer { defaults.removeObject(forKey: ChordVoicingPreferencesStore.storageKey) }
        let preferences = ChordVoicingPreferencesStore(defaults: defaults)
        let selected = try XCTUnwrap(GuitarChordData(symbol: "C/G")?.voicings.last)
        preferences.select(selected.id, for: "C/G")
        for (scheme, name) in [(ColorScheme.light, "light"), (.dark, "dark")] {
            let view = ChordVoicingPickerView(symbol: "C/G", previousSymbol: "Am", preferences: preferences)
                .environment(\.colorScheme, scheme)
            let host = NSHostingView(rootView: view)
            host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            host.frame = NSRect(x: 0, y: 0, width: 620, height: 530)
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            XCTAssertGreaterThan(png.count, 1_000)
            try png.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("guitar-voicings-\(name).png"))
        }
        let diagram = NSHostingView(rootView: ChordFingeringView(symbol: "C/G", inline: true, preferences: preferences))
        diagram.frame = NSRect(x: 0, y: 0, width: InlineChordFingering.width, height: InlineChordFingering.height)
        diagram.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(diagram.fittingSize.width, InlineChordFingering.width)
        XCTAssertLessThanOrEqual(diagram.fittingSize.height, InlineChordFingering.height)
    }
}
