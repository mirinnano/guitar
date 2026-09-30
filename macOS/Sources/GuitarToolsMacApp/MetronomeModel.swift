import AVFoundation
import Combine
import Foundation
import GuitarToolsCore

enum MacMetronomeSubdivision:
    Int,
    CaseIterable,
    Identifiable {

    case quarter = 1
    case eighth = 2
    case triplet = 3
    case sixteenth = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .quarter:
            "4分"
        case .eighth:
            "8分"
        case .triplet:
            "3連"
        case .sixteenth:
            "16分"
        }
    }
}

enum MacBeatAccent:
    Int,
    CaseIterable {

    case accent
    case normal
    case mute

    var symbol: String {
        switch self {
        case .accent:
            "●"
        case .normal:
            "○"
        case .mute:
            "×"
        }
    }
}

enum MacClickSound:
    String,
    CaseIterable,
    Identifiable {

    case digital
    case wood
    case hiHat

    var id: String { rawValue }

    var label: String {
        switch self {
        case .digital:
            "Digital"
        case .wood:
            "Wood"
        case .hiHat:
            "Hi-Hat"
        }
    }
}

struct MacMetronomeConfig {
    var bpm = 120
    var beatsPerBar = 4
    var beatUnit = 4
    var subdivision:
        MacMetronomeSubdivision =
        .quarter
    var accents:
        [MacBeatAccent] =
        [
            .accent,
            .normal,
            .normal,
            .normal
        ]
    var clickSound:
        MacClickSound =
        .digital
    var countInBars = 0
}

struct MacBeatEvent {
    let beatInBar: Int
    let subdivisionIndex: Int
    let isCountIn: Bool
    let accent:
        MacBeatAccent

    var isMainBeat: Bool {
        subdivisionIndex == 0
    }
}

final class MacMetronomeEngine {

    private let queue =
        DispatchQueue(
            label:
                "dev.mirinnano.guitartools.mac.metronome",
            qos: .userInteractive
        )

    private let engine =
        AVAudioEngine()

    private let player =
        AVAudioPlayerNode()

    private var generation = 0
    private var running = false
    private var beatInBar = 0
    private var subdivisionIndex = 0
    private var countInPulses = 0

    private let sampleRate =
        48_000.0

    init() {
        engine.attach(player)

        let format =
            AVAudioFormat(
                standardFormatWithSampleRate:
                    sampleRate,
                channels: 1
            )!

        engine.connect(
            player,
            to:
                engine.mainMixerNode,
            format: format
        )
    }

    func start(
        startingBeat: Int = 0,
        configProvider:
            @escaping () ->
            MacMetronomeConfig,
        onBeat:
            @escaping (
                MacBeatEvent
            ) -> Void,
        onError:
            @escaping (
                Error
            ) -> Void = { _ in }
    ) {
        guard !running else {
            return
        }

        let initial =
            configProvider()

        running = true
        beatInBar =
            max(
                startingBeat,
                0
            ) %
            max(
                initial.beatsPerBar,
                1
            )
        subdivisionIndex = 0
        countInPulses =
            initial.countInBars *
            initial.beatsPerBar *
            initial.subdivision
                .rawValue

        generation += 1
        let token = generation

        do {
            if !engine.isRunning {
                try engine.start()
            }
            player.play()
        } catch {
            running = false
            onError(error)
            return
        }

        queue.async {
            [weak self] in

            self?.schedulePulse(
                token: token,
                configProvider:
                    configProvider,
                onBeat: onBeat
            )
        }
    }

    func stop() {
        running = false
        generation += 1
        player.stop()
    }

    private func schedulePulse(
        token: Int,
        configProvider:
            @escaping () ->
            MacMetronomeConfig,
        onBeat:
            @escaping (
                MacBeatEvent
            ) -> Void
    ) {
        guard
            running,
            token == generation
        else {
            return
        }

        let config =
            configProvider()

        if beatInBar >=
            config.beatsPerBar {
            beatInBar = 0
        }

        if subdivisionIndex >=
            config.subdivision.rawValue {
            subdivisionIndex = 0
        }

        let main =
            subdivisionIndex == 0

        let countIn =
            countInPulses > 0

        let beatAccent =
            config.accents.indices
                .contains(beatInBar)
            ? config.accents[
                beatInBar
            ]
            : (
                beatInBar == 0
                ? .accent
                : .normal
            )

        let effective:
            MacBeatAccent

        if countIn {
            effective =
                beatInBar == 0 &&
                main
                ? .accent
                : .normal
        } else if main {
            effective =
                beatAccent
        } else {
            effective =
                .normal
        }

        let event =
            MacBeatEvent(
                beatInBar:
                    beatInBar,
                subdivisionIndex:
                    subdivisionIndex,
                isCountIn:
                    countIn,
                accent:
                    effective
            )

        DispatchQueue.main.async {
            onBeat(event)
        }

        if effective != .mute {
            let buffer =
                clickBuffer(
                    sound:
                        config
                            .clickSound,
                    accent:
                        effective,
                    isSubdivision:
                        !main
                )

            player.scheduleBuffer(
                buffer
            )
        }

        if countInPulses > 0 {
            countInPulses -= 1
        }

        subdivisionIndex += 1

        if subdivisionIndex >=
            config.subdivision
                .rawValue {
            subdivisionIndex = 0
            beatInBar =
                (
                    beatInBar + 1
                ) %
                max(
                    config.beatsPerBar,
                    1
                )
        }

        let interval =
            60.0 /
            Double(
                max(
                    config.bpm,
                    1
                )
            ) /
            Double(
                config
                    .subdivision
                    .rawValue
            )

        queue.asyncAfter(
            deadline:
                .now() +
                interval
        ) {
            [weak self] in

            self?.schedulePulse(
                token: token,
                configProvider:
                    configProvider,
                onBeat: onBeat
            )
        }
    }

    private func clickBuffer(
        sound: MacClickSound,
        accent: MacBeatAccent,
        isSubdivision: Bool
    ) -> AVAudioPCMBuffer {
        let length =
            sound == .hiHat
            ? 0.055
            : 0.035

        let frames =
            AVAudioFrameCount(
                sampleRate *
                length
            )

        let format =
            AVAudioFormat(
                standardFormatWithSampleRate:
                    sampleRate,
                channels: 1
            )!

        let buffer =
            AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity:
                    frames
            )!

        buffer.frameLength =
            frames

        let samples =
            buffer
                .floatChannelData![0]

        let amplitude:
            Double =
            isSubdivision
            ? 0.24
            : accent == .accent
            ? 0.64
            : 0.44

        for index in
            0..<Int(frames) {
            let fade =
                1 -
                Double(index) /
                Double(
                    max(
                        Int(frames),
                        1
                    )
                )

            let value:
                Double

            switch sound {
            case .digital:
                let hz =
                    accent == .accent &&
                    !isSubdivision
                    ? 1_800.0
                    : 1_200.0

                value =
                    sin(
                        2 *
                        .pi *
                        hz *
                        Double(index) /
                        sampleRate
                    )

            case .wood:
                value =
                    sin(
                        2 *
                        .pi *
                        760 *
                        Double(index) /
                        sampleRate
                    ) *
                    0.72 +
                    sin(
                        2 *
                        .pi *
                        1_320 *
                        Double(index) /
                        sampleRate
                    ) *
                    0.28

            case .hiHat:
                let x =
                    sin(
                        Double(index) *
                        12.9898
                    ) *
                    43_758.5453

                value =
                    (
                        x -
                        floor(x)
                    ) *
                    2 -
                    1
            }

            samples[index] =
                Float(
                    value *
                    fade *
                    amplitude
                )
        }

        return buffer
    }
}

@MainActor
final class MetronomeModel:
    ObservableObject {

    private let preferencesStore:
        AppPreferencesStore

    private let clock:
        any AudioHostClock

    @Published
    var bpm = 120 {
        didSet {
            persistPreferences()
        }
    }

    @Published
    var beatsPerBar = 4 {
        didSet {
            persistPreferences()
        }
    }

    @Published
    var beatUnit = 4 {
        didSet {
            persistPreferences()
        }
    }

    @Published
    var subdivision:
        MacMetronomeSubdivision =
        .quarter {
        didSet {
            persistPreferences()
        }
    }

    @Published
    var accents:
        [MacBeatAccent] =
        [
            .accent,
            .normal,
            .normal,
            .normal
        ] {
        didSet {
            persistPreferences()
        }
    }

    @Published
    var clickSound:
        MacClickSound =
        .digital {
        didSet {
            persistPreferences()
        }
    }

    @Published
    var countInBars = 0 {
        didSet {
            persistPreferences()
        }
    }

    @Published private(set)
    var currentBeat:
        Int?

    @Published private(set)
    var currentSubdivision = 0

    @Published private(set)
    var isCountIn = false

    @Published private(set)
    var isPlaying = false

    @Published
    var speedTrainerEnabled =
        false {
        didSet {
            persistPreferences()
        }
    }

    @Published
    var speedStartBpm = 60 {
        didSet {
            persistPreferences()
        }
    }

    @Published
    var speedEndBpm = 120 {
        didSet {
            persistPreferences()
        }
    }

    @Published
    var speedStepBpm = 5 {
        didSet {
            persistPreferences()
        }
    }

    @Published
    var speedBarsPerStep = 4 {
        didSet {
            persistPreferences()
        }
    }

    @Published private(set)
    var speedCompletedBars = 0

    private let engine =
        MacMetronomeEngine()

    private var tapTempo =
        TapTempoCalculator()

    init(
        preferencesStore:
            AppPreferencesStore,
        clock:
            any AudioHostClock =
            SystemAudioHostClock()
    ) {
        self.preferencesStore =
            preferencesStore
        self.clock = clock

        let saved =
            preferencesStore
                .value
                .metronome

        bpm = saved.bpm
        beatsPerBar =
            saved.beatsPerBar
        beatUnit =
            saved.beatUnit
        subdivision =
            MacMetronomeSubdivision(
                rawValue:
                    saved
                        .subdivisionRawValue
            )
            ?? .quarter

        let restoredAccents =
            saved.accentRawValues
                .compactMap {
                    MacBeatAccent(
                        rawValue: $0
                    )
                }

        accents =
            restoredAccents.isEmpty
            ? [
                .accent,
                .normal,
                .normal,
                .normal
            ]
            : restoredAccents

        clickSound =
            MacClickSound(
                rawValue:
                    saved
                        .clickSoundRawValue
            )
            ?? .digital

        countInBars =
            saved.countInBars
        speedTrainerEnabled =
            saved
                .speedTrainerEnabled
        speedStartBpm =
            saved.speedStartBPM
        speedEndBpm =
            saved.speedEndBPM
        speedStepBpm =
            saved.speedStepBPM
        speedBarsPerStep =
            saved.speedBarsPerStep

        setTimeSignature(
            beats: beatsPerBar,
            unit: beatUnit
        )
    }

    func changeBpm(
        _ delta: Int
    ) {
        tapTempo.reset()
        bpm =
            min(
                max(
                    bpm + delta,
                    30
                ),
                300
            )
    }

    func registerTap() {
        if let tempo =
            tapTempo.tap(
                timestampSeconds:
                    clock.nowSeconds()
            ) {
            bpm = tempo
        }
    }

    func setTimeSignature(
        beats: Int,
        unit: Int
    ) {
        let safe =
            min(
                max(beats, 1),
                12
            )

        beatsPerBar = safe
        beatUnit = unit

        if accents.count <
            safe {
            accents +=
                Array(
                    repeating:
                        .normal,
                    count:
                        safe -
                        accents.count
                )
        } else if
            accents.count >
            safe {
            accents =
                Array(
                    accents.prefix(
                        safe
                    )
                )
        }

        if !accents.isEmpty,
           accents[0] ==
            .normal {
            accents[0] =
                .accent
        }
    }

    func cycleAccent(
        _ index: Int
    ) {
        guard
            accents.indices
                .contains(index)
        else {
            return
        }

        switch accents[index] {
        case .accent:
            accents[index] =
                .normal
        case .normal:
            accents[index] =
                .mute
        case .mute:
            accents[index] =
                .accent
        }
    }

    func toggle() {
        isPlaying
        ? stop()
        : start()
    }

    func start() {
        guard !isPlaying else {
            return
        }

        if speedTrainerEnabled {
            bpm = speedStartBpm
        }

        speedCompletedBars = 0
        currentBeat = nil
        currentSubdivision = 0
        isCountIn =
            countInBars > 0
        isPlaying = true

        engine.start(
            configProvider: {
                [weak self] in

                guard let self
                else {
                    return MacMetronomeConfig()
                }

                return MacMetronomeConfig(
                    bpm: self.bpm,
                    beatsPerBar:
                        self.beatsPerBar,
                    beatUnit:
                        self.beatUnit,
                    subdivision:
                        self.subdivision,
                    accents:
                        self.accents,
                    clickSound:
                        self.clickSound,
                    countInBars:
                        self.countInBars
                )
            },
            onBeat: {
                [weak self]
                event in

                self?.onBeat(event)
            }
        )
    }

    func stop() {
        engine.stop()
        isPlaying = false
        currentBeat = nil
        currentSubdivision = 0
        isCountIn = false
    }

    private func onBeat(
        _ event:
            MacBeatEvent
    ) {
        currentBeat =
            event.beatInBar
        currentSubdivision =
            event.subdivisionIndex
        isCountIn =
            event.isCountIn

        guard
            speedTrainerEnabled,
            !event.isCountIn,
            event.isMainBeat,
            event.beatInBar ==
                beatsPerBar - 1
        else {
            return
        }

        let completed =
            speedCompletedBars + 1

        if completed >=
            speedBarsPerStep,
           bpm <
            speedEndBpm {
            bpm =
                min(
                    bpm +
                    speedStepBpm,
                    speedEndBpm
                )
            speedCompletedBars = 0
        } else {
            speedCompletedBars =
                completed
        }
    }

    private func persistPreferences() {
        preferencesStore
            .update {
                value in

                value.metronome =
                    MetronomePreferences(
                        bpm: self.bpm,
                        beatsPerBar:
                            self.beatsPerBar,
                        beatUnit:
                            self.beatUnit,
                        subdivisionRawValue:
                            self.subdivision
                                .rawValue,
                        accentRawValues:
                            self.accents
                                .map(
                                    \.rawValue
                                ),
                        clickSoundRawValue:
                            self.clickSound
                                .rawValue,
                        countInBars:
                            self.countInBars,
                        speedTrainerEnabled:
                            self
                                .speedTrainerEnabled,
                        speedStartBPM:
                            self.speedStartBpm,
                        speedEndBPM:
                            self.speedEndBpm,
                        speedStepBPM:
                            self.speedStepBpm,
                        speedBarsPerStep:
                            self.speedBarsPerStep
                    )
            }
    }
}
