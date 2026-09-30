import Foundation

public struct PracticeSession:
    Codable,
    Identifiable,
    Sendable,
    Equatable {

    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let title: String
    public let artist: String
    public let sourceIdentifier: String?
    public let bpm: Int
    public let beatsPerBar: Int
    public let onTimeToleranceMs: Double
    public let inputLatencyCompensationMs: Double
    public let attempts: [PracticeAttempt]

    public init(
        schemaVersion: Int =
            PracticeSession
                .currentSchemaVersion,
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        title: String,
        artist: String = "",
        sourceIdentifier: String? = nil,
        bpm: Int,
        beatsPerBar: Int,
        onTimeToleranceMs: Double,
        inputLatencyCompensationMs: Double,
        attempts: [PracticeAttempt]
    ) {
        self.schemaVersion =
            schemaVersion
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.title = title
        self.artist = artist
        self.sourceIdentifier =
            sourceIdentifier
        self.bpm = bpm
        self.beatsPerBar =
            beatsPerBar
        self.onTimeToleranceMs =
            onTimeToleranceMs
        self.inputLatencyCompensationMs =
            inputLatencyCompensationMs
        self.attempts = attempts
    }

    public var statistics:
        PracticeStatistics {
        ChordFollowEvaluator
            .statistics(
                attempts:
                    attempts
            )
    }

    public var durationSeconds:
        Double {
        max(
            endedAt.timeIntervalSince(
                startedAt
            ),
            0
        )
    }
}
