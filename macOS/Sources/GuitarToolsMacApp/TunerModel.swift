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

final class ReferenceTonePlayer {

    private let engine =
        AVAudioEngine()

    private let player =
        AVAudioPlayerNode()

    init() {
        engine.attach(player)
        engine.connect(
            player,
            to:
                engine.mainMixerNode,
            format: nil
        )
    }

    func play(
        frequency: Double
    ) {
        stop()

        let sampleRate =
            48_000.0
        let duration =
            1.2

        let frames =
            AVAudioFrameCount(
                sampleRate *
                duration
            )

        let format =
            AVAudioFormat(
                standardFormatWithSampleRate:
                    sampleRate,
                channels: 1
            )!

        guard let buffer =
            AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity:
                    frames
            )
        else {
            return
        }

        buffer.frameLength =
            frames

        guard let samples =
            buffer.floatChannelData?[0]
        else {
            return
        }

        for index in
            0..<Int(frames) {
            let time =
                Double(index) /
                sampleRate

            let envelope =
                min(
                    1,
                    min(
                        time / 0.02,
                        (duration - time) /
                        0.08
                    )
                )

            samples[index] =
                Float(
                    sin(
                        2 *
                        .pi *
                        frequency *
                        time
                    ) *
                    0.18 *
                    max(
                        envelope,
                        0
                    )
                )
        }

        do {
            if !engine.isRunning {
                try engine.start()
            }

            player.scheduleBuffer(
                buffer,
                at: nil,
                options:
                    .interrupts
            )

            player.play()
        } catch {
            stop()
        }
    }

    func stop() {
        player.stop()
    }
}
