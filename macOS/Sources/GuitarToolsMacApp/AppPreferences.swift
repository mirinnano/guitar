import Combine
import Foundation

struct AppPreferences:
    Codable,
    Equatable,
    Sendable {

    static let currentSchemaVersion = 1

    var schemaVersion =
        currentSchemaVersion

    var audio =
        AudioPreferences()

    var tuner =
        TunerPreferences()

    var metronome =
        MetronomePreferences()

    var practice =
        PracticePreferences()
}

struct AudioPreferences:
    Codable,
    Equatable,
    Sendable {

    var inputDeviceUID:
        String?

    // Optional so pre-output-selection JSON continues to decode unchanged.
    var outputDeviceUID:
        String?

    var selectedChannel = 0

    var inputLatencyCompensationMs =
        0.0
}

struct TunerPreferences:
    Codable,
    Equatable,
    Sendable {

    var a4Hz = 440.0
    var tuningID = "standard"
    var sensitivity = 0.6

    var customStringMIDI:
        [Int: Int] = [:]
}

struct MetronomePreferences:
    Codable,
    Equatable,
    Sendable {

    var bpm = 120
    var beatsPerBar = 4
    var beatUnit = 4
    var subdivisionRawValue = 1

    var accentRawValues =
        [
            0,
            1,
            1,
            1
        ]

    var clickSoundRawValue =
        "digital"

    var countInBars = 0

    var speedTrainerEnabled =
        false

    var speedStartBPM = 60
    var speedEndBPM = 120
    var speedStepBPM = 5
    var speedBarsPerStep = 4
}

struct PracticePreferences:
    Codable,
    Equatable,
    Sendable {

    var onTimeToleranceMs =
        90.0

    var autoScroll = true
}

@MainActor
final class AppPreferencesStore:
    ObservableObject {

    static let storageKey =
        "dev.mirinnano.guitartools.preferences.v1"

    @Published private(set)
    var value: AppPreferences

    private let defaults:
        UserDefaults

    init(
        defaults:
            UserDefaults = .standard
    ) {
        self.defaults = defaults
        value =
            Self.load(
                defaults: defaults
            )
    }

    func update(
        _ mutate:
            (inout AppPreferences)
                -> Void
    ) {
        var copy = value
        mutate(&copy)

        guard copy != value
        else {
            return
        }

        value = copy
        save()
    }

    func reset() {
        value =
            AppPreferences()

        defaults.removeObject(
            forKey:
                Self.storageKey
        )
    }

    private func save() {
        guard
            let data =
                try? JSONEncoder()
                    .encode(value)
        else {
            return
        }

        defaults.set(
            data,
            forKey:
                Self.storageKey
        )
    }

    private static func load(
        defaults: UserDefaults
    ) -> AppPreferences {
        guard
            let data =
                defaults.data(
                    forKey:
                        storageKey
                ),
            let decoded =
                try? JSONDecoder()
                    .decode(
                        AppPreferences.self,
                        from: data
                    ),
            decoded.schemaVersion <=
                AppPreferences
                    .currentSchemaVersion
        else {
            return AppPreferences()
        }

        return sanitized(
            decoded
        )
    }

    private static func sanitized(
        _ input:
            AppPreferences
    ) -> AppPreferences {
        var result = input

        // Bound corrupt preferences, not the currently connected device: a
        // saved UR12 Ch 2 must survive unplugging or a mono default input.
        result.audio.selectedChannel = min(max(result.audio.selectedChannel, 0), 63)

        result.audio
            .inputLatencyCompensationMs =
            min(
                max(
                    result.audio
                        .inputLatencyCompensationMs,
                    -250
                ),
                500
            )

        result.tuner.a4Hz =
            min(
                max(
                    result.tuner.a4Hz,
                    400
                ),
                480
            )

        result.tuner.sensitivity =
            min(
                max(
                    result.tuner.sensitivity,
                    0
                ),
                1
            )

        result.metronome.bpm =
            min(
                max(
                    result.metronome.bpm,
                    30
                ),
                300
            )

        result.metronome
            .beatsPerBar =
            min(
                max(
                    result.metronome
                        .beatsPerBar,
                    1
                ),
                12
            )

        if ![2, 4, 8, 16]
            .contains(
                result.metronome
                    .beatUnit
            ) {
            result.metronome
                .beatUnit = 4
        }

        result.practice
            .onTimeToleranceMs =
            min(
                max(
                    result.practice
                        .onTimeToleranceMs,
                    20
                ),
                400
            )

        return result
    }
}
