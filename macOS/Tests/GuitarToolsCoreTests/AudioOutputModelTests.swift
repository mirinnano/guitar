import AVFoundation
import CoreAudio
import XCTest
@testable import GuitarToolsMacApp

@MainActor
final class AudioOutputModelTests: XCTestCase {
    private let mac = CoreAudioOutputDevice(id: 10, uid: "mac", name: "Mac Speakers", channelCount: 2, sampleRate: 44_100)
    private let ur12 = CoreAudioOutputDevice(id: 20, uid: "ur12", name: "Steinberg UR12", channelCount: 2, sampleRate: 48_000)

    private var defaultsSuites: [String] = []

    override func tearDown() async throws {
        for name in defaultsSuites {
            UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
        }
        defaultsSuites.removeAll()
    }

    private func preferences() -> AppPreferencesStore {
        // Isolated test defaults: no standard defaults, permissions, or hardware I/O.
        let name = "AudioOutputTests.\(UUID().uuidString)"
        defaultsSuites.append(name)
        return AppPreferencesStore(defaults: UserDefaults(suiteName: name)!)
    }

    func testSelectionPersistsStableUIDAndSurvivesNewModel() {
        let store = preferences()
        let catalog = FakeOutputCatalog(devices: [mac, ur12], defaultID: mac.id)
        let model = AudioOutputModel(preferencesStore: store, catalog: catalog)
        model.selectOutputDevice(uid: ur12.uid)
        XCTAssertEqual(store.value.audio.outputDeviceUID, ur12.uid)
        XCTAssertEqual(model.selectedDevice, ur12)
        let restored = AudioOutputModel(preferencesStore: store, catalog: FakeOutputCatalog(devices: [mac, ur12], defaultID: mac.id))
        XCTAssertEqual(restored.selectedDeviceUID, ur12.uid)
        XCTAssertEqual(restored.selectedDevice, ur12)
        model.selectOutputDevice(uid: nil)
        XCTAssertNil(store.value.audio.outputDeviceUID)
        XCTAssertNil(model.selectedDevice)
    }

    func testPlayerIsLazyAndSelectionDoesNotStartInputOrPlayback() {
        let store = preferences()
        let catalog = FakeOutputCatalog(devices: [mac, ur12], defaultID: mac.id)
        let player = FakeReferencePlayer()
        var creations = 0
        let model = AudioOutputModel(preferencesStore: store, catalog: catalog, playerFactory: {
            creations += 1
            return player
        })
        model.selectOutputDevice(uid: ur12.uid)
        model.refreshOutputDevices()
        model.stopReference()
        XCTAssertEqual(creations, 0)
        XCTAssertTrue(player.calls.isEmpty)
        XCTAssertEqual(catalog.defaultReads, 0)
        model.playReference(frequency: 440)
        XCTAssertEqual(creations, 1)
        XCTAssertEqual(player.calls.map(\.id), [ur12.id])
        XCTAssertEqual(player.calls.first?.frequency, 440)
        XCTAssertTrue(model.isPlaying)
        // There is no input catalog/player/permission API in this model or its dependencies.
    }

    func testChangingSelectionStopsAndOnlyRebindsOnNextPlay() {
        let catalog = FakeOutputCatalog(devices: [mac, ur12], defaultID: mac.id)
        let player = FakeReferencePlayer()
        let model = AudioOutputModel(preferencesStore: preferences(), catalog: catalog, playerFactory: { player })
        model.playReference(frequency: 440)
        let stops = player.stops
        model.selectOutputDevice(uid: ur12.uid)
        XCTAssertGreaterThan(player.stops, stops)
        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(player.calls.map(\.id), [mac.id])
        model.playReference(frequency: 220)
        XCTAssertEqual(player.calls.map(\.id), [mac.id, ur12.id])
    }

    func testSavedMissingDeviceNeverFallsBackAndReconnectUsesNewNumericID() {
        let store = preferences()
        store.update { $0.audio.outputDeviceUID = ur12.uid }
        let catalog = FakeOutputCatalog(devices: [mac], defaultID: mac.id)
        let player = FakeReferencePlayer()
        let model = AudioOutputModel(preferencesStore: store, catalog: catalog, playerFactory: { player })
        XCTAssertTrue(model.selectedDeviceUnavailable)
        XCTAssertNotNil(model.errorMessage)
        model.playReference(frequency: 440)
        XCTAssertTrue(player.calls.isEmpty)
        XCTAssertEqual(catalog.defaultReads, 0)
        XCTAssertEqual(model.selectedDeviceUID, ur12.uid)
        XCTAssertEqual(store.value.audio.outputDeviceUID, ur12.uid)
        let reconnected = CoreAudioOutputDevice(id: 99, uid: ur12.uid, name: ur12.name, channelCount: 2, sampleRate: 44_100)
        catalog.devices.append(reconnected)
        model.refreshOutputDevices()
        XCTAssertFalse(model.selectedDeviceUnavailable)
        XCTAssertNil(model.errorMessage)
        model.playReference(frequency: 440)
        XCTAssertEqual(player.calls.map(\.id), [reconnected.id])
    }

    func testDisconnectStopsPlayingAndRetainsSelection() {
        let catalog = FakeOutputCatalog(devices: [mac, ur12], defaultID: mac.id)
        let player = FakeReferencePlayer()
        let model = AudioOutputModel(preferencesStore: preferences(), catalog: catalog, playerFactory: { player })
        model.selectOutputDevice(uid: ur12.uid)
        model.playReference(frequency: 440)
        catalog.devices = [mac]
        let stops = player.stops
        model.refreshOutputDevices()
        XCTAssertGreaterThan(player.stops, stops)
        XCTAssertFalse(model.isPlaying)
        XCTAssertTrue(model.selectedDeviceUnavailable)
        XCTAssertEqual(model.selectedDeviceUID, ur12.uid)
        XCTAssertTrue(model.errorMessage?.contains("別の出力には切り替えません") == true)
        model.playReference(frequency: 440)
        XCTAssertEqual(player.calls.map(\.id), [ur12.id])
        XCTAssertEqual(catalog.defaultReads, 0)
    }

    func testDefaultChangeStopsAndIsResolvedAgainAtPlay() {
        let catalog = FakeOutputCatalog(devices: [mac, ur12], defaultID: mac.id)
        let player = FakeReferencePlayer()
        let model = AudioOutputModel(preferencesStore: preferences(), catalog: catalog, playerFactory: { player })
        model.playReference(frequency: 440)
        catalog.defaultID = ur12.id
        model.refreshOutputDevices()
        XCTAssertFalse(model.isPlaying)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(player.calls.map(\.id), [mac.id])
        model.playReference(frequency: 440)
        XCTAssertEqual(player.calls.map(\.id), [mac.id, ur12.id])
        XCTAssertNil(model.selectedDeviceUID)
    }

    func testDefaultChangeDoesNotAffectExplicitOutput() {
        let catalog = FakeOutputCatalog(devices: [mac, ur12], defaultID: mac.id)
        let player = FakeReferencePlayer()
        let model = AudioOutputModel(preferencesStore: preferences(), catalog: catalog, playerFactory: { player })
        model.selectOutputDevice(uid: ur12.uid)
        model.playReference(frequency: 440)
        catalog.defaultID = nil
        model.refreshOutputDevices()
        XCTAssertTrue(model.isPlaying)
        XCTAssertEqual(catalog.defaultReads, 0)
        XCTAssertNil(model.errorMessage)
    }

    func testSampleRateChangeStopsUntilNextPlay() {
        let catalog = FakeOutputCatalog(devices: [ur12], defaultID: ur12.id)
        let player = FakeReferencePlayer()
        let model = AudioOutputModel(preferencesStore: preferences(), catalog: catalog, playerFactory: { player })
        model.playReference(frequency: 440)
        catalog.devices = [CoreAudioOutputDevice(id: ur12.id, uid: ur12.uid, name: ur12.name, channelCount: 2, sampleRate: 44_100)]
        model.refreshOutputDevices()
        XCTAssertFalse(model.isPlaying)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(player.calls.count, 1)
    }

    func testMissingDefaultOutputDoesNotUseFirstAvailableDevice() {
        let catalog = FakeOutputCatalog(devices: [mac, ur12], defaultID: nil)
        let player = FakeReferencePlayer()
        let model = AudioOutputModel(preferencesStore: preferences(), catalog: catalog, playerFactory: { player })
        model.playReference(frequency: 440)
        XCTAssertTrue(player.calls.isEmpty)
        XCTAssertFalse(model.isPlaying)
        XCTAssertTrue(model.errorMessage?.contains("見つかりません") == true)
        catalog.defaultID = 1234
        model.playReference(frequency: 440)
        XCTAssertTrue(player.calls.isEmpty)
    }

    func testBindingErrorIsVisibleWithoutFallback() {
        let catalog = FakeOutputCatalog(devices: [mac, ur12], defaultID: mac.id)
        let player = FakeReferencePlayer()
        player.error = FakeOutputError.failed
        let model = AudioOutputModel(preferencesStore: preferences(), catalog: catalog, playerFactory: { player })
        model.selectOutputDevice(uid: ur12.uid)
        model.playReference(frequency: 440)
        XCTAssertEqual(player.calls.map(\.id), [ur12.id])
        XCTAssertFalse(model.isPlaying)
        XCTAssertTrue(model.errorMessage?.contains("テスト用エラー") == true)
        XCTAssertEqual(catalog.defaultReads, 0)
    }

    func testCoreAudioDiagnosticIsLocalizedWithoutChangingStatus() {
        let catalog = FakeOutputCatalog(devices: [mac], defaultID: mac.id)
        catalog.error = CoreAudioCatalogError.operationFailed(operation: "Read output device list", status: -50)
        let model = AudioOutputModel(preferencesStore: preferences(), catalog: catalog)
        XCTAssertTrue(model.errorMessage?.contains("音声出力を更新できません") == true)
        XCTAssertTrue(model.errorMessage?.contains("CoreAudioエラー（OSStatus -50）") == true)
        XCTAssertFalse(model.errorMessage?.contains("Read output device list") == true)
    }

    func testEnumerationErrorStopsAndNeverUsesStaleDeviceList() {
        let catalog = FakeOutputCatalog(devices: [mac], defaultID: mac.id)
        let player = FakeReferencePlayer()
        let model = AudioOutputModel(preferencesStore: preferences(), catalog: catalog, playerFactory: { player })
        model.playReference(frequency: 440)
        catalog.error = FakeOutputError.failed
        model.refreshOutputDevices()
        XCTAssertFalse(model.isPlaying)
        XCTAssertTrue(model.devices.isEmpty)
        XCTAssertNotNil(model.errorMessage)
        model.playReference(frequency: 440)
        XCTAssertEqual(player.calls.count, 1)
    }

    func testInvalidFrequenciesAreRejectedHonestlyAndStopExistingTone() {
        let player = FakeReferencePlayer()
        let model = AudioOutputModel(preferencesStore: preferences(), catalog: FakeOutputCatalog(devices: [mac], defaultID: mac.id), playerFactory: { player })
        model.playReference(frequency: 440)
        for frequency in [Double.nan, .infinity, -.infinity, -1, 0, 19.9, 4_000.1] {
            model.playReference(frequency: frequency)
            XCTAssertFalse(model.isPlaying)
            XCTAssertTrue(model.errorMessage?.contains("周波数") == true)
        }
        XCTAssertEqual(player.calls.count, 1)
    }

    func testStaleCompletionCannotStopNewToneOrOverwriteError() {
        let player = FakeReferencePlayer()
        let model = AudioOutputModel(preferencesStore: preferences(), catalog: FakeOutputCatalog(devices: [mac], defaultID: mac.id), playerFactory: { player })
        model.playReference(frequency: 440)
        let stale = player.onPlaybackEnded
        model.playReference(frequency: 220)
        stale?("old failure")
        XCTAssertTrue(model.isPlaying)
        XCTAssertNil(model.errorMessage)
        player.onPlaybackEnded?("current output lost")
        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(model.errorMessage, "current output lost")
        model.playReference(frequency: 440)
        player.onPlaybackEnded?(nil)
        XCTAssertFalse(model.isPlaying)
        XCTAssertNil(model.errorMessage)
    }

    func testSynchronousPlaybackFailureAndRepeatedCompletionStayHonest() {
        let player = FakeReferencePlayer()
        player.completeDuringPlay = true
        player.completionMessage = "output lost"
        let model = AudioOutputModel(preferencesStore: preferences(), catalog: FakeOutputCatalog(devices: [mac], defaultID: mac.id), playerFactory: { player })
        model.playReference(frequency: 440)
        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(model.errorMessage, "output lost")
        player.onPlaybackEnded?("stale repeated completion")
        XCTAssertEqual(model.errorMessage, "output lost")
    }

    func testRealPlayerRejectsInvalidArgumentsBeforeCreatingEngine() {
        let player = ReferenceTonePlayer()
        XCTAssertThrowsError(try player.play(frequency: .nan, outputDeviceID: 777)) { error in
            XCTAssertTrue(error.localizedDescription.contains("周波数"))
        }
        XCTAssertThrowsError(try player.play(frequency: 440, outputDeviceID: kAudioObjectUnknown)) { error in
            XCTAssertTrue(error.localizedDescription.contains("音声出力"))
        }
        player.stop()
    }

    func testCatalogListenerRefreshesAndDoesNotRetainModel() async {
        let catalog = FakeOutputCatalog(devices: [mac, ur12], defaultID: mac.id)
        let player = FakeReferencePlayer()
        var model: AudioOutputModel? = AudioOutputModel(preferencesStore: preferences(), catalog: catalog, playerFactory: { player })
        model?.selectOutputDevice(uid: ur12.uid)
        model?.playReference(frequency: 440)
        catalog.devices = [mac]
        catalog.onDevicesChanged?()
        for _ in 0..<5 { await Task.yield() }
        XCTAssertFalse(model?.isPlaying ?? true)
        XCTAssertTrue(model?.selectedDeviceUnavailable ?? false)
        weak var weakModel = model
        model = nil
        XCTAssertNil(weakModel)
        catalog.onDevicesChanged?()
        await Task.yield()
    }

    func testOldJSONWithoutOutputUIDPreservesEveryExistingPreference() throws {
        let oldJSON = """
        {"schemaVersion":1,"audio":{"inputDeviceUID":"existing-input","selectedChannel":1,"inputLatencyCompensationMs":12.5},"tuner":{"a4Hz":442,"tuningID":"custom","sensitivity":0.7,"customStringMIDI":{"1":65}},"metronome":{"bpm":93,"beatsPerBar":3,"beatUnit":8,"subdivisionRawValue":2,"accentRawValues":[0,1,1],"clickSoundRawValue":"digital","countInBars":2,"speedTrainerEnabled":true,"speedStartBPM":65,"speedEndBPM":140,"speedStepBPM":3,"speedBarsPerStep":8},"practice":{"onTimeToleranceMs":75,"autoScroll":false}}
        """
        let data = Data(oldJSON.utf8)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        XCTAssertNil(decoded.audio.outputDeviceUID)
        XCTAssertEqual(decoded.audio.inputDeviceUID, "existing-input")
        XCTAssertEqual(decoded.audio.selectedChannel, 1)
        XCTAssertEqual(decoded.tuner.a4Hz, 442)
        XCTAssertEqual(decoded.metronome.bpm, 93)
        XCTAssertFalse(decoded.practice.autoScroll)
        let name = "AudioOutputMigration.\(UUID().uuidString)"
        defaultsSuites.append(name)
        let defaults = UserDefaults(suiteName: name)!
        defaults.set(data, forKey: AppPreferencesStore.storageKey)
        let store = AppPreferencesStore(defaults: defaults)
        XCTAssertEqual(store.value, decoded)
        store.update { $0.audio.outputDeviceUID = "ur12" }
        let relaunched = AppPreferencesStore(defaults: defaults)
        var expected = decoded
        expected.audio.outputDeviceUID = "ur12"
        XCTAssertEqual(relaunched.value, expected)
        defaults.removeObject(forKey: AppPreferencesStore.storageKey)
    }

    func testA440BufferUsesActualRateAndSafeAmplitude() throws {
        for rate in [44_100.0, 48_000.0] {
            let buffer = try ReferenceTonePlayer.makeBuffer(frequency: 440, sampleRate: rate)
            XCTAssertEqual(buffer.format.sampleRate, rate)
            let samples = buffer.floatChannelData![0]
            let start = Int(rate * 0.1)
            let end = Int(rate * 1.0)
            var crossings: [Double] = []
            for index in start..<end {
                XCTAssertTrue(samples[index].isFinite)
                XCTAssertLessThanOrEqual(abs(samples[index]), 0.120001)
                if samples[index] <= 0, samples[index + 1] > 0 {
                    let fraction = Double(-samples[index]) / Double(samples[index + 1] - samples[index])
                    crossings.append(Double(index) + fraction)
                }
            }
            XCTAssertGreaterThan(crossings.count, 300)
            let estimated = Double(crossings.count - 1) * rate / (crossings.last! - crossings.first!)
            XCTAssertEqual(estimated, 440, accuracy: 0.01)
            XCTAssertEqual(samples[0], 0)
            XCTAssertLessThan(abs(samples[Int(buffer.frameLength) - 1]), 0.001)
        }
        for invalid in [Double.nan, .infinity, -440, 0, 10_000] {
            XCTAssertThrowsError(try ReferenceTonePlayer.makeBuffer(frequency: invalid, sampleRate: 48_000))
        }
        for invalid in [Double.nan, .infinity, 0, 1, 1_000_000] {
            XCTAssertThrowsError(try ReferenceTonePlayer.makeBuffer(frequency: 440, sampleRate: invalid))
        }
    }
}

private final class FakeOutputCatalog: AudioOutputDeviceCatalog {
    var onDevicesChanged: (() -> Void)?
    var devices: [CoreAudioOutputDevice]
    var defaultID: AudioDeviceID?
    var error: Error?
    var defaultReads = 0

    init(devices: [CoreAudioOutputDevice], defaultID: AudioDeviceID?) {
        self.devices = devices
        self.defaultID = defaultID
    }
    func outputDevices() throws -> [CoreAudioOutputDevice] {
        if let error { throw error }
        return devices
    }
    func defaultOutputDeviceID() throws -> AudioDeviceID? {
        defaultReads += 1
        if let error { throw error }
        return defaultID
    }
}

@MainActor
private final class FakeReferencePlayer: ReferenceTonePlaying {
    var onPlaybackEnded: ((String?) -> Void)?
    var calls: [(frequency: Double, id: AudioDeviceID)] = []
    var stops = 0
    var error: Error?
    var completeDuringPlay = false
    var completionMessage: String?

    func play(frequency: Double, outputDeviceID: AudioDeviceID) throws {
        calls.append((frequency, outputDeviceID))
        if let error { throw error }
        if completeDuringPlay { onPlaybackEnded?(completionMessage) }
    }
    func stop() { stops += 1 }
}

private enum FakeOutputError: LocalizedError {
    case failed
    var errorDescription: String? { "テスト用エラー" }
}
