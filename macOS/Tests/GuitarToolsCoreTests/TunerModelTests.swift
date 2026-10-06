import AVFoundation
import CoreAudio
import Foundation
import GuitarToolsCore
import XCTest
@testable import GuitarToolsMacApp

/// Synthetic PCM only: these tests never request real microphone permission or open hardware.
@MainActor
final class TunerModelTests: XCTestCase {
    func testLowEIsDetectedFromSmallHALBuffers() async throws {
        let h = fixture()
        defer { h.model.stop(); h.audio.stop() }
        h.model.start()
        feed(h.capture, frequency: GuitarNote.frequency(forMIDI: 40), chunkSize: 128)
        await waitUntil { h.model.reading != nil }
        XCTAssertEqual(h.model.reading?.frequencyHz ?? 0, GuitarNote.frequency(forMIDI: 40), accuracy: 0.15)
        XCTAssertEqual(h.model.target?.string.stringNumber, 6)
    }

    func testExternalInputStopClearsTheReadingWithoutAnotherPCMFrame() async throws {
        let h = fixture()
        defer { h.model.stop(); h.audio.stop() }
        h.model.start()
        feed(h.capture, frequency: 220, chunkSize: 8_192)
        await waitUntil { h.model.reading != nil }
        XCTAssertNotNil(h.model.reading)
        h.audio.stop()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(h.model.reading)
        XCTAssertNil(h.model.target)
    }

    func testCalibrationRecomputesTheNoteAndTargetImmediately() async throws {
        let h = fixture()
        defer { h.model.stop(); h.audio.stop() }
        h.model.start()
        feed(h.capture, frequency: 440, chunkSize: 8_192)
        await waitUntil { h.model.reading != nil }
        let frequency = try XCTUnwrap(h.model.reading?.frequencyHz)
        h.model.a4Hz = 400
        XCTAssertEqual(h.model.reading, GuitarPitchReading.fromFrequency(frequency, a4Hz: 400))
        XCTAssertEqual(h.model.target, h.model.selectedTuning.closestString(frequencyHz: frequency, a4Hz: 400))
    }

    func testCustomTuningSurvivesPresetRoundTripAndModelRecreation() {
        let h = fixture()
        h.model.selectCustomTuning()
        h.model.changeCustomString(stringNumber: 6, semitones: -3)
        h.model.changeCustomString(stringNumber: 1, semitones: 2)
        let custom = h.model.selectedTuning
        h.model.setLockedString(6)
        h.model.setTuning(.standard)
        h.model.selectCustomTuning()
        XCTAssertEqual(h.model.selectedTuning, custom)
        XCTAssertNil(h.model.lockedStringNumber)
        h.model.setTuning(.standard)
        let restored = TunerModel(audio: h.audio, preferencesStore: h.preferences)
        restored.selectCustomTuning()
        XCTAssertEqual(restored.selectedTuning, custom)
    }

    func testVisibleTunerObservesExternalStartWithoutStartingInputItself() async {
        let h = fixture()
        defer { h.model.stop(); h.audio.stop() }
        h.model.start(requestInput: false)
        XCTAssertFalse(h.audio.isRunning)
        XCTAssertNil(h.capture.onFrame)
        h.audio.toggle()
        feed(h.capture, frequency: 110, chunkSize: 128)
        await waitUntil { h.model.reading != nil }
        XCTAssertEqual(h.model.reading?.frequencyHz ?? 0, 110, accuracy: 0.2)
        XCTAssertEqual(h.model.target?.string.stringNumber, 5)
    }

    func testCustomLowCAndQuietDecayRemainDetectable() async {
        for (midi, amplitude) in [(24, 0.2), (40, 0.008)] {
            let h = fixture()
            defer { h.model.stop(); h.audio.stop() }
            if midi == 24 {
                h.model.selectCustomTuning()
                h.model.changeCustomString(stringNumber: 6, semitones: -16)
                h.model.setLockedString(6)
            }
            h.model.start()
            let frequency = GuitarNote.frequency(forMIDI: midi)
            feed(h.capture, frequency: frequency, chunkSize: 128, amplitude: amplitude)
            await waitUntil { h.model.reading != nil }
            XCTAssertEqual(h.model.reading?.frequencyHz ?? 0, frequency, accuracy: 0.15)
        }
    }

    func testRouteRestartDoesNotReuseTheOldWindowOrMedian() async throws {
        let h = fixture()
        defer { h.model.stop(); h.audio.stop() }
        h.model.start()
        feed(h.capture, frequency: 110, chunkSize: 128)
        await waitUntil { h.model.reading != nil }
        h.audio.stop()
        h.audio.requestPermissionAndStart()
        feed(h.capture, frequency: 329.63, chunkSize: 128, count: 4_096)
        try await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertNil(h.model.reading, "Half of a new window cannot complete a previous route's window")
        feed(h.capture, frequency: 329.63, chunkSize: 128, startSeconds: 100 + 4_096.0 / 48_000)
        await waitUntil { h.model.reading != nil }
        XCTAssertEqual(h.model.reading?.frequencyHz ?? 0, 329.63, accuracy: 0.2)
    }

    func testMissingPCMExpiresTheNeedleAndLockedTargetRemainsVisible() async {
        let clock = TunerTestClock()
        let h = fixture(clock: clock)
        defer { h.model.stop(); h.audio.stop() }
        h.model.setLockedString(6)
        h.model.start()
        feed(h.capture, frequency: 82.4, chunkSize: 128)
        await waitUntil { h.model.reading != nil }
        clock.time += 1
        h.model.expireReading()
        XCTAssertNil(h.model.reading)
        XCTAssertNil(h.model.target)
        XCTAssertEqual(h.model.targetString?.stringNumber, 6)
        XCTAssertEqual(h.model.targetFrequencyHz ?? 0, GuitarNote.frequency(forMIDI: 40), accuracy: 0.001)
    }

    func testCalibrationAndSensitivityRejectInvalidSettings() {
        let h = fixture()
        h.model.a4Hz = .nan
        h.model.sensitivity = .infinity
        XCTAssertEqual(h.model.a4Hz, 440)
        XCTAssertEqual(h.model.sensitivity, 0.6)
        h.model.a4Hz = 999
        h.model.sensitivity = -1
        XCTAssertEqual(h.model.a4Hz, 480)
        XCTAssertEqual(h.model.sensitivity, 0)
    }

    // Synthetic PCM arrives in a burst, not in real time. Keep its clock controlled
    // so real YIN coverage does not become a CI CPU-throughput/freshness race.
    private func fixture(clock: any AudioHostClock = TunerTestClock()) -> TunerHarness {
        let capture = TunerTestCapture()
        let audio = AudioInputModel(catalog: TunerTestCatalog(), permission: TunerTestPermission(), captureFactory: { capture })
        let defaults = UserDefaults(suiteName: "TunerModelTests.\(UUID().uuidString)")!
        let preferences = AppPreferencesStore(defaults: defaults)
        return TunerHarness(audio: audio, capture: capture, preferences: preferences,
                            model: TunerModel(audio: audio, preferencesStore: preferences,
                                              analysisPipeline: TunerAnalysisPipeline(clock: clock), clock: clock))
    }

    private func feed(_ capture: TunerTestCapture, frequency: Double, chunkSize: Int, sampleRate: Double = 48_000, amplitude: Double = 0.2, count: Int = 24_576, startSeconds: Double = 100) {
        let phaseOffset = Int(((startSeconds - 100) * sampleRate).rounded())
        for start in stride(from: 0, to: count, by: chunkSize) {
            let end = min(start + chunkSize, count)
            let samples = (start..<end).map { Float(amplitude * sin(2 * .pi * frequency * Double($0 + phaseOffset) / sampleRate)) }
            capture.onFrame?(InputCaptureFrame(samples: samples, sampleRate: sampleRate, timestampSeconds: startSeconds + Double(start) / sampleRate, channelLevelsDBFS: [-20], selectedChannelPeak: Float(amplitude)))
        }
    }

    private func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<500 {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for synthetic tuner analysis")
    }
}

@MainActor
private struct TunerHarness {
    let audio: AudioInputModel
    let capture: TunerTestCapture
    let preferences: AppPreferencesStore
    let model: TunerModel
}

private final class TunerTestCatalog: AudioInputDeviceCatalogProviding {
    var onDevicesChanged: (() -> Void)?
    private let device = CoreAudioInputDevice(id: 901, uid: "synthetic-tuner", name: "Synthetic Tuner", channelCount: 1, sampleRate: 48_000, deviceLatencyFrames: 0, safetyOffsetFrames: 0, bufferFrameSize: 128)
    func inputDevices() throws -> [CoreAudioInputDevice] { [device] }
    func defaultInputDeviceID() throws -> AudioDeviceID? { device.id }
}

private struct TunerTestPermission: AudioInputPermissionProviding {
    var authorizationStatus: AVAuthorizationStatus { .authorized }
    func requestAccess(_ completion: @escaping (Bool) -> Void) { XCTFail("Synthetic authorized input must not request permission") }
}

private final class TunerTestClock: AudioHostClock, @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 100.0
    var time: Double {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }
    func nowSeconds() -> Double { time }
    func seconds(forHostTime hostTime: UInt64) -> Double { Double(hostTime) / 1_000_000 }
}

private final class TunerTestCapture: AudioInputCapturing {
    var onFrame: ((InputCaptureFrame) -> Void)?
    func start(device: CoreAudioInputDevice, channel: Int, clock: any AudioHostClock, onFrame: @escaping (InputCaptureFrame) -> Void, onError: @escaping (Error) -> Void, onConfigurationChanged: @escaping () -> Void) throws -> InputCaptureFormat {
        self.onFrame = onFrame
        return InputCaptureFormat(sampleRate: device.sampleRate, channelCount: device.channelCount)
    }
    func stop() { onFrame = nil }
}
