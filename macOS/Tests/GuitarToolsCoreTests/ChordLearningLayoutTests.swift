import AppKit
import GuitarToolsCore
import SwiftUI
import XCTest
@testable import GuitarToolsMacApp

@MainActor
final class ChordLearningLayoutTests: XCTestCase {
    func testLearningDeskRendersStudyHiddenAnswerAndResultWithoutAudioOrWindows() throws {
        let suite = "guitar-learning-layout-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = ChordLearningModel(progressStore: ChordLearningProgressStore(defaults: defaults))
        let before = defaults.data(forKey: ChordLearningProgressStore.storageKey)
        for (width, scheme) in [(CGFloat(560), ColorScheme.light), (920, .dark)] {
            try render(ChordLearningView(model: model), width: width, scheme: scheme, name: "overview")
        }
        XCTAssertEqual(defaults.data(forKey: ChordLearningProgressStore.storageKey), before,
                       "Displaying the desk must not record practice")

        model.startCustom(symbols: ["C"], title: "Cを覚える")
        XCTAssertEqual(model.phase, .studying)
        try renderBoth(model, name: "study")
        model.hideDiagram()
        XCTAssertEqual(model.phase, .recalling)
        try renderBoth(model, name: "hidden")
        model.revealAnswer()
        XCTAssertEqual(model.phase, .revealed)
        try renderBoth(model, name: "answer")
        model.rate(.remembered)
        XCTAssertEqual(model.phase, .completed)
        try renderBoth(model, name: "result")
        XCTAssertEqual(model.sessionRecalled, 0, "Immediate study is not a delayed recall success")
        XCTAssertTrue(model.hasCustomSource)
        XCTAssertEqual(model.sourceSymbols, ["C"])
    }

    func testLibraryEntryAndDueReviewRenderWithPinnedConventionalBarre() throws {
        let suite = "guitar-learning-review-layout-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ChordLearningProgressStore(defaults: defaults)
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let voicing = try XCTUnwrap(GuitarChordData(symbol: "F")?.voicings.first)
        let key = try XCTUnwrap(GuitarChordData.selectionKey(for: "F"))
        store.save(ChordLearningProgress(nextReviewAt: now.addingTimeInterval(-1),
                                        lastPracticedAt: now.addingTimeInterval(-86_400)),
                   selectionKey: key, voicingID: voicing.id)
        let model = ChordLearningModel(progressStore: store, now: { now })
        try render(ChordsView(learning: model), width: 560, scheme: .light, name: "library")
        model.startCustom(symbols: ["F"], title: "曲のコードを覚える")
        XCTAssertEqual(model.phase, .recalling)
        XCTAssertTrue(model.canCreditRecall)
        XCTAssertEqual(model.currentVoicing?.id, voicing.id)
        model.revealAnswer()
        try renderBoth(model, name: "due-answer")
        model.rate(.remembered)
        XCTAssertEqual(model.sessionRecalled, 1)
    }

    func testAudioPreferenceChannelBoundsDoNotClampSavedUR12Ch2ToMono() throws {
        let suite = "guitar-audio-channel-bounds-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppPreferencesStore(defaults: defaults)
        store.update { $0.audio.inputDeviceUID = "saved-ur12"; $0.audio.selectedChannel = 1 }
        XCTAssertEqual(AppPreferencesStore(defaults: defaults).value.audio.selectedChannel, 1)
        store.update { $0.audio.selectedChannel = Int.max }
        XCTAssertEqual(AppPreferencesStore(defaults: defaults).value.audio.selectedChannel, 63)
        store.update { $0.audio.selectedChannel = -1 }
        XCTAssertEqual(AppPreferencesStore(defaults: defaults).value.audio.selectedChannel, 0)
    }

    private func renderBoth(_ model: ChordLearningModel, name: String) throws {
        for (width, scheme) in [(CGFloat(560), ColorScheme.light), (920, .dark)] {
            try render(ChordLearningView(model: model), width: width, scheme: scheme, name: name)
        }
    }

    private func render<Content: View>(_ view: Content, width: CGFloat, scheme: ColorScheme, name: String) throws {
        // Supply the actual detail viewport. Unconstrained fittingSize asks
        // ViewThatFits for its preferred wide layout, not its narrow layout.
        let host = NSHostingView(rootView: view.environment(\.colorScheme, scheme)
            .background(Color(nsColor: .windowBackgroundColor))
            .frame(width: width, height: 820))
        host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 820)
        host.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(host.fittingSize.width, width + 0.5, name)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(png.count, 1_000, name)
        let suffix = scheme == .dark ? "dark" : "light"
        try png.write(to: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("guitar-learning-\(name)-\(suffix).png"))
    }
}
