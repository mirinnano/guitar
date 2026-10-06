import AVFoundation
import Combine
import CoreAudio
import Foundation
import XCTest
@testable import GuitarToolsMacApp

/// All catalogs, capture adapters, clocks and permissions in these tests are
/// fakes. No test instantiates the real capture adapter or asks mic permission.
@MainActor
final class AudioInputModelRegressionTests: XCTestCase {
    private let mac = CoreAudioInputDevice(id: 10, uid: "mac-mono", name: "Mac Microphone", channelCount: 1, sampleRate: 44_100, deviceLatencyFrames: 0, safetyOffsetFrames: 0, bufferFrameSize: 128)
    private let ur12 = CoreAudioInputDevice(id: 51, uid: "YamahaUSBAudioEngine2-ur12", name: "Steinberg UR12", channelCount: 2, sampleRate: 48_000, deviceLatencyFrames: 16, safetyOffsetFrames: 16, bufferFrameSize: 128)

    func testIdleUR12ConfigurationIsAtomicAndNeverStartsCaptureOrRequestsPermission() {
        let catalog = InputRegressionCatalog(devices: [mac, ur12], defaultID: mac.id)
        let permission = InputRegressionPermission(status: .notDetermined)
        let capture = InputRegressionCapture()
        var creations = 0
        let model = AudioInputModel(catalog: catalog, permission: permission, captureFactory: { creations += 1; return capture })
        let defaultReads = catalog.defaultReads
        model.configureInput(uid: ur12.uid, channel: 1)
        model.refreshInputDevices()
        XCTAssertEqual(model.selectedDeviceUID, ur12.uid)
        XCTAssertEqual(model.selectedChannel, 1)
        XCTAssertEqual(model.availableChannels, 2)
        XCTAssertEqual(model.sampleRate, 48_000)
        XCTAssertTrue(model.inputLabel.contains("UR12 · Ch 2"))
        XCTAssertEqual(model.channelLevelsDBFS, [-120, -120])
        XCTAssertEqual(model.receivedFrameCount, 0)
        XCTAssertFalse(model.isRunning)
        XCTAssertEqual(creations, 0)
        XCTAssertEqual(permission.requests, 0)
        XCTAssertTrue(capture.calls.isEmpty)
        XCTAssertEqual(catalog.defaultReads, defaultReads)
        XCTAssertEqual(catalog.defaultID, mac.id, "Selection must not change system defaults")
    }

    func testAuthorizedStartCapturesBothUR12ChannelsAtNative48kAndSelectsCh2() {
        let (model, catalog, capture, _) = fixture()
        model.configureInput(uid: ur12.uid, channel: 1)
        let defaultReads = catalog.defaultReads
        model.requestPermissionAndStart()
        XCTAssertTrue(model.isRunning)
        XCTAssertEqual(capture.calls.map(\.id), [51])
        XCTAssertEqual(capture.calls.map(\.channel), [1])
        XCTAssertEqual(model.availableChannels, 2)
        XCTAssertEqual(model.sampleRate, 48_000)
        XCTAssertEqual(model.selectedChannel, 1)
        XCTAssertEqual(model.hardwareInputLatencyMs, 160.0 / 48_000 * 1_000, accuracy: 0.00001)
        XCTAssertEqual(catalog.defaultReads, defaultReads)
        XCTAssertNil(model.errorMessage)
        model.stop()
    }

    func testAtomicConfigureWhileRunningDoesNotRestartUR12OnCh1ThenCh2() {
        let (model, _, capture, _) = fixture()
        model.requestPermissionAndStart() // Mac mono, Ch 1.
        let stops = capture.stops
        model.configureInput(uid: ur12.uid, channel: 1)
        XCTAssertTrue(model.isRunning)
        XCTAssertEqual(capture.calls.map(\.id), [10, 51])
        XCTAssertEqual(capture.calls.map(\.channel), [0, 1])
        XCTAssertEqual(capture.stops, stops + 1)
        model.configureInput(uid: ur12.uid, channel: 1)
        XCTAssertEqual(capture.calls.count, 2, "No-op configuration must not restart")
        model.stop()
    }

    func testSavedMissingUIDKeepsCh2AndCannotSubstituteMacMonoMetadata() {
        let catalog = InputRegressionCatalog(devices: [mac], defaultID: mac.id)
        let permission = InputRegressionPermission(status: .authorized)
        let capture = InputRegressionCapture()
        let model = AudioInputModel(catalog: catalog, permission: permission, captureFactory: { capture })
        let defaultReads = catalog.defaultReads
        model.selectInputDevice(uid: ur12.uid)
        model.selectInputChannel(1) // Existing two-call restoration must also work while idle.
        model.refreshInputDevices()
        XCTAssertEqual(model.selectedChannel, 1)
        XCTAssertEqual(model.selectedDeviceUID, ur12.uid)
        XCTAssertTrue(model.selectedDeviceUnavailable)
        XCTAssertEqual(model.availableChannels, 0)
        XCTAssertEqual(model.sampleRate, 0)
        XCTAssertEqual(model.hardwareInputLatencyMs, 0)
        XCTAssertFalse(model.inputLabel.contains("Mac"))
        XCTAssertTrue(model.channelLevelsDBFS.isEmpty)
        XCTAssertTrue(model.inputHealthMessage?.contains("別の入力には切り替え") == true)
        XCTAssertEqual(catalog.defaultReads, defaultReads)
        XCTAssertTrue(capture.calls.isEmpty)
    }

    func testSavedChannelsAreBoundedOnlyByStorageRangeNotConnectedDevice() {
        let (model, _, capture, _) = fixture(devices: [mac])
        model.configureInput(uid: ur12.uid, channel: 63)
        XCTAssertEqual(model.selectedChannel, 63)
        model.selectInputChannel(64)
        XCTAssertEqual(model.selectedChannel, 63)
        XCTAssertTrue(model.errorMessage?.contains("Ch 1〜Ch 64") == true)
        model.selectedChannel = -1
        XCTAssertEqual(model.selectedChannel, 63)
        XCTAssertTrue(capture.calls.isEmpty)
    }

    func testMissingSelectedDeviceRearmsOnReconnectWithNewIDWithoutDefaultFallback() {
        let (model, catalog, capture, _) = fixture(devices: [mac])
        model.configureInput(uid: ur12.uid, channel: 1)
        let defaultReads = catalog.defaultReads
        model.requestPermissionAndStart()
        XCTAssertFalse(model.isRunning)
        XCTAssertTrue(capture.calls.isEmpty)
        XCTAssertTrue(model.errorMessage?.contains("再接続を待ちます") == true)
        catalog.devices.append(reconnectedUR12())
        catalog.onDevicesChanged?()
        XCTAssertTrue(model.isRunning)
        XCTAssertEqual(capture.calls.map(\.id), [99])
        XCTAssertEqual(capture.calls.map(\.channel), [1])
        XCTAssertEqual(model.selectedDeviceUID, ur12.uid)
        XCTAssertEqual(model.selectedChannel, 1)
        XCTAssertEqual(catalog.defaultReads, defaultReads)
        XCTAssertNil(model.errorMessage)
        model.stop()
    }

    func testToggleCancelsMissingSelectedDeviceWaitAndReconnectDoesNotStartCapture() {
        let catalog = InputRegressionCatalog(devices: [mac], defaultID: mac.id)
        let permission = InputRegressionPermission(status: .authorized)
        let capture = InputRegressionCapture()
        var creations = 0
        let model = AudioInputModel(catalog: catalog, permission: permission, captureFactory: { creations += 1; return capture })
        model.configureInput(uid: ur12.uid, channel: 1)
        let defaultReads = catalog.defaultReads
        XCTAssertFalse(model.isStartRequested)

        model.toggle()
        XCTAssertTrue(model.isStartRequested)
        XCTAssertFalse(model.isRunning)
        XCTAssertTrue(model.selectedDeviceUnavailable)
        XCTAssertEqual(creations, 0)

        model.toggle()
        XCTAssertFalse(model.isStartRequested)
        XCTAssertFalse(model.isRunning)
        XCTAssertFalse(model.inputHealthMessage?.contains("再接続を待ち") == true)
        catalog.onDevicesChanged?() // Still missing: refreshing must not rearm or claim to wait.
        XCTAssertFalse(model.isStartRequested)
        XCTAssertFalse(model.inputHealthMessage?.contains("再接続を待ち") == true)
        catalog.devices.append(reconnectedUR12())
        catalog.onDevicesChanged?()
        model.refreshInputDevices()
        model.selectInputChannel(0)
        model.selectInputChannel(1)
        XCTAssertFalse(model.isStartRequested)
        XCTAssertFalse(model.isRunning)
        XCTAssertTrue(capture.calls.isEmpty)
        XCTAssertEqual(creations, 0)
        XCTAssertEqual(permission.requests, 0)
        XCTAssertEqual(model.selectedDeviceUID, ur12.uid)
        XCTAssertEqual(model.selectedChannel, 1)
        XCTAssertEqual(catalog.defaultReads, defaultReads)

        model.toggle() // Only a fresh user request may start the reconnected route.
        XCTAssertTrue(model.isStartRequested)
        XCTAssertTrue(model.isRunning)
        XCTAssertEqual(capture.calls.map(\.id), [99])
        XCTAssertEqual(capture.calls.map(\.channel), [1])
        XCTAssertEqual(creations, 1)
        model.toggle()
        XCTAssertFalse(model.isStartRequested)
        XCTAssertFalse(model.isRunning)
    }

    func testDisconnectStopsRetainsCh2AndReconnectRearmsOnlyUntilUserStops() {
        let (model, catalog, capture, _) = fixture()
        model.configureInput(uid: ur12.uid, channel: 1)
        model.requestPermissionAndStart()
        let defaultReads = catalog.defaultReads
        catalog.devices = [mac]
        catalog.onDevicesChanged?()
        XCTAssertFalse(model.isRunning)
        XCTAssertEqual(model.selectedChannel, 1)
        XCTAssertEqual(model.availableChannels, 0)
        XCTAssertEqual(model.sampleRate, 0)
        XCTAssertEqual(model.receivedFrameCount, 0)
        XCTAssertFalse(model.inputLabel.contains("Mac"))
        XCTAssertEqual(capture.calls.map(\.id), [51])
        catalog.devices.append(reconnectedUR12())
        catalog.onDevicesChanged?()
        XCTAssertTrue(model.isRunning)
        XCTAssertEqual(capture.calls.map(\.id), [51, 99])
        XCTAssertEqual(capture.calls.map(\.channel), [1, 1])
        XCTAssertTrue(model.isStartRequested)
        catalog.devices = [mac]
        catalog.onDevicesChanged?()
        XCTAssertTrue(model.isStartRequested)
        XCTAssertFalse(model.isRunning)
        model.toggle()
        XCTAssertFalse(model.isStartRequested)
        catalog.devices.append(ur12)
        catalog.onDevicesChanged?()
        XCTAssertFalse(model.isStartRequested)
        XCTAssertFalse(model.isRunning)
        XCTAssertEqual(capture.calls.count, 2)
        XCTAssertEqual(model.selectedChannel, 1)
        XCTAssertEqual(catalog.defaultReads, defaultReads)
    }

    func testChangingSystemDefaultDoesNotRerouteExplicitUR12() {
        let (model, catalog, capture, _) = fixture()
        model.configureInput(uid: ur12.uid, channel: 1)
        model.requestPermissionAndStart()
        let defaultReads = catalog.defaultReads
        catalog.defaultID = nil
        catalog.onDevicesChanged?()
        XCTAssertTrue(model.isRunning)
        XCTAssertEqual(capture.calls.map(\.id), [51])
        XCTAssertEqual(catalog.defaultReads, defaultReads)
        model.stop()
    }

    func testNilUIDFollowsOnlyTheDefaultAndRejectsUnavailableChannelRatherThanClamping() {
        let (model, catalog, capture, _) = fixture()
        model.requestPermissionAndStart()
        catalog.defaultID = ur12.id
        catalog.onDevicesChanged?()
        XCTAssertEqual(capture.calls.map(\.id), [10, 51])
        model.selectInputChannel(1)
        XCTAssertEqual(capture.calls.map(\.channel), [0, 0, 1])
        catalog.defaultID = mac.id
        catalog.onDevicesChanged?()
        XCTAssertFalse(model.isRunning)
        XCTAssertEqual(model.selectedChannel, 1)
        XCTAssertTrue(model.errorMessage?.contains("Ch 1 には切り替えません") == true)
        XCTAssertEqual(capture.calls.map(\.id), [10, 51, 51, 10])
        model.stop()
    }

    func testAClaimedMonoCaptureForStereoDeviceThrowsAndPreservesCh2() {
        let (model, catalog, capture, _) = fixture()
        model.configureInput(uid: ur12.uid, channel: 1)
        let defaultReads = catalog.defaultReads
        capture.returnedFormat = InputCaptureFormat(sampleRate: 48_000, channelCount: 1)
        model.requestPermissionAndStart()
        XCTAssertFalse(model.isRunning)
        XCTAssertEqual(model.selectedChannel, 1)
        XCTAssertEqual(model.availableChannels, 2, "Idle catalog metadata remains hardware stereo")
        XCTAssertTrue(model.errorMessage?.contains("必要: 2 チャンネル、取得: 1 チャンネル") == true)
        XCTAssertEqual(capture.calls.map(\.channel), [1])
        XCTAssertGreaterThan(capture.stops, 0)
        XCTAssertEqual(catalog.defaultReads, defaultReads)
        model.stop()
    }

    func testActualMonoCh2AndDriverFailuresAreExplicitAndNeverRetryAnotherInput() {
        let (model, catalog, capture, _) = fixture()
        model.configureInput(uid: mac.uid, channel: 1)
        let defaultReads = catalog.defaultReads
        model.requestPermissionAndStart()
        XCTAssertFalse(model.isRunning)
        XCTAssertEqual(model.selectedChannel, 1)
        XCTAssertTrue(model.errorMessage?.contains("Ch 1 には切り替えません") == true)
        XCTAssertEqual(capture.calls.map(\.id), [10])
        model.configureInput(uid: ur12.uid, channel: 1) // Still armed from user start.
        XCTAssertTrue(model.isRunning)
        capture.error = InputCaptureError.operationFailed(operation: "入力デバイスの指定", status: -50)
        model.selectInputChannel(0)
        XCTAssertFalse(model.isRunning)
        XCTAssertTrue(model.errorMessage?.contains("入力デバイスの指定") == true)
        XCTAssertTrue(model.errorMessage?.contains("OSStatus -50") == true)
        XCTAssertEqual(capture.calls.map(\.id), [10, 51, 51])
        XCTAssertEqual(catalog.defaultReads, defaultReads)
        model.stop()
    }

    func testEnumerationFailureStopsAndCannotUseStaleCatalogOrDefaultMetadata() {
        let (model, catalog, capture, _) = fixture()
        model.configureInput(uid: ur12.uid, channel: 1)
        model.requestPermissionAndStart()
        let defaultReads = catalog.defaultReads
        catalog.error = CoreAudioCatalogError.operationFailed(operation: "Read input device list", status: -50)
        model.refreshInputDevices()
        XCTAssertFalse(model.isRunning)
        XCTAssertTrue(model.inputDevices.isEmpty)
        XCTAssertEqual(model.selectedChannel, 1)
        XCTAssertEqual(model.sampleRate, 0)
        XCTAssertEqual(model.availableChannels, 0)
        XCTAssertTrue(model.errorMessage?.contains("CoreAudioエラー（OSStatus -50）") == true)
        XCTAssertFalse(model.errorMessage?.contains("Read input device list") == true)
        XCTAssertEqual(capture.calls.map(\.id), [51])
        XCTAssertEqual(catalog.defaultReads, defaultReads)
        catalog.error = nil
        model.refreshInputDevices()
        XCTAssertTrue(model.isRunning)
        XCTAssertEqual(capture.calls.map(\.id), [51, 51])
        model.stop()
    }

    func testPermissionDeniedNeverCreatesAdapterOrStartsCapture() {
        let catalog = InputRegressionCatalog(devices: [mac, ur12], defaultID: mac.id)
        let permission = InputRegressionPermission(status: .denied)
        var creations = 0
        let model = AudioInputModel(catalog: catalog, permission: permission, captureFactory: { creations += 1; return InputRegressionCapture() })
        model.configureInput(uid: ur12.uid, channel: 1)
        model.requestPermissionAndStart()
        catalog.onDevicesChanged?()
        XCTAssertEqual(creations, 0)
        XCTAssertEqual(permission.requests, 0)
        XCTAssertFalse(model.isRunning)
        XCTAssertTrue(model.permissionDenied)
        XCTAssertFalse(model.isStartRequested)
        XCTAssertTrue(model.errorMessage?.contains("許可されていません") == true)
    }

    func testToggleCancelsPendingPermissionAndLateGrantCannotStartCapture() async {
        let catalog = InputRegressionCatalog(devices: [mac, ur12], defaultID: mac.id)
        let permission = InputRegressionPermission(status: .notDetermined)
        let capture = InputRegressionCapture()
        var creations = 0
        let model = AudioInputModel(catalog: catalog, permission: permission, captureFactory: { creations += 1; return capture })
        model.configureInput(uid: ur12.uid, channel: 1)
        var requests: [Bool] = []
        let subscription = model.$isStartRequested.sink { requests.append($0) }

        model.toggle()
        XCTAssertTrue(model.isStartRequested)
        XCTAssertFalse(model.isRunning)
        XCTAssertEqual(permission.requests, 1)
        let lateGrant = permission.completion
        model.toggle()
        XCTAssertFalse(model.isStartRequested)
        XCTAssertFalse(model.isRunning)
        permission.authorizationStatus = .authorized
        lateGrant?(true)
        catalog.onDevicesChanged?()
        model.selectInputChannel(0)
        model.selectInputChannel(1)
        await drainCallbacks()
        XCTAssertFalse(model.isStartRequested)
        XCTAssertFalse(model.isRunning)
        XCTAssertTrue(capture.calls.isEmpty)
        XCTAssertEqual(creations, 0)
        XCTAssertEqual(permission.requests, 1)

        model.toggle() // Permission is now granted, but still needs a fresh user start.
        XCTAssertTrue(model.isStartRequested)
        XCTAssertTrue(model.isRunning)
        XCTAssertEqual(capture.calls.map(\.id), [51])
        XCTAssertEqual(capture.calls.map(\.channel), [1])
        XCTAssertEqual(creations, 1)
        model.toggle()
        XCTAssertFalse(model.isStartRequested)
        XCTAssertFalse(model.isRunning)
        XCTAssertEqual(requests, [false, true, false, true, false])
        subscription.cancel()
    }

    func testLatePermissionGrantAfterStopCannotStartCapture() async {
        let catalog = InputRegressionCatalog(devices: [mac, ur12], defaultID: mac.id)
        let permission = InputRegressionPermission(status: .notDetermined)
        let capture = InputRegressionCapture()
        let model = AudioInputModel(catalog: catalog, permission: permission, captureFactory: { capture })
        model.configureInput(uid: ur12.uid, channel: 1)
        model.requestPermissionAndStart()
        XCTAssertEqual(permission.requests, 1)
        model.stop()
        permission.authorizationStatus = .authorized
        permission.completion?(true)
        await drainCallbacks()
        XCTAssertFalse(model.isRunning)
        XCTAssertTrue(capture.calls.isEmpty)
    }

    func testPendingPermissionUsesLatestAtomicRouteOnce() async {
        let catalog = InputRegressionCatalog(devices: [mac, ur12], defaultID: mac.id)
        let permission = InputRegressionPermission(status: .notDetermined)
        let capture = InputRegressionCapture()
        let model = AudioInputModel(catalog: catalog, permission: permission, captureFactory: { capture })
        model.requestPermissionAndStart()
        model.configureInput(uid: ur12.uid, channel: 1)
        model.requestPermissionAndStart()
        XCTAssertEqual(permission.requests, 1)
        XCTAssertTrue(capture.calls.isEmpty)
        permission.authorizationStatus = .authorized
        permission.completion?(true)
        await waitUntil { model.isRunning }
        XCTAssertEqual(capture.calls.map(\.id), [51])
        XCTAssertEqual(capture.calls.map(\.channel), [1])
        model.stop()
    }

    func testPCMHandlersReceiveChosenSamplesNativeRateAndTimestampAndMetersPublishOnMain() async {
        let (model, _, capture, clock) = fixture()
        model.configureInput(uid: ur12.uid, channel: 1)
        let recorder = InputRegressionPCMRecorder()
        let id = model.addPCMFrameHandler { recorder.record(samples: $0, rate: $1, time: $2) }
        var publications = 0
        let subscription = model.$channelLevelsDBFS.dropFirst().sink { _ in
            XCTAssertTrue(Thread.isMainThread)
            publications += 1
        }
        model.requestPermissionAndStart()
        capture.onFrame?(frame(count: 128, value: 0.5, timestamp: 12.345))
        await waitUntil { model.receivedFrameCount == 128 }
        XCTAssertEqual(model.channelLevelsDBFS, [-120, -6])
        XCTAssertEqual(model.levelDBFS, -6)
        XCTAssertNil(model.inputHealthMessage)
        XCTAssertEqual(recorder.records.first?.samples, Array(repeating: Float(0.5), count: 128))
        XCTAssertEqual(recorder.records.first?.rate, 48_000)
        XCTAssertEqual(recorder.records.first?.time, 12.345)
        XCTAssertGreaterThan(publications, 0)
        clock.set(100.11)
        capture.onFrame?(frame(count: 256, value: 1))
        await waitUntil { model.receivedFrameCount == 384 }
        XCTAssertTrue(model.clipping)
        model.removePCMFrameHandler(id)
        clock.set(100.22)
        capture.onFrame?(frame(count: 32))
        await waitUntil { model.receivedFrameCount == 416 }
        XCTAssertEqual(recorder.records.count, 2)
        subscription.cancel()
        model.stop()
    }

    func testStoppedAndReroutedQueuedFramesMetersAndErrorsCannotAffectNewSession() async {
        let (model, _, capture, _) = fixture()
        let recorder = InputRegressionPCMRecorder()
        let id = model.addPCMFrameHandler { recorder.record(samples: $0, rate: $1, time: $2) }
        model.configureInput(uid: ur12.uid, channel: 1)
        model.requestPermissionAndStart()
        let oldFrame = capture.onFrame
        let oldError = capture.onError
        let oldRouteChange = capture.onConfigurationChanged
        oldFrame?(frame(count: 2_048, value: 1)) // Worker/main updates may now be queued.
        model.toggle()
        XCTAssertFalse(model.isStartRequested)
        let deliveredBeforeNewRoute = recorder.records.count
        oldFrame?(frame(count: 512, value: 1))
        oldError?(InputCaptureError.deviceMismatch)
        oldRouteChange?()
        model.configureInput(uid: ur12.uid, channel: 0)
        model.requestPermissionAndStart()
        oldFrame?(frame(count: 1_024, value: 1))
        oldError?(InputCaptureError.invalidBuffer)
        capture.onFrame?(frame(count: 64, levels: [-12, -120], value: 0.25))
        await waitUntil { model.receivedFrameCount == 64 }
        await drainCallbacks()
        XCTAssertTrue(model.isRunning)
        XCTAssertEqual(model.selectedChannel, 0)
        XCTAssertEqual(model.receivedFrameCount, 64)
        XCTAssertEqual(model.channelLevelsDBFS, [-12, -120])
        XCTAssertEqual(model.levelDBFS, -12)
        XCTAssertFalse(model.clipping)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(capture.calls.count, 2)
        XCTAssertEqual(recorder.records.count, deliveredBeforeNewRoute + 1)
        let stoppedFrame = capture.onFrame
        model.toggle()
        stoppedFrame?(frame(count: 512, value: 1))
        await drainCallbacks()
        XCTAssertFalse(model.isStartRequested)
        XCTAssertFalse(model.isRunning)
        XCTAssertEqual(capture.calls.count, 2, "A late PCM frame must not restart cancelled input")
        XCTAssertEqual(recorder.records.count, deliveredBeforeNewRoute + 1)
        XCTAssertEqual(model.receivedFrameCount, 0)
        XCTAssertEqual(model.channelLevelsDBFS, [-120, -120])
        XCTAssertEqual(model.levelDBFS, -120)
        XCTAssertNil(model.estimate)
        XCTAssertNil(model.stableChord)
        model.removePCMFrameHandler(id)
    }

    func testDeviceFormatChangeRestartsCh2AndStaleRouteEventIsIgnored() async {
        let (model, catalog, capture, _) = fixture()
        model.configureInput(uid: ur12.uid, channel: 1)
        model.requestPermissionAndStart()
        let staleRouteChange = capture.onConfigurationChanged
        catalog.devices = [mac, reconnectedUR12(id: 51, rate: 44_100)]
        capture.onConfigurationChanged?()
        await waitUntil { model.sampleRate == 44_100 && capture.calls.count == 2 }
        XCTAssertEqual(model.selectedChannel, 1)
        XCTAssertEqual(model.availableChannels, 2)
        staleRouteChange?()
        await drainCallbacks()
        XCTAssertEqual(capture.calls.count, 2)
        model.stop()
    }

    func testCaptureErrorStopsAndLateRepeatedErrorsAreIgnored() async {
        let (model, _, capture, _) = fixture()
        model.configureInput(uid: ur12.uid, channel: 1)
        model.requestPermissionAndStart()
        let error = capture.onError
        error?(InputCaptureError.operationFailed(operation: "入力PCMの取得", status: -50))
        await waitUntil { !model.isRunning }
        let message = model.errorMessage
        error?(InputCaptureError.deviceMismatch)
        await drainCallbacks()
        XCTAssertEqual(model.errorMessage, message)
        XCTAssertTrue(message?.contains("OSStatus -50") == true)
        XCTAssertEqual(model.selectedChannel, 1)
        model.stop()
    }

    func testModelCleanupStopsCaptureAndCatalogDoesNotRetainIt() {
        let catalog = InputRegressionCatalog(devices: [mac, ur12], defaultID: mac.id)
        let capture = InputRegressionCapture()
        var model: AudioInputModel? = AudioInputModel(catalog: catalog, permission: InputRegressionPermission(status: .authorized), captureFactory: { capture })
        model?.configureInput(uid: ur12.uid, channel: 1)
        model?.requestPermissionAndStart()
        weak var weakModel = model
        let stops = capture.stops
        model = nil
        XCTAssertNil(weakModel)
        XCTAssertGreaterThan(capture.stops, stops)
        XCTAssertNil(catalog.onDevicesChanged)
    }

    private func fixture(devices: [CoreAudioInputDevice]? = nil) -> (AudioInputModel, InputRegressionCatalog, InputRegressionCapture, InputRegressionClock) {
        let catalog = InputRegressionCatalog(devices: devices ?? [mac, ur12], defaultID: mac.id)
        let capture = InputRegressionCapture()
        let clock = InputRegressionClock()
        let model = AudioInputModel(clock: clock, catalog: catalog, permission: InputRegressionPermission(status: .authorized), captureFactory: { capture })
        return (model, catalog, capture, clock)
    }

    private func reconnectedUR12(id: AudioDeviceID = 99, rate: Double = 48_000) -> CoreAudioInputDevice {
        CoreAudioInputDevice(id: id, uid: ur12.uid, name: ur12.name, channelCount: 2, sampleRate: rate, deviceLatencyFrames: 16, safetyOffsetFrames: 16, bufferFrameSize: 128)
    }

    private func frame(count: Int, levels: [Double] = [-120, -6], value: Float = 0.5, timestamp: Double = 100) -> InputCaptureFrame {
        InputCaptureFrame(samples: Array(repeating: value, count: count), sampleRate: 48_000, timestampSeconds: timestamp, channelLevelsDBFS: levels, selectedChannelPeak: abs(value))
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out waiting for synthetic input callbacks")
    }

    private func drainCallbacks() async {
        try? await Task.sleep(nanoseconds: 15_000_000)
    }
}

private final class InputRegressionCatalog: AudioInputDeviceCatalogProviding {
    var onDevicesChanged: (() -> Void)?
    var devices: [CoreAudioInputDevice]
    var defaultID: AudioDeviceID?
    var defaultReads = 0
    var error: Error?

    init(devices: [CoreAudioInputDevice], defaultID: AudioDeviceID?) {
        self.devices = devices
        self.defaultID = defaultID
    }
    func inputDevices() throws -> [CoreAudioInputDevice] {
        if let error { throw error }
        return devices
    }
    func defaultInputDeviceID() throws -> AudioDeviceID? {
        defaultReads += 1
        if let error { throw error }
        return defaultID
    }
}

private final class InputRegressionPermission: AudioInputPermissionProviding {
    var authorizationStatus: AVAuthorizationStatus
    var requests = 0
    var completion: ((Bool) -> Void)?
    init(status: AVAuthorizationStatus) { authorizationStatus = status }
    func requestAccess(_ completion: @escaping (Bool) -> Void) {
        requests += 1
        self.completion = completion
    }
}

private final class InputRegressionCapture: AudioInputCapturing {
    var calls: [(id: AudioDeviceID, channel: Int)] = []
    var stops = 0
    var returnedFormat: InputCaptureFormat?
    var error: Error?
    var onFrame: ((InputCaptureFrame) -> Void)?
    var onError: ((Error) -> Void)?
    var onConfigurationChanged: (() -> Void)?

    func start(
        device: CoreAudioInputDevice, channel: Int, clock: any AudioHostClock,
        onFrame: @escaping (InputCaptureFrame) -> Void,
        onError: @escaping (Error) -> Void,
        onConfigurationChanged: @escaping () -> Void
    ) throws -> InputCaptureFormat {
        calls.append((device.id, channel))
        if let error { throw error }
        try InputPCM.validateChannel(channel, channelCount: device.channelCount)
        self.onFrame = onFrame
        self.onError = onError
        self.onConfigurationChanged = onConfigurationChanged
        return returnedFormat ?? InputCaptureFormat(sampleRate: device.sampleRate, channelCount: device.channelCount)
    }
    func stop() {
        stops += 1
        onFrame = nil
        onError = nil
        onConfigurationChanged = nil
    }
}

private final class InputRegressionClock: AudioHostClock, @unchecked Sendable {
    private let lock = NSLock()
    private var now = 100.0
    func set(_ value: Double) { lock.lock(); now = value; lock.unlock() }
    func nowSeconds() -> Double { lock.lock(); defer { lock.unlock() }; return now }
    func seconds(forHostTime hostTime: UInt64) -> Double { Double(hostTime) / 1_000_000 }
}

private final class InputRegressionPCMRecorder: @unchecked Sendable {
    struct Record {
        let samples: [Float]
        let rate: Double
        let time: Double
    }
    private let lock = NSLock()
    private var storage: [Record] = []
    var records: [Record] { lock.lock(); defer { lock.unlock() }; return storage }
    func record(samples: [Float], rate: Double, time: Double) {
        lock.lock()
        storage.append(Record(samples: samples, rate: rate, time: time))
        lock.unlock()
    }
}
