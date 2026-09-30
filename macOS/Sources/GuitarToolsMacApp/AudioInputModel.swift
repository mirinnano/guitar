import AVFoundation
import Combine
import Foundation
import GuitarToolsCore

final class AudioInputModel:
    ObservableObject {

    @Published private(set)
    var isRunning = false

    @Published private(set)
    var inputLabel =
        "macOS Default Input"

    @Published private(set)
    var sampleRate = 0.0

    @Published private(set)
    var availableChannels = 0

    @Published
    var selectedChannel = 0

    @Published private(set)
    var levelDBFS = -120.0

    @Published private(set)
    var clipping = false

    @Published private(set)
    var estimate: ChordEstimate?

    @Published private(set)
    var stableChord: String?

    @Published private(set)
    var errorMessage: String?

    @Published private(set)
    var permissionDenied = false

    var onOnset:
        ((AudioOnset) -> Void)?

    var onStableChord:
        ((String, Double) -> Void)?

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

    private let handlerLock =
        NSLock()

    private var pcmHandlers:
        [UUID: PCMFrameHandler] = [:]

    private var tapInstalled = false

    init() {
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
        levelDBFS = -120
        clipping = false
        estimate = nil
        stableChord = nil
    }

    private func startEngine() {
        guard !isRunning else {
            return
        }

        do {
            let input =
                engine.inputNode

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
                            count: frameCount
                        )
                    )

                let startTime:
                    Double

                if when
                    .isHostTimeValid {
                    startTime =
                        AVAudioTime
                            .seconds(
                                forHostTime:
                                    when.hostTime
                            )
                } else {
                    startTime =
                        ProcessInfo
                            .processInfo
                            .systemUptime -
                        Double(frameCount) /
                        format.sampleRate
                }

                self.handlerLock.lock()
                let handlers =
                    Array(
                        self.pcmHandlers
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

            permissionDenied =
                false
            isRunning = true

            inputLabel =
                channelCount > 1
                ? "macOS Default Input · Ch \(channel + 1)"
                : "macOS Default Input · Mono"

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

            errorMessage =
                "オーディオ入力を開始できませんでした: \(error.localizedDescription)"
        }
    }

    deinit {
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

    var errorDescription:
        String? {
        switch self {
        case .noInputChannels:
            "使用可能なオーディオ入力チャンネルがありません。"
        }
    }
}
