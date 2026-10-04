import AudioToolbox
import AVFoundation
import Combine
import CoreAudio
import Foundation
import GuitarToolsCore

protocol AudioInputDeviceCatalogProviding: AnyObject {
    var onDevicesChanged: (() -> Void)? { get set }
    func inputDevices() throws -> [CoreAudioInputDevice]
    func defaultInputDeviceID() throws -> AudioDeviceID?
}

extension CoreAudioDeviceCatalog: AudioInputDeviceCatalogProviding {}

protocol AudioInputPermissionProviding {
    var authorizationStatus: AVAuthorizationStatus { get }
    func requestAccess(_ completion: @escaping (Bool) -> Void)
}

struct SystemAudioInputPermission: AudioInputPermissionProviding {
    var authorizationStatus: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .audio) }
    func requestAccess(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }
}

/// UI-facing configuration/lifecycle methods are called on the main thread.
/// PCM handlers are delivered on a serial input-processing queue, not the HAL
/// render thread. Catalog, permission and capture dependencies are injectable.
final class AudioInputModel: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var inputDevices: [CoreAudioInputDevice] = []
    @Published private(set) var selectedDeviceUID: String?
    @Published private(set) var inputLabel = "System Default Input"
    @Published private(set) var sampleRate = 0.0
    @Published private(set) var availableChannels = 0
    @Published var selectedChannel = 0 {
        didSet {
            guard !applyingConfiguration, selectedChannel != oldValue else { return }
            guard (0...63).contains(selectedChannel) else {
                applyingConfiguration = true
                selectedChannel = oldValue
                applyingConfiguration = false
                report(InputCaptureError.invalidSavedChannel)
                return
            }
            // Preserve the writable published API, including direct bindings.
            reconfigureCapture()
        }
    }
    @Published private(set) var hardwareInputLatencyMs = 0.0
    @Published private(set) var levelDBFS = InputPCM.silenceDBFS
    @Published private(set) var channelLevelsDBFS: [Double] = []
    /// Total frames in this capture session, published with meters at ~10 Hz.
    @Published private(set) var receivedFrameCount = 0
    @Published private(set) var inputHealthMessage: String?
    @Published private(set) var clipping = false
    @Published private(set) var estimate: ChordEstimate?
    @Published private(set) var stableChord: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var permissionDenied = false

    var onOnset: ((AudioOnset) -> Void)?
    var onStableChord: ((String, Double) -> Void)?

    var selectedDevice: CoreAudioInputDevice? {
        guard let selectedDeviceUID else { return nil }
        return inputDevices.first { $0.uid == selectedDeviceUID }
    }

    var selectedDeviceUnavailable: Bool { selectedDeviceUID != nil && selectedDevice == nil }

    typealias PCMFrameHandler = (_ samples: [Float], _ sampleRate: Double, _ timestampSeconds: Double) -> Void

    private let clock: any AudioHostClock
    private let catalog: any AudioInputDeviceCatalogProviding
    private let permission: any AudioInputPermissionProviding
    private let captureFactory: () -> any AudioInputCapturing
    private let handlerLock = NSLock()
    private var pcmHandlers: [UUID: PCMFrameHandler] = [:]
    private let frameQueue = DispatchQueue(label: "dev.mirinnano.guitartools.mac.input-pcm", qos: .userInitiated)
    private let generations = InputCaptureGenerationGate()
    private var capture: (any AudioInputCapturing)?
    private var session: InputAnalysisSession?
    private var activeDevice: CoreAudioInputDevice?
    private var wantsCapture = false
    private var permissionRequestID: UUID?
    private var applyingConfiguration = false
    private var routeFailureMessage: String?

    init(
        clock: any AudioHostClock = SystemAudioHostClock(),
        catalog: any AudioInputDeviceCatalogProviding = CoreAudioDeviceCatalog(),
        permission: any AudioInputPermissionProviding = SystemAudioInputPermission(),
        captureFactory: @escaping () -> any AudioInputCapturing = { CoreAudioInputCapture() }
    ) {
        self.clock = clock
        self.catalog = catalog
        self.permission = permission
        self.captureFactory = captureFactory
        catalog.onDevicesChanged = { [weak self] in self?.refreshInputDevices() }
        refreshInputDevices()
    }

    func addPCMFrameHandler(_ handler: @escaping PCMFrameHandler) -> UUID {
        let id = UUID()
        handlerLock.lock()
        pcmHandlers[id] = handler
        handlerLock.unlock()
        return id
    }

    func removePCMFrameHandler(_ id: UUID) {
        handlerLock.lock()
        pcmHandlers[id] = nil
        handlerLock.unlock()
    }

    /// Atomic route selection. UR12 guitar uses channel 1 (hardware Ch 2).
    /// Valid saved channels (0...63) survive disconnects, with no hardware clamp.
    /// This configures only; idle selection never asks permission or opens I/O.
    func configureInput(uid: String?, channel: Int) {
        guard (0...63).contains(channel) else {
            report(InputCaptureError.invalidSavedChannel)
            return
        }
        let trimmed = uid?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextUID = trimmed?.isEmpty == true ? nil : trimmed
        guard nextUID != selectedDeviceUID || channel != selectedChannel else { return }
        shutDownCapture()
        applyingConfiguration = true
        selectedDeviceUID = nextUID
        selectedChannel = channel
        applyingConfiguration = false
        errorMessage = nil
        routeFailureMessage = nil
        updateIdleDeviceMetadata()
        resumeRequestedCapture()
    }

    func selectInputDevice(uid: String?) { configureInput(uid: uid, channel: selectedChannel) }
    func selectInputChannel(_ channel: Int) { configureInput(uid: selectedDeviceUID, channel: channel) }

    private func reconfigureCapture() {
        shutDownCapture()
        errorMessage = nil
        routeFailureMessage = nil
        updateIdleDeviceMetadata()
        resumeRequestedCapture()
    }

    func refreshInputDevices() { refreshInputDevices(forceRestart: false) }

    private func refreshInputDevices(forceRestart: Bool) {
        do {
            inputDevices = try catalog.inputDevices()
        } catch {
            shutDownCapture()
            inputDevices = []
            report(error, prefix: "オーディオ入力デバイス一覧を取得できませんでした")
            updateIdleDeviceMetadata()
            return
        }
        do {
            let target = try resolvedInputDevice()
            if let routeFailureMessage, errorMessage == routeFailureMessage { errorMessage = nil }
            routeFailureMessage = nil
            if isRunning, forceRestart || activeDevice != target { shutDownCapture() }
            updateIdleDeviceMetadata()
            resumeRequestedCapture()
        } catch {
            shutDownCapture()
            report(error)
            routeFailureMessage = errorMessage
            updateIdleDeviceMetadata()
            // wantsCapture remains armed. A later catalog notification resolves
            // this same UID again (including its new numeric device ID).
        }
    }

    func toggle() {
        if isRunning || permissionRequestID != nil { stop() }
        else { requestPermissionAndStart() }
    }

    func requestPermissionAndStart() {
        wantsCapture = true
        guard !isRunning, permissionRequestID == nil else { return }
        errorMessage = nil
        switch permission.authorizationStatus {
        case .authorized:
            startCapture()
        case .notDetermined:
            let requestID = UUID()
            permissionRequestID = requestID
            inputHealthMessage = "マイク/オーディオ入力の許可を待っています。"
            permission.requestAccess { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.permissionRequestID == requestID, self.wantsCapture else { return }
                    self.permissionRequestID = nil
                    if granted { self.startCapture() }
                    else { self.reportPermissionDenied() }
                }
            }
        default:
            reportPermissionDenied()
        }
    }

    func stop() {
        wantsCapture = false
        permissionRequestID = nil // A late permission completion must not start I/O.
        shutDownCapture()
        updateIdleDeviceMetadata()
    }

    private func resumeRequestedCapture() {
        guard wantsCapture, !isRunning, permissionRequestID == nil else { return }
        // Reroutes/reconnects never request permission. Only user start does.
        if permission.authorizationStatus == .authorized { startCapture() }
        else if permission.authorizationStatus != .notDetermined { reportPermissionDenied() }
    }

    private func startCapture() {
        guard wantsCapture, !isRunning else { return }
        // No capture factory invocation until the user has started and the
        // existing microphone-permission flow has granted access.
        let generation = generations.begin()
        let session = InputAnalysisSession(generation: generation, channel: selectedChannel)
        configureAnalysis(session)
        self.session = session
        errorMessage = nil
        routeFailureMessage = nil
        do {
            let target = try resolvedInputDevice()
            let inputCapture = captureFactory()
            capture = inputCapture // Own partial initialization for error cleanup.
            let format = try inputCapture.start(
                device: target,
                channel: selectedChannel,
                clock: clock,
                onFrame: { [weak self] frame in self?.enqueue(frame, session: session) },
                onError: { [weak self] error in
                    DispatchQueue.main.async {
                        guard let self, self.generations.accepts(generation) else { return }
                        self.shutDownCapture()
                        self.report(error, prefix: "オーディオ入力を継続できませんでした")
                        self.updateIdleDeviceMetadata()
                    }
                },
                onConfigurationChanged: { [weak self] in
                    DispatchQueue.main.async {
                        guard let self, self.generations.accepts(generation) else { return }
                        self.refreshInputDevices(forceRestart: true)
                    }
                }
            )
            // Also enforce the adapter contract for injected/alternate sources.
            guard format.channelCount == target.channelCount else {
                throw InputCaptureError.channelCountMismatch(expected: target.channelCount, actual: format.channelCount)
            }
            try InputPCM.validateChannel(selectedChannel, channelCount: format.channelCount)
            guard format.sampleRate.isFinite, format.sampleRate > 0 else { throw InputCaptureError.invalidFormat }
            activeDevice = target
            availableChannels = format.channelCount
            sampleRate = format.sampleRate
            hardwareInputLatencyMs = (Double(target.deviceLatencyFrames) + Double(target.safetyOffsetFrames) + Double(target.bufferFrameSize)) / format.sampleRate * 1_000
            inputLabel = label(for: target, channelCount: format.channelCount)
            channelLevelsDBFS = Array(repeating: InputPCM.silenceDBFS, count: format.channelCount)
            receivedFrameCount = 0
            permissionDenied = false
            isRunning = true
            inputHealthMessage = "入力データを待っています。"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, self.generations.accepts(generation), self.isRunning, self.receivedFrameCount == 0 else { return }
                self.inputHealthMessage = "入力データを受信できていません。デバイスの接続と入力設定を確認してください。"
            }
        } catch {
            shutDownCapture()
            report(error, prefix: "オーディオ入力を開始できませんでした")
            if let inputError = error as? InputCaptureError {
                switch inputError {
                case .selectedDeviceUnavailable, .noDefaultInput:
                    routeFailureMessage = errorMessage
                default:
                    break
                }
            }
            updateIdleDeviceMetadata()
        }
    }

    private func configureAnalysis(_ session: InputAnalysisSession) {
        let generation = session.generation
        // A fresh pipeline per generation is intentional. The pipeline delivers
        // asynchronously via mutable callbacks: reusing it could relabel old
        // queued analysis as results for a new capture after stop/reroute.
        session.pipeline.onResult = { [weak self] estimate, stableChord, _, timestamp in
            guard let self, self.generations.accepts(generation), self.isRunning else { return }
            self.estimate = estimate
            self.stableChord = stableChord
            if let stableChord { self.onStableChord?(stableChord, timestamp) }
        }
        session.pipeline.onOnset = { [weak self] onset in
            guard let self, self.generations.accepts(generation), self.isRunning else { return }
            self.onOnset?(onset)
        }
    }

    private func enqueue(_ frame: InputCaptureFrame, session: InputAnalysisSession) {
        frameQueue.async { [weak self] in
            guard let self, self.generations.accepts(session.generation), frame.frameCount > 0 else { return }
            guard frame.sampleRate.isFinite, frame.sampleRate > 0,
                  frame.channelLevelsDBFS.indices.contains(session.channel) else {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generations.accepts(session.generation) else { return }
                    self.shutDownCapture()
                    self.report(InputCaptureError.invalidBuffer)
                    self.updateIdleDeviceMetadata()
                }
                return
            }
            self.handlerLock.lock()
            let handlers = Array(self.pcmHandlers.values)
            self.handlerLock.unlock()
            // Invalidation drains an in-flight delivery, so no old PCM handler
            // can run after stop() returns. Queued work is simply discarded.
            self.generations.performIfCurrent(session.generation) {
                for handler in handlers {
                    guard self.generations.accepts(session.generation) else { return }
                    handler(frame.samples, frame.sampleRate, frame.timestampSeconds)
                }
                guard self.generations.accepts(session.generation) else { return }
                session.pipeline.ingest(samples: frame.samples, sampleRate: frame.sampleRate, bufferStartTimeSeconds: frame.timestampSeconds)
                if let snapshot = session.meter.ingest(frame, at: self.clock.nowSeconds()) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.generations.accepts(session.generation), self.isRunning else { return }
                        self.receivedFrameCount = snapshot.receivedFrameCount
                        self.channelLevelsDBFS = snapshot.channelLevelsDBFS
                        self.levelDBFS = snapshot.channelLevelsDBFS[session.channel]
                        self.clipping = snapshot.clipping
                        self.inputHealthMessage = snapshot.channelLevelsDBFS[session.channel] < -90 && snapshot.channelLevelsDBFS.contains(where: { $0 > -55 })
                            ? "Ch \(session.channel + 1) の信号が小さい状態です。接続する入力端子とGAINを確認してください。別のチャンネルには切り替えません。"
                            : nil
                    }
                }
            }
        }
    }

    private func shutDownCapture() {
        generations.invalidate() // Invalidate before stopping or clearing meters.
        let oldCapture = capture
        capture = nil
        oldCapture?.stop()
        session = nil
        activeDevice = nil
        isRunning = false
        receivedFrameCount = 0
        levelDBFS = InputPCM.silenceDBFS
        channelLevelsDBFS = []
        clipping = false
        estimate = nil
        stableChord = nil
        inputHealthMessage = nil
    }

    private func resolvedInputDevice() throws -> CoreAudioInputDevice {
        try InputRoutePolicy.resolve(uid: selectedDeviceUID, devices: inputDevices) {
            try catalog.defaultInputDeviceID()
        }
    }

    private func updateIdleDeviceMetadata() {
        guard !isRunning else { return }
        do {
            let device = try resolvedInputDevice()
            availableChannels = device.channelCount
            sampleRate = device.sampleRate
            hardwareInputLatencyMs = device.estimatedInputLatencyMs
            channelLevelsDBFS = Array(repeating: InputPCM.silenceDBFS, count: device.channelCount)
            inputLabel = label(for: device, channelCount: device.channelCount)
            do {
                try InputPCM.validateChannel(selectedChannel, channelCount: device.channelCount)
                inputHealthMessage = errorMessage
            } catch {
                inputHealthMessage = errorMessage ?? error.localizedDescription
            }
        } catch {
            // An explicit missing UID must never consult/substitute the default,
            // and metadata must never alter a saved Ch 2 selection on unplug.
            availableChannels = 0
            sampleRate = 0
            hardwareInputLatencyMs = 0
            channelLevelsDBFS = []
            inputLabel = selectedDeviceUID == nil ? "オーディオ入力なし" : "選択した入力（未接続）"
            inputHealthMessage = errorMessage ?? error.localizedDescription
        }
    }

    private func label(for device: CoreAudioInputDevice, channelCount: Int) -> String {
        let name = selectedDeviceUID == nil ? "System Default · \(device.name)" : device.name
        if !(0..<channelCount).contains(selectedChannel) { return "\(name) · Ch \(selectedChannel + 1)（使用不可）" }
        return channelCount == 1 ? "\(name) · Mono" : "\(name) · Ch \(selectedChannel + 1)"
    }

    private func report(_ error: Error, prefix: String? = nil) {
        let detail: String
        if case let CoreAudioCatalogError.operationFailed(_, status) = error {
            detail = "CoreAudioエラー（OSStatus \(status)）。別の入力には切り替えません。"
        } else {
            detail = error.localizedDescription
        }
        errorMessage = prefix.map { "\($0): \(detail)" } ?? detail
        inputHealthMessage = errorMessage
    }

    private func reportPermissionDenied() {
        wantsCapture = false
        permissionDenied = true
        errorMessage = "マイク/オーディオ入力へのアクセスが許可されていません。システム設定 > プライバシーとセキュリティ > マイクで許可してください。"
        inputHealthMessage = errorMessage
    }

    deinit {
        generations.invalidate()
        catalog.onDevicesChanged = nil
        capture?.stop()
    }
}

// Pure route policy: an explicit UID cannot fall back to the system default or
// the first enumerated device. The default is resolved only for a nil UID.
enum InputRoutePolicy {
    static func resolve(
        uid: String?,
        devices: [CoreAudioInputDevice],
        defaultDeviceID: () throws -> AudioDeviceID?
    ) throws -> CoreAudioInputDevice {
        if let uid {
            guard let device = devices.first(where: { $0.uid == uid }) else { throw InputCaptureError.selectedDeviceUnavailable }
            return device
        }
        guard let id = try defaultDeviceID(), let device = devices.first(where: { $0.id == id }) else { throw InputCaptureError.noDefaultInput }
        return device
    }
}

final class InputCaptureGenerationGate {
    private let lock = NSRecursiveLock()
    private var current: UUID?

    func begin() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let next = UUID()
        current = next
        return next
    }

    func invalidate() {
        lock.lock()
        current = nil
        lock.unlock()
    }

    func accepts(_ generation: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return current == generation
    }

    func performIfCurrent(_ generation: UUID, _ work: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard current == generation else { return }
        work()
    }
}

struct InputMeterSnapshot {
    let receivedFrameCount: Int
    let channelLevelsDBFS: [Double]
    let clipping: Bool
}

struct InputMeterAccumulator {
    private(set) var receivedFrameCount = 0
    private var lastPublicationTime: Double?
    private var peakSincePublication: Float = 0

    mutating func ingest(_ frame: InputCaptureFrame, at time: Double) -> InputMeterSnapshot? {
        receivedFrameCount += min(frame.frameCount, Int.max - receivedFrameCount)
        peakSincePublication = max(peakSincePublication, frame.selectedChannelPeak)
        if let lastPublicationTime, time >= lastPublicationTime, time - lastPublicationTime < 0.1 { return nil }
        lastPublicationTime = time
        let snapshot = InputMeterSnapshot(receivedFrameCount: receivedFrameCount, channelLevelsDBFS: frame.channelLevelsDBFS, clipping: peakSincePublication >= 0.995)
        peakSincePublication = 0
        return snapshot
    }
}

private final class InputAnalysisSession {
    let generation: UUID
    let channel: Int
    let pipeline = LiveChordAnalysisPipeline()
    var meter = InputMeterAccumulator() // Accessed only on frameQueue.

    init(generation: UUID, channel: Int) {
        self.generation = generation
        self.channel = channel
    }
}
