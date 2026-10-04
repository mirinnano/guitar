import Foundation
import GuitarToolsCore
import XCTest
@testable import GuitarToolsMacApp

@MainActor
final class ChordVoicingPreferencesTests: XCTestCase {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "guitar-voicing-tests-\(UUID().uuidString)")!
    }

    func testSelectionPersistsAndResetRestoresStandard() throws {
        let defaults = defaults()
        defer { defaults.removeObject(forKey: ChordVoicingPreferencesStore.storageKey) }
        let store = ChordVoicingPreferencesStore(defaults: defaults)
        let data = try XCTUnwrap(GuitarChordData(symbol: "C"))
        XCTAssertGreaterThan(data.voicings.count, 1)
        let alternate = data.voicings[1]
        store.select(alternate.id, for: "C")
        XCTAssertEqual(store.presentation(for: "C").shape, alternate.shape)
        let restored = ChordVoicingPreferencesStore(defaults: defaults)
        XCTAssertEqual(restored.selectedID(for: "Cmaj"), alternate.id)
        restored.select(nil, for: "C")
        XCTAssertNil(restored.selectedID(for: "C"))
        XCTAssertEqual(restored.presentation(for: "C").shape, data.voicings.first?.shape)
    }

    func testEnharmonicAliasesShareSelectionButSlashBassDoesNot() throws {
        let defaults = defaults()
        defer { defaults.removeObject(forKey: ChordVoicingPreferencesStore.storageKey) }
        let store = ChordVoicingPreferencesStore(defaults: defaults)
        let data = try XCTUnwrap(GuitarChordData(symbol: "Bbmin"))
        let selected = try XCTUnwrap(data.voicings.last)
        store.select(selected.id, for: "Bbmin")
        XCTAssertEqual(store.selectedID(for: "A#m"), selected.id)
        XCTAssertNil(store.selectedID(for: "Bbmin/F"))
        XCTAssertNotEqual(GuitarChordData.selectionKey(for: "C6/9"), GuitarChordData.selectionKey(for: "C/G"))
    }

    func testForeignSelectionIsRejectedAndStaleSelectionFallsBack() throws {
        let defaults = defaults()
        defer { defaults.removeObject(forKey: ChordVoicingPreferencesStore.storageKey) }
        let store = ChordVoicingPreferencesStore(defaults: defaults)
        let g = try XCTUnwrap(GuitarChordData(symbol: "G")?.voicings.first)
        store.select(g.id, for: "C")
        store.select("invented", for: "C")
        store.select(g.id, for: "NC")
        XCTAssertTrue(store.selections.isEmpty)
        let key = try XCTUnwrap(GuitarChordData.selectionKey(for: "C"))
        defaults.set(try JSONEncoder().encode([key: "removed-voicing"]), forKey: ChordVoicingPreferencesStore.storageKey)
        let restored = ChordVoicingPreferencesStore(defaults: defaults)
        XCTAssertEqual(restored.presentation(for: "C").shape, ChordFingeringPresentation(symbol: "C").shape)
    }

    func testCorruptStorageDoesNotBreakDisplay() {
        let defaults = defaults()
        defer { defaults.removeObject(forKey: ChordVoicingPreferencesStore.storageKey) }
        defaults.set(Data("not JSON".utf8), forKey: ChordVoicingPreferencesStore.storageKey)
        XCTAssertTrue(ChordVoicingPreferencesStore(defaults: defaults).selections.isEmpty)
    }

    func testChartContextCrossesLinesAndStopsAtUnsafeOrNC() {
        func context(_ source: String) -> [Int: String] {
            let chart = ChordChartParser.parse(source, fallbackTitle: "Context", sourceURL: nil)
            return ChartVoicingContext.previousSymbols(timeline: ChordTimelineBuilder.build(chart: chart), lineIndex: 1)
        }
        XCTAssertTrue(context("[C]one\n[Am]two").values.contains("C"))
        XCTAssertTrue(context("[C]one [NC]rest\n[Am]two").isEmpty)
        XCTAssertTrue(context("{capo:2}\n[Cm((7)]one [G]two").isEmpty)
    }
}
