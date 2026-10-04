import AVFoundation
import Combine
import Foundation
import GuitarToolsCore

@MainActor
final class TunerModel:
    ObservableObject {

    @Published
    var a4Hz = 440.0 {
        didSet {
            persistPreferences()
        }
    }

    @Published
    var selectedTuning =
        GuitarTuning.standard {
        didSet {
            persistPreferences()
        }
    }

    @Published
    var lockedStringNumber:
        Int?

    @Published
    var sensitivity = 0.6 {
        didSet {
            persistPreferences()
        }
    }

    @Published private(set)
    var reading:
        GuitarPitchReading?

    @Published private(set)
    var target:
        GuitarTuningTarget?

    private let audio:
        AudioInputModel

    private let preferencesStore:
        AppPreferencesStore

    private let detector =
        YinPitchDetector()

    private let analysisQueue =
        DispatchQueue(
            label:
                "dev.mirinnano.guitartools.mac.tuner",
            qos: .userInitiated
        )

    private var handlerID:
        UUID?

    private var history:
        [Double] = []

    init(
        audio: AudioInputModel,
        preferencesStore:
            AppPreferencesStore
    ) {
        self.audio = audio
        self.preferencesStore =
            preferencesStore

        let saved =
            preferencesStore
                .value
                .tuner

        a4Hz = saved.a4Hz
        sensitivity =
            saved.sensitivity

        if saved.tuningID ==
            "custom" {
            var custom =
                GuitarTuning
                    .customDefault

            for (
                stringNumber,
                midi
            ) in saved
                .customStringMIDI {
                custom =
                    custom.withStringMIDI(
                        stringNumber:
                            stringNumber,
                        midi: midi
                    )
            }

            selectedTuning =
                custom
        } else {
            selectedTuning =
                GuitarTuning
                    .presets
                    .first {
                        $0.id ==
                            saved.tuningID
                    }
                ?? .standard
        }
    }

    func start() {
        guard handlerID == nil
        else {
            return
        }

        if !audio.isRunning {
            audio
                .requestPermissionAndStart()
        }

        handlerID =
            audio.addPCMFrameHandler {
                [weak self]
                samples,
                sampleRate,
                _ in

                guard let self else {
                    return
                }

                Task {
                    @MainActor in

                    let sensitivity =
                        self.sensitivity

                    self.analysisQueue
                        .async {
                            Self.processFrame(
                                samples:
                                    samples,
                                sampleRate:
                                    sampleRate,
                                sensitivity:
                                    sensitivity
                            ) {
                                [weak self]
                                frequency in

                                Task {
                                    @MainActor in
                                    self?
                                        .acceptFrequency(
                                            frequency
                                        )
                                }
                            }
                        }
                }
            }
    }

    func stop() {
        if let handlerID {
            audio.removePCMFrameHandler(
                handlerID
            )
        }

        handlerID = nil
        history.removeAll()
        reading = nil
        target = nil
    }

    func setTuning(
        _ tuning:
            GuitarTuning
    ) {
        selectedTuning = tuning
        lockedStringNumber = nil
        retarget()
    }

    func selectCustomTuning() {
        if selectedTuning.id !=
            "custom" {
            selectedTuning =
                .customDefault
        }
        retarget()
    }

    func changeCustomString(
        stringNumber: Int,
        semitones: Int
    ) {
        let current =
            selectedTuning.id ==
                "custom"
            ? selectedTuning
            : .customDefault

        guard let string =
            current.strings
                .first(
                    where: {
                        $0.stringNumber ==
                            stringNumber
                    }
                )
        else {
            return
        }

        selectedTuning =
            current.withStringMIDI(
                stringNumber:
                    stringNumber,
                midi:
                    string.midi +
                    semitones
            )

        retarget()
    }

    func setLockedString(
        _ stringNumber: Int?
    ) {
        lockedStringNumber =
            stringNumber
        retarget()
    }

    private nonisolated static func processFrame(
        samples: [Float],
        sampleRate: Double,
        sensitivity: Double,
        completion:
            @escaping (Double?) -> Void
    ) {
        let minimumRMS =
            0.025 -
            sensitivity *
            (0.025 - 0.003)

        let rms =
            sqrt(
                samples.reduce(0.0) {
                    $0 +
                    Double(
                        $1 * $1
                    )
                } /
                Double(
                    max(
                        samples.count,
                        1
                    )
                )
            )

        guard rms >= minimumRMS
        else {
            completion(nil)
            return
        }

        let frequency =
            YinPitchDetector()
                .detect(
                    samples: samples,
                    sampleRate:
                        sampleRate
                )

        completion(frequency)
    }

    private func acceptFrequency(
        _ frequency: Double?
    ) {
        guard let frequency
        else {
            history.removeAll()
            reading = nil
            target = nil
            return
        }

        history.append(
            frequency
        )

        if history.count > 5 {
            history.removeFirst(
                history.count - 5
            )
        }

        let sorted =
            history.sorted()

        let median =
            sorted[
                sorted.count / 2
            ]

        reading =
            GuitarPitchReading
                .fromFrequency(
                    median,
                    a4Hz:
                        a4Hz
                )

        retarget()
    }

    private func persistPreferences() {
        preferencesStore
            .update {
                value in

                value.tuner.a4Hz =
                    self.a4Hz
                value.tuner.tuningID =
                    self.selectedTuning.id
                value.tuner.sensitivity =
                    self.sensitivity

                if self
                    .selectedTuning
                    .id ==
                    "custom" {
                    value.tuner
                        .customStringMIDI =
                        Dictionary(
                            uniqueKeysWithValues:
                                self
                                    .selectedTuning
                                    .strings
                                    .map {
                                        (
                                            $0.stringNumber,
                                            $0.midi
                                        )
                                    }
                        )
                }
            }
    }

    private func retarget() {
        guard let reading
        else {
            target = nil
            return
        }

        if let lockedStringNumber {
            target =
                selectedTuning.target(
                    stringNumber:
                        lockedStringNumber,
                    frequencyHz:
                        reading.frequencyHz,
                    a4Hz: a4Hz
                )
        } else {
            target =
                selectedTuning
                    .closestString(
                        frequencyHz:
                            reading.frequencyHz,
                        a4Hz: a4Hz
                    )
        }
    }
}

@MainActor
final class ReferenceTonePlayer: ReferenceTonePlaying {
    var onPlaybackEnded: ((String?) -> Void)?

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var configurationObserver: NSObjectProtocol?
    private var generation: UInt64 = 0

    deinit {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        player?.stop()
        engine?.stop()
    }

    func play(frequency: Double, outputDeviceID: AudioDeviceID) throws {
        stop()
        guard outputDeviceID != kAudioObjectUnknown else {
            throw ReferenceToneError.invalidOutput
        }
        guard frequency.isFinite, (20.0...4_000.0).contains(frequency) else {
            throw ReferenceToneError.invalidFrequency
        }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        self.engine = engine
        self.player = player
        do {
            // Never access inputNode: reference tones must not request microphone access.
            let output = engine.outputNode
            guard let unit = output.audioUnit else { throw ReferenceToneError.invalidOutput }
            var deviceID = outputDeviceID
            let status = AudioUnitSetProperty(
                unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                &deviceID, UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            guard status == noErr else { throw ReferenceToneError.bindFailed(status) }

            // Query the bound endpoint, not the old system-default mixer format.
            let hardwareFormat = output.outputFormat(forBus: 0)
            let rate = hardwareFormat.sampleRate
            guard rate.isFinite, (8_000.0...384_000.0).contains(rate),
                  hardwareFormat.channelCount > 0,
                  let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)
            else { throw ReferenceToneError.invalidFormat }
            let buffer = try Self.makeBuffer(frequency: frequency, sampleRate: rate)
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.connect(engine.mainMixerNode, to: output, format: hardwareFormat)
            try engine.start()

            // A disappearing endpoint must not silently cause a default-speaker route.
            var actualID = AudioDeviceID(kAudioObjectUnknown)
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            let readStatus = AudioUnitGetProperty(
                unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                &actualID, &size
            )
            guard readStatus == noErr, actualID == outputDeviceID else {
                throw ReferenceToneError.invalidOutput
            }

            let token = generation
            configurationObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    self.stop()
                    self.onPlaybackEnded?("音声出力の構成が変わったため基準音を停止しました。別の出力には切り替えません。")
                }
            }
            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    self.stop()
                    self.onPlaybackEnded?(nil)
                }
            }
            player.play()
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        generation &+= 1
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
        player?.stop()
        engine?.stop()
        engine?.reset()
        player = nil
        engine = nil
    }

    /// Pure buffer generation is also tested at 44.1 kHz and 48 kHz, without audio I/O.
    static func makeBuffer(frequency: Double, sampleRate: Double) throws -> AVAudioPCMBuffer {
        guard frequency.isFinite, (20.0...4_000.0).contains(frequency) else {
            throw ReferenceToneError.invalidFrequency
        }
        guard sampleRate.isFinite, (8_000.0...384_000.0).contains(sampleRate),
              frequency < sampleRate / 2,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        else { throw ReferenceToneError.invalidFormat }
        let duration = 1.2
        let frames = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0]
        else { throw ReferenceToneError.invalidFormat }
        buffer.frameLength = frames
        for index in 0..<Int(frames) {
            let time = Double(index) / sampleRate
            let envelope = max(0, min(1, min(time / 0.02, (duration - time) / 0.08)))
            samples[index] = Float(sin(2 * .pi * frequency * time) * 0.12 * envelope)
        }
        return buffer
    }

    private enum ReferenceToneError: LocalizedError {
        case invalidFrequency
        case invalidOutput
        case invalidFormat
        case bindFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .invalidFrequency:
                return "基準音の周波数は20〜4,000 Hzの有限の値で指定してください"
            case .invalidOutput:
                return "指定した音声出力が見つからないか、確認できません"
            case .invalidFormat:
                return "選択した音声出力のサンプル形式には対応していません"
            case .bindFailed(let status):
                return "選択した音声出力に接続できません（OSStatus \(status)）"
            }
        }
    }
}
