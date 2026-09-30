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

    private let engine =
        AVAudioEngine()

    private let pipeline =
        LiveChordAnalysisPipeline()

    init() {
        pipeline.onResult = {
            [weak self]
            estimate,
            stableChord,
            levelDBFS in

            guard let self else {
                return
            }

            self.estimate = estimate
            self.stableChord = stableChord
            self.levelDBFS = levelDBFS
            self.clipping =
                levelDBFS > -0.4
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

                    DispatchQueue.main.async {
                        guard let self else {
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
        guard isRunning else {
            return
        }

        engine.inputNode
            .removeTap(
                onBus: 0
            )
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

            selectedChannel = channel
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
                _ in

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
                        audioBuffer.frameLength
                    )

                guard frameCount > 0 else {
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

                self.pipeline.ingest(
                    samples: samples,
                    sampleRate:
                        format.sampleRate
                )
            }

            engine.prepare()
            try engine.start()

            permissionDenied = false
            isRunning = true
            inputLabel =
                channelCount > 1
                ? "macOS Default Input · Ch (channel + 1)"
                : "macOS Default Input · Mono"

        } catch {
            runCatchingStopTap()

            isRunning = false
            errorMessage =
                "オーディオ入力を開始できませんでした: (error.localizedDescription)"
        }
    }

    private func runCatchingStopTap() {
        engine.inputNode
            .removeTap(
                onBus: 0
            )
        engine.stop()
    }

    deinit {
        if isRunning {
            engine.inputNode
                .removeTap(
                    onBus: 0
                )
            engine.stop()
        }
    }
}

private enum AudioInputError:
    LocalizedError {

    case noInputChannels

    var errorDescription: String? {
        switch self {
        case .noInputChannels:
            "使用可能なオーディオ入力チャンネルがありません。"
        }
    }
}
