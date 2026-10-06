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
            let bounded = a4Hz.isFinite ? min(max(a4Hz, 400), 480) : 440
            if a4Hz != bounded { a4Hz = bounded; return }
            persistPreferences()
            recalculateReading()
        }
    }

    @Published
    var selectedTuning =
        GuitarTuning.standard {
        didSet {
            persistPreferences()
            retarget()
        }
    }

    @Published
    var lockedStringNumber:
        Int?

    @Published
    var sensitivity = 0.6 {
        didSet {
            let bounded = sensitivity.isFinite ? min(max(sensitivity, 0), 1) : 0.6
            if sensitivity != bounded { sensitivity = bounded; return }
            analysisPipeline.setSensitivity(sensitivity)
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

    private let analysisPipeline: TunerAnalysisPipeline
    private let clock: any AudioHostClock
    private var tracker = TunerPitchTracker()
    private var handlerID: UUID?
    private var inputStateSubscription: AnyCancellable?
    private var freshnessTimer: DispatchSourceTimer?
    private var lastResultReceivedAt: Double?

    var targetString: GuitarStringTuning? {
        target?.string ?? selectedTuning.strings.first { $0.stringNumber == lockedStringNumber }
    }

    var targetFrequencyHz: Double? {
        targetString.map { GuitarNote.frequency(forMIDI: $0.midi, a4Hz: a4Hz) }
    }

    init(
        audio: AudioInputModel,
        preferencesStore: AppPreferencesStore,
        analysisPipeline: TunerAnalysisPipeline = TunerAnalysisPipeline(),
        clock: any AudioHostClock = SystemAudioHostClock()
    ) {
        self.audio = audio
        self.preferencesStore = preferencesStore
        self.analysisPipeline = analysisPipeline
        self.clock = clock

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
        inputStateSubscription = audio.$isRunning.dropFirst().sink { [weak self] running in
            if !running { self?.resetInputAnalysis() }
        }
    }

    /// Observing a visible tuner does not itself request permission or start hardware.
    func start(requestInput: Bool = true) {
        if handlerID == nil {
            analysisPipeline.start(sensitivity: sensitivity) { [weak self] result in
                Task { @MainActor [weak self] in self?.accept(result) }
            }
            handlerID = audio.addPCMFrameHandler { [weak pipeline = analysisPipeline] samples, rate, time in
                pipeline?.ingest(samples: samples, sampleRate: rate, timestampSeconds: time)
            }
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
            timer.setEventHandler { [weak self] in self?.expireReading() }
            timer.resume()
            freshnessTimer = timer
        }
        if requestInput && !audio.isRunning { audio.requestPermissionAndStart() }
    }

    func stop() {
        if let handlerID { audio.removePCMFrameHandler(handlerID) }
        handlerID = nil
        analysisPipeline.stop()
        freshnessTimer?.cancel()
        freshnessTimer = nil
        clearReading()
    }

    deinit {
        if let handlerID { audio.removePCMFrameHandler(handlerID) }
        analysisPipeline.stop()
        freshnessTimer?.cancel()
    }

    private func resetInputAnalysis() {
        analysisPipeline.reset()
        clearReading()
    }

    private func clearReading() {
        tracker.reset()
        lastResultReceivedAt = nil
        reading = nil
        target = nil
    }

    func expireReading() {
        if let lastResultReceivedAt, clock.nowSeconds() - lastResultReceivedAt > TunerAnalysisPipeline.freshnessSeconds {
            clearReading()
        }
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
        if selectedTuning.id != "custom" { setTuning(savedCustomTuning()) }
    }

    private func savedCustomTuning() -> GuitarTuning {
        var tuning = GuitarTuning.customDefault
        for (number, midi) in preferencesStore.value.tuner.customStringMIDI {
            tuning = tuning.withStringMIDI(stringNumber: number, midi: midi)
        }
        return tuning
    }

    func changeCustomString(
        stringNumber: Int,
        semitones: Int
    ) {
        let current =
            selectedTuning.id ==
                "custom"
            ? selectedTuning
            : savedCustomTuning()

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

    private func accept(_ result: TunerAnalysisResult) {
        guard handlerID != nil, analysisPipeline.accepts(result) else { return }
        if result.isReset { clearReading(); return }
        lastResultReceivedAt = clock.nowSeconds()
        let frequency = tracker.update(frequencyHz: result.frequencyHz, timestampSeconds: result.timestampSeconds)
        reading = frequency.flatMap { GuitarPitchReading.fromFrequency($0, a4Hz: a4Hz) }
        retarget()
    }

    private func recalculateReading() {
        reading = reading.flatMap { GuitarPitchReading.fromFrequency($0.frequencyHz, a4Hz: a4Hz) }
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
