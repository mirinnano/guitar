import AudioToolbox
import AVFoundation
import Combine
import CoreAudio
import Foundation
import GuitarToolsCore

final class AudioInputModel:
    ObservableObject {

    @Published private(set)
    var isRunning = false

    @Published private(set)
    var inputDevices:
        [CoreAudioInputDevice] = []

    @Published private(set)
    var selectedDeviceUID:
        String?

    @Published private(set)
    var inputLabel =
        "System Default Input"

    @Published private(set)
    var sampleRate = 0.0

    @Published private(set)
    var availableChannels = 0

    @Published
    var selectedChannel = 0

    @Published private(set)
    var hardwareInputLatencyMs =
        0.0

    @Published private(set)
    var levelDBFS = -120.0

    @Published private(set)
    var clipping = false

    @Published private(set)
    var estimate:
        ChordEstimate?

    @Published private(set)
    var stableChord:
        String?

    @Published private(set)
    var errorMessage:
        String?

    @Published private(set)
    var permissionDenied = false

    var onOnset:
        ((AudioOnset) -> Void)?

    var onStableChord:
        ((String, Double) -> Void)?

    var selectedDevice:
        CoreAudioInputDevice? {
        guard let selectedDeviceUID
        else {
            return nil
        }

        return inputDevices
            .first {
                $0.uid ==
                    selectedDeviceUID
            }
    }

    typealias PCMFrameHandler =
        (
            _ samples: [Float],
            _ sampleRate: Double,
            _ timestampSeconds: Double
        ) -> Void

    private let engine =
        AVAudioEngine()

    private let pipeline =
        LiveChordAnalysisPipeline()

    private let clock:
        any AudioHostClock

    private let catalog:
        CoreAudioDeviceCatalog

    private let handlerLock =
        NSLock()

    private var pcmHandlers:
        [UUID: PCMFrameHandler] = [:]

    private var tapInstalled = false

    private var activeDeviceID:
        AudioDeviceID?

    init(
        clock:
            any AudioHostClock =
            SystemAudioHostClock(),
        catalog:
            CoreAudioDeviceCatalog =
            CoreAudioDeviceCatalog()
    ) {
        self.clock = clock
        self.catalog = catalog

        pipeline.onResult = {
            [weak self]
            estimate,
            stableChord,
            levelDBFS,
            timestamp in

            guard let self else {
                return
            }

            self.estimate = estimate
            self.stableChord =
                stableChord
            self.levelDBFS =
                levelDBFS
            self.clipping =
                levelDBFS > -0.4

            if let stableChord {
                self.onStableChord?(
                    stableChord,
                    timestamp
                )
            }
        }

        pipeline.onOnset = {
            [weak self]
            onset in

            self?.onOnset?(onset)
        }

        catalog.onDevicesChanged = {
            [weak self] in

            self?
                .handleDeviceTopologyChange()
        }

        refreshInputDevices()
    }

    func addPCMFrameHandler(
        _ handler:
            @escaping PCMFrameHandler
    ) -> UUID {
        let id = UUID()

        handlerLock.lock()
        pcmHandlers[id] = handler
        handlerLock.unlock()

        return id
    }

    func removePCMFrameHandler(
        _ id: UUID
    ) {
        handlerLock.lock()
        pcmHandlers[id] = nil
        handlerLock.unlock()
    }

    func selectInputDevice(
        uid: String?
    ) {
        let normalized =
            uid?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let next =
            normalized?
                .isEmpty == true
            ? nil
            : normalized

        guard next !=
            selectedDeviceUID
        else {
            return
        }

        let restart =
            isRunning

        if restart {
            stop()
        }

        selectedDeviceUID =
            next

        if let selectedDevice,
           selectedChannel >=
            selectedDevice.channelCount {
            selectedChannel =
                max(
                    selectedDevice
                        .channelCount - 1,
                    0
                )
        }

        updateIdleDeviceMetadata()

        if restart {
            requestPermissionAndStart()
        }
    }

    func refreshInputDevices() {
        do {
            inputDevices =
                try catalog
                    .inputDevices()

            if let selectedDeviceUID,
               !inputDevices
                .contains(
                    where: {
                        $0.uid ==
                            selectedDeviceUID
                    }
                ) {
                self.selectedDeviceUID =
                    nil
            }

            updateIdleDeviceMetadata()
        } catch {
            inputDevices = []
            errorMessage =
                "オーディオデバイス一覧を取得できませんでした: \(error.localizedDescription)"
        }
    }

    func toggle() {
        if isRunning {
            stop()
        } else {
            requestPermissionAndStart()
        }
    }

    func requestPermissionAndStart() {
        errorMessage = nil

        switch AVCaptureDevice
            .authorizationStatus(
                for: .audio
            ) {
        case .authorized:
            startEngine()

        case .notDetermined:
            AVCaptureDevice
                .requestAccess(
                    for: .audio
                ) {
                    [weak self]
                    granted in

                    DispatchQueue
                        .main
                        .async {
                            guard let self
                            else {
                                return
                            }

                            if granted {
                                self.startEngine()
                            } else {
                                self.permissionDenied =
                                    true
                                self.errorMessage =
                                    "マイク/オーディオ入力へのアクセスが許可されていません。システム設定 > プライバシーとセキュリティ > マイクで許可してください。"
                            }
                        }
                }

        default:
            permissionDenied = true
            errorMessage =
                "マイク/オーディオ入力へのアクセスが許可されていません。システム設定 > プライバシーとセキュリティ > マイクで許可してください。"
        }
    }

    func stop() {
        guard
            isRunning ||
            tapInstalled
        else {
            return
        }

        if tapInstalled {
            engine.inputNode
                .removeTap(
                    onBus: 0
                )
            tapInstalled = false
        }

        engine.stop()
        pipeline.reset()

        isRunning = false
        activeDeviceID = nil
        levelDBFS = -120
        clipping = false
        estimate = nil
        stableChord = nil

        updateIdleDeviceMetadata()
    }

    private func startEngine() {
        guard !isRunning else {
            return
        }

        do {
            engine.stop()
            engine.reset()

            let input =
                engine.inputNode

            let target =
                try resolvedInputDevice()

            if let deviceID =
                target?.id ??
                catalog
                    .defaultInputDeviceID() {
                try setCurrentDevice(
                    deviceID,
                    inputNode:
                        input
                )

                activeDeviceID =
                    deviceID
            }

            let format =
                input.outputFormat(
                    forBus: 0
                )

            let channelCount =
                Int(
                    format.channelCount
                )

            guard
                channelCount > 0,
                format.sampleRate > 0
            else {
                throw AudioInputError
                    .noInputChannels
            }

            let channel =
                min(
                    max(
                        selectedChannel,
                        0
                    ),
                    channelCount - 1
                )

            selectedChannel =
                channel
            availableChannels =
                channelCount
            sampleRate =
                format.sampleRate

            if let activeDeviceID,
               let device =
                inputDevices
                    .first(
                        where: {
                            $0.id ==
                                activeDeviceID
                        }
                    ) {
                hardwareInputLatencyMs =
                    device
                        .estimatedInputLatencyMs
                inputLabel =
                    channelCount > 1
                    ? "\(device.name) · Ch \(channel + 1)"
                    : "\(device.name) · Mono"
            } else {
                hardwareInputLatencyMs =
                    input.presentationLatency *
                    1_000
                inputLabel =
                    channelCount > 1
                    ? "System Default Input · Ch \(channel + 1)"
                    : "System Default Input · Mono"
            }

            input.installTap(
                onBus: 0,
                bufferSize: 2_048,
                format: format
            ) {
                [weak self]
                audioBuffer,
                when in

                guard
                    let self,
                    let channels =
                        audioBuffer
                            .floatChannelData
                else {
                    return
                }

                let frameCount =
                    Int(
                        audioBuffer
                            .frameLength
                    )

                guard frameCount > 0
                else {
                    return
                }

                let pointer =
                    channels[channel]

                let samples =
                    Array(
                        UnsafeBufferPointer(
                            start: pointer,
                            count:
                                frameCount
                        )
                    )

                let startTime:
                    Double

                if when
                    .isHostTimeValid {
                    startTime =
                        self.clock
                            .seconds(
                                forHostTime:
                                    when.hostTime
                            )
                } else {
                    startTime =
                        self.clock
                            .nowSeconds() -
                        Double(
                            frameCount
                        ) /
                        format.sampleRate
                }

                self.handlerLock.lock()

                let handlers =
                    Array(
                        self
                            .pcmHandlers
                            .values
                    )

                self.handlerLock.unlock()

                for handler in handlers {
                    handler(
                        samples,
                        format.sampleRate,
                        startTime
                    )
                }

                self.pipeline.ingest(
                    samples: samples,
                    sampleRate:
                        format.sampleRate,
                    bufferStartTimeSeconds:
                        startTime
                )
            }

            tapInstalled = true

            engine.prepare()
            try engine.start()

            permissionDenied = false
            isRunning = true

        } catch {
            if tapInstalled {
                engine.inputNode
                    .removeTap(
                        onBus: 0
                    )

                tapInstalled = false
            }

            engine.stop()
            isRunning = false
            activeDeviceID = nil

            errorMessage =
                "オーディオ入力を開始できませんでした: \(error.localizedDescription)"
        }
    }

    private func resolvedInputDevice()
        throws
        -> CoreAudioInputDevice? {

        if let selectedDeviceUID {
            guard let device =
                inputDevices
                    .first(
                        where: {
                            $0.uid ==
                                selectedDeviceUID
                        }
                    )
            else {
                throw AudioInputError
                    .selectedDeviceUnavailable
            }

            return device
        }

        guard let defaultID =
            try catalog
                .defaultInputDeviceID()
        else {
            return nil
        }

        return inputDevices
            .first {
                $0.id == defaultID
            }
    }

    private func setCurrentDevice(
        _ deviceID:
            AudioDeviceID,
        inputNode:
            AVAudioInputNode
    ) throws {
        guard let audioUnit =
            inputNode.audioUnit
        else {
            throw AudioInputError
                .missingAudioUnit
        }

        var mutableDeviceID =
            deviceID

        let status =
            AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &mutableDeviceID,
                UInt32(
                    MemoryLayout<
                        AudioDeviceID
                    >.size
                )
            )

        guard status == noErr
        else {
            throw AudioInputError
                .deviceSelectionFailed(
                    status
                )
        }
    }

    private func handleDeviceTopologyChange() {
        let restart =
            isRunning

        if restart {
            stop()
        }

        refreshInputDevices()

        if restart {
            requestPermissionAndStart()
        }
    }

    private func updateIdleDeviceMetadata() {
        guard !isRunning
        else {
            return
        }

        let device:
            CoreAudioInputDevice?

        if let selectedDevice {
            device = selectedDevice
        } else if
            let defaultID =
                try? catalog
                    .defaultInputDeviceID() {
            device =
                inputDevices
                    .first {
                        $0.id ==
                            defaultID
                    }
        } else {
            device = nil
        }

        if let device {
            availableChannels =
                device.channelCount
            sampleRate =
                device.sampleRate
            hardwareInputLatencyMs =
                device
                    .estimatedInputLatencyMs

            if selectedChannel >=
                device.channelCount {
                selectedChannel =
                    max(
                        device
                            .channelCount -
                        1,
                        0
                    )
            }

            inputLabel =
                selectedDeviceUID == nil
                ? "System Default · \(device.name)"
                : device.name
        } else {
            availableChannels = 0
            sampleRate = 0
            hardwareInputLatencyMs = 0
            inputLabel =
                "No Audio Input"
        }
    }

    deinit {
        catalog.onDevicesChanged =
            nil

        if tapInstalled {
            engine.inputNode
                .removeTap(
                    onBus: 0
                )
        }

        engine.stop()
    }
}

private enum AudioInputError:
    LocalizedError {

    case noInputChannels
    case selectedDeviceUnavailable
    case missingAudioUnit
    case deviceSelectionFailed(
        OSStatus
    )

    var errorDescription:
        String? {
        switch self {
        case .noInputChannels:
            "使用可能なオーディオ入力チャンネルがありません。"

        case .selectedDeviceUnavailable:
            "選択したオーディオ入力デバイスが接続されていません。"

        case .missingAudioUnit:
            "AVAudioEngineの入力AudioUnitを取得できませんでした。"

        case let .deviceSelectionFailed(
            status
        ):
            "入力デバイスの切り替えに失敗しました (OSStatus \(status))。"
        }
    }
}
