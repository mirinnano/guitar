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

struct MacMetronomePulseState {
    var beatInBar: Int
    var subdivisionIndex: Int
    var countInPulses: Int

    init(
        startingBeat: Int,
        config:
            MacMetronomeConfig
    ) {
        beatInBar =
            max(
                startingBeat,
                0
            ) %
            max(
                config.beatsPerBar,
                1
            )

        subdivisionIndex = 0

        countInPulses =
            max(
                config.countInBars,
                0
            ) *
            max(
                config.beatsPerBar,
                1
            ) *
            max(
                config.subdivision
                    .rawValue,
                1
            )
    }

    mutating func nextEvent(
        config:
            MacMetronomeConfig
    ) -> MacBeatEvent {
        let beatsPerBar =
            max(
                config.beatsPerBar,
                1
            )

        let subdivisions =
            max(
                config.subdivision
                    .rawValue,
                1
            )

        if beatInBar >=
            beatsPerBar {
            beatInBar = 0
        }

        if subdivisionIndex >=
            subdivisions {
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

        if countInPulses > 0 {
            countInPulses -= 1
        }

        subdivisionIndex += 1

        if subdivisionIndex >=
            subdivisions {
            subdivisionIndex = 0
            beatInBar =
                (
                    beatInBar + 1
                ) %
                beatsPerBar
        }

        return event
    }

    static func intervalSeconds(
        config:
            MacMetronomeConfig
    ) -> Double {
        60.0 /
        Double(
            max(
                config.bpm,
                1
            )
        ) /
        Double(
            max(
                config.subdivision
                    .rawValue,
                1
            )
        )
    }
}

final class MacMetronomeEngine {

    private let schedulerQueue =
        DispatchQueue(
            label:
                "dev.mirinnano.guitartools.mac.metronome.scheduler",
            qos: .userInteractive
        )

    private let stateLock =
        NSLock()

    private let engine =
        AVAudioEngine()

    private let player =
        AVAudioPlayerNode()

    private let clock:
        any AudioHostClock

    private let sampleRate =
        48_000.0

    private let lookaheadSeconds =
        0.12

    private let schedulerInterval =
        0.02

    private let startupLeadSeconds =
        0.06

    private var scheduler:
        DispatchSourceTimer?

    private var running = false
    private var generation = 0

    private var pulseState =
        MacMetronomePulseState(
            startingBeat: 0,
            config:
                MacMetronomeConfig()
        )

    private var nextPulseHostSeconds =
        0.0

    private var configProvider:
        (() -> MacMetronomeConfig)?

    private var onBeat:
        ((MacBeatEvent) -> Void)?

    private var clickBuffers:
        [String: AVAudioPCMBuffer] =
        [:]

    init(
        clock:
            any AudioHostClock =
            SystemAudioHostClock()
    ) {
        self.clock = clock

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
        let initial =
            configProvider()

        let token:
            Int

        stateLock.lock()

        guard !running
        else {
            stateLock.unlock()
            return
        }

        running = true
        generation += 1
        token = generation
        self.configProvider =
            configProvider
        self.onBeat = onBeat

        pulseState =
            MacMetronomePulseState(
                startingBeat:
                    startingBeat,
                config: initial
            )

        nextPulseHostSeconds =
            clock.nowSeconds() +
            startupLeadSeconds

        stateLock.unlock()

        do {
            if !engine.isRunning {
                try engine.start()
            }

            player.prepare(
                withFrameCount:
                    AVAudioFrameCount(
                        sampleRate *
                        0.06
                    )
            )

            player.play()

            installScheduler(
                token: token
            )
        } catch {
            stateLock.lock()
            running = false
            generation += 1
            self.configProvider = nil
            self.onBeat = nil
            stateLock.unlock()

            onError(error)
        }
    }

    func stop() {
        let timer:
            DispatchSourceTimer?

        stateLock.lock()
        running = false
        generation += 1
        timer = scheduler
        scheduler = nil
        configProvider = nil
        onBeat = nil
        stateLock.unlock()

        timer?.cancel()
        player.stop()
    }

    private func installScheduler(
        token: Int
    ) {
        let timer =
            DispatchSource.makeTimerSource(
                queue:
                    schedulerQueue
            )

        timer.schedule(
            deadline: .now(),
            repeating:
                schedulerInterval,
            leeway:
                .milliseconds(2)
        )

        timer.setEventHandler {
            [weak self] in

            self?.fillLookahead(
                token: token
            )
        }

        stateLock.lock()

        if
            running,
            generation == token {
            scheduler?.cancel()
            scheduler = timer
            stateLock.unlock()
            timer.resume()
        } else {
            stateLock.unlock()
            timer.cancel()
        }
    }

    private func fillLookahead(
        token: Int
    ) {
        while true {
            let snapshot =
                nextSchedulingSnapshot(
                    token: token
                )

            guard let snapshot
            else {
                return
            }

            let now =
                clock.nowSeconds()

            guard
                snapshot.eventTime <=
                    now +
                    lookaheadSeconds
            else {
                return
            }

            let config =
                currentConfig(
                    provider:
                        snapshot.provider
                )

            let scheduled =
                advancePulse(
                    token: token,
                    config: config
                )

            guard let scheduled
            else {
                return
            }

            schedule(
                scheduled.event,
                at:
                    scheduled.eventTime,
                config: config,
                token: token
            )
        }
    }

    private func nextSchedulingSnapshot(
        token: Int
    ) -> (
        eventTime: Double,
        provider:
            () -> MacMetronomeConfig
    )? {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }

        guard
            running,
            generation == token,
            let configProvider
        else {
            return nil
        }

        return (
            nextPulseHostSeconds,
            configProvider
        )
    }

    private func currentConfig(
        provider:
            @escaping () ->
            MacMetronomeConfig
    ) -> MacMetronomeConfig {
        if Thread.isMainThread {
            return provider()
        }

        return DispatchQueue
            .main
            .sync {
                provider()
            }
    }

    private func advancePulse(
        token: Int,
        config:
            MacMetronomeConfig
    ) -> (
        event:
            MacBeatEvent,
        eventTime:
            Double
    )? {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }

        guard
            running,
            generation == token
        else {
            return nil
        }

        let eventTime =
            nextPulseHostSeconds

        let event =
            pulseState.nextEvent(
                config: config
            )

        nextPulseHostSeconds +=
            MacMetronomePulseState
                .intervalSeconds(
                    config: config
                )

        return (
            event,
            eventTime
        )
    }

    private func schedule(
        _ event:
            MacBeatEvent,
        at eventTime:
            Double,
        config:
            MacMetronomeConfig,
        token: Int
    ) {
        if event.accent != .mute {
            let buffer =
                clickBuffer(
                    sound:
                        config
                            .clickSound,
                    accent:
                        event.accent,
                    isSubdivision:
                        !event
                            .isMainBeat
                )

            let hostTime =
                clock.hostTime(
                    forSeconds:
                        eventTime
                )

            player.scheduleBuffer(
                buffer,
                at:
                    AVAudioTime(
                        hostTime:
                            hostTime
                    ),
                options: []
            )
        }

        let delay =
            max(
                eventTime -
                clock.nowSeconds(),
                0
            )

        DispatchQueue.main
            .asyncAfter(
                deadline:
                    .now() +
                    delay
            ) {
                [weak self] in

                guard
                    let self,
                    self.isActive(
                        token: token
                    )
                else {
                    return
                }

                self.onBeat?(
                    event
                )
            }
    }

    private func isActive(
        token: Int
    ) -> Bool {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }

        return running &&
            generation == token
    }

    private func clickBuffer(
        sound:
            MacClickSound,
        accent:
            MacBeatAccent,
        isSubdivision:
            Bool
    ) -> AVAudioPCMBuffer {
        let key =
            sound.rawValue +
            ":" +
            String(accent.rawValue) +
            ":" +
            String(isSubdivision)

        if let cached =
            clickBuffers[key] {
            return cached
        }

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

        clickBuffers[key] =
            buffer

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
