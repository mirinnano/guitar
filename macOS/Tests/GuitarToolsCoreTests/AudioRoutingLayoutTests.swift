import AppKit
import SwiftUI
import XCTest
@testable import GuitarToolsMacApp

@MainActor
final class AudioRoutingLayoutTests: XCTestCase {
    func testTunerRoutesRenderWithoutStartingInputOrPlayingSound() throws {
        let defaults = UserDefaults(suiteName: "guitar-routing-layout-\(UUID().uuidString)")!
        defer { defaults.removeObject(forKey: AppPreferencesStore.storageKey) }
        let preferences = AppPreferencesStore(defaults: defaults)
        let audio = AudioInputModel()
        let output = AudioOutputModel(preferencesStore: preferences)
        let original = preferences.value
        XCTAssertFalse(audio.isRunning)
        XCTAssertFalse(output.isPlaying)
        for (width, scheme, name) in [(780, ColorScheme.light, "light"), (1_040, .dark, "dark")] {
            let root = TunerView(audio: audio, output: output, preferencesStore: preferences)
                .environment(\.colorScheme, scheme)
                .background(Color(nsColor: .windowBackgroundColor))
            let host = NSHostingView(rootView: root)
            host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            host.frame = NSRect(x: 0, y: 0, width: width, height: 850)
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            XCTAssertGreaterThan(png.count, 1_000)
            try png.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("guitar-tuner-routing-\(name).png"))
        }
        XCTAssertFalse(audio.isRunning)
        XCTAssertFalse(output.isPlaying)
        XCTAssertEqual(preferences.value, original)
        // Enumerating endpoints does not record the microphone or make a playback claim.
        let detected = UR12RoutingProfile.configuration(inputs: audio.inputDevices, outputs: output.devices, preferredInputUID: nil)
        if let detected {
            XCTAssertTrue(audio.inputDevices.contains { $0.uid == detected.inputUID && $0.channelCount >= 2 })
            XCTAssertTrue(output.devices.contains { $0.uid == detected.outputUID && $0.channelCount >= 2 })
        }
    }
}
