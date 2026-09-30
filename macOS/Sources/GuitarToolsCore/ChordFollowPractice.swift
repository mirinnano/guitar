import Foundation

public enum HarmonyResult:
    String,
    Codable,
    Sendable,
    Equatable {

    case correct
    case incorrect
    case unrecognized
}

public enum TimingResult:
    String,
    Codable,
    Sendable,
    Equatable {

    case early
    case onTime
    case late
}

public struct PracticeAttempt:
    Codable,
    Sendable,
    Equatable,
    Identifiable {

    public let id: UUID
    public let eventID: Int
    public let expectedChord: String
    public let playedChord: String?
    public let timingErrorMs: Double
    public let harmony:
        HarmonyResult
    public let timing:
        TimingResult

    public init(
        id: UUID = UUID(),
        eventID: Int,
        expectedChord: String,
        playedChord: String?,
        timingErrorMs: Double,
        harmony: HarmonyResult,
        timing: TimingResult
    ) {
        self.id = id
        self.eventID = eventID
        self.expectedChord =
            expectedChord
        self.playedChord =
            playedChord
        self.timingErrorMs =
            timingErrorMs
        self.harmony = harmony
        self.timing = timing
    }
}

public struct PracticeStatistics:
    Codable,
    Sendable,
    Equatable {

    public let totalAttempts: Int
    public let correctChords: Int
    public let onTimeAttempts: Int
    public let meanAbsoluteTimingErrorMs:
        Double

    public var chordAccuracy:
        Double {
        guard totalAttempts > 0 else {
            return 0
        }

        return Double(correctChords) /
            Double(totalAttempts)
    }

    public var timingAccuracy:
        Double {
        guard totalAttempts > 0 else {
            return 0
        }

        return Double(onTimeAttempts) /
            Double(totalAttempts)
    }
}

public enum ChordSymbolNormalizer {

    public static func normalize(
        _ raw: String
    ) -> String? {
        var text =
            raw
                .trimmingCharacters(
                    in: .whitespaces
                )
                .replacingOccurrences(
                    of: "♯",
                    with: "#"
                )
                .replacingOccurrences(
                    of: "♭",
                    with: "b"
                )

        if text.isEmpty ||
            text.uppercased() ==
                "N.C." ||
            text.uppercased() ==
                "NC" {
            return nil
        }

        if let slash =
            text.firstIndex(of: "/") {
            text =
                String(
                    text[..<slash]
                )
        }

        let pattern =
            #"^([A-Ga-g])([#b]?)(.*)$"#

        guard
            let regex =
                try? NSRegularExpression(
                    pattern: pattern
                )
        else {
            return nil
        }

        let ns =
            text as NSString

        guard
            let match =
                regex.firstMatch(
                    in: text,
                    range: NSRange(
                        location: 0,
                        length: ns.length
                    )
                )
        else {
            return nil
        }

        var root =
            ns.substring(
                with:
                    match.range(at: 1)
            )
            .uppercased()

        let accidental =
            ns.substring(
                with:
                    match.range(at: 2)
            )

        var suffix =
            ns.substring(
                with:
                    match.range(at: 3)
            )
            .lowercased()

        if accidental == "b" {
            root =
                flatToSharp(
                    root
                )
        } else if accidental == "#" {
            root += "#"
        }

        suffix =
            canonicalSuffix(
                suffix
            )

        return root + suffix
    }

    public static func matches(
        expected: String,
        played: String
    ) -> Bool {
        guard
            let lhs =
                normalize(expected),
            let rhs =
                normalize(played)
        else {
            return false
        }

        return lhs == rhs
    }

    private static func flatToSharp(
        _ root: String
    ) -> String {
        switch root {
        case "D": "C#"
        case "E": "D#"
        case "G": "F#"
        case "A": "G#"
        case "B": "A#"
        case "C": "B"
        case "F": "E"
        default: root
        }
    }

    private static func canonicalSuffix(
        _ suffix: String
    ) -> String {
        var value =
            suffix
                .replacingOccurrences(
                    of: "major",
                    with: ""
                )
                .replacingOccurrences(
                    of: "minor",
                    with: "m"
                )
                .replacingOccurrences(
                    of: "min",
                    with: "m"
                )

        if value == "maj" {
            value = ""
        }

        return value
    }
}

public enum ChordFollowEvaluator {

    public static func attempt(
        event: TimedChordEvent,
        playedChord: String?,
        timingErrorMs: Double,
        onTimeToleranceMs:
            Double = 90
    ) -> PracticeAttempt {
        let harmony:
            HarmonyResult

        if let playedChord {
            harmony =
                ChordSymbolNormalizer
                    .matches(
                        expected:
                            event.symbol,
                        played:
                            playedChord
                    )
                ? .correct
                : .incorrect
        } else {
            harmony =
                .unrecognized
        }

        let timing:
            TimingResult

        if timingErrorMs <
            -onTimeToleranceMs {
            timing = .early
        } else if timingErrorMs >
            onTimeToleranceMs {
            timing = .late
        } else {
            timing = .onTime
        }

        return PracticeAttempt(
            eventID: event.id,
            expectedChord:
                event.symbol,
            playedChord:
                playedChord,
            timingErrorMs:
                timingErrorMs,
            harmony:
                harmony,
            timing:
                timing
        )
    }

    public static func statistics(
        attempts:
            [PracticeAttempt]
    ) -> PracticeStatistics {
        let correct =
            attempts.filter {
                $0.harmony == .correct
            }.count

        let onTime =
            attempts.filter {
                $0.timing == .onTime
            }.count

        let mean =
            attempts.isEmpty
            ? 0
            : attempts
                .map {
                    abs(
                        $0.timingErrorMs
                    )
                }
                .reduce(0, +) /
                Double(
                    attempts.count
                )

        return PracticeStatistics(
            totalAttempts:
                attempts.count,
            correctChords:
                correct,
            onTimeAttempts:
                onTime,
            meanAbsoluteTimingErrorMs:
                mean
        )
    }
}
