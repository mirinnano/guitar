import XCTest
@testable import GuitarToolsCore
@testable import GuitarToolsMacApp

final class FoundationPersistenceTests:
    XCTestCase {

    @MainActor
    func testPreferencesRoundTripAndSanitize() {
        let suite =
            "FoundationPersistenceTests." +
            UUID().uuidString

        let defaults =
            UserDefaults(
                suiteName: suite
            )!

        defer {
            defaults
                .removePersistentDomain(
                    forName: suite
                )
        }

        let store =
            AppPreferencesStore(
                defaults: defaults
            )

        store.update {
            value in

            value.audio
                .selectedChannel = 3
            value.audio
                .inputLatencyCompensationMs =
                72
            value.tuner.a4Hz =
                442
            value.metronome.bpm =
                156
            value.practice
                .onTimeToleranceMs =
                65
        }

        let reloaded =
            AppPreferencesStore(
                defaults: defaults
            )

        XCTAssertEqual(
            reloaded.value
                .audio
                .selectedChannel,
            3
        )

        XCTAssertEqual(
            reloaded.value
                .audio
                .inputLatencyCompensationMs,
            72
        )

        XCTAssertEqual(
            reloaded.value
                .tuner
                .a4Hz,
            442
        )

        XCTAssertEqual(
            reloaded.value
                .metronome
                .bpm,
            156
        )

        XCTAssertEqual(
            reloaded.value
                .practice
                .onTimeToleranceMs,
            65
        )
    }

    func testPracticeSessionCodableRoundTrip()
        throws {
        let attempt =
            PracticeAttempt(
                eventID: 4,
                expectedChord:
                    "Cmaj7",
                playedChord: "C",
                timingErrorMs: 31,
                harmony:
                    .incorrect,
                timing:
                    .onTime
            )

        let start =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let session =
            PracticeSession(
                startedAt: start,
                endedAt:
                    start.addingTimeInterval(
                        60
                    ),
                title: "Test Song",
                artist: "Artist",
                sourceIdentifier:
                    "chordwiki:test",
                bpm: 120,
                beatsPerBar: 4,
                onTimeToleranceMs: 90,
                inputLatencyCompensationMs:
                    18,
                attempts: [attempt]
            )

        let encoded =
            try JSONEncoder()
                .encode(session)

        let decoded =
            try JSONDecoder()
                .decode(
                    PracticeSession.self,
                    from: encoded
                )

        XCTAssertEqual(
            decoded,
            session
        )

        XCTAssertEqual(
            decoded.statistics
                .totalAttempts,
            1
        )

        XCTAssertEqual(
            decoded.durationSeconds,
            60,
            accuracy: 0.001
        )
    }

    func testPracticeSessionStoreRoundTrip()
        async throws {
        let directory =
            FileManager
                .default
                .temporaryDirectory
                .appendingPathComponent(
                    UUID().uuidString,
                    isDirectory: true
                )

        defer {
            try? FileManager
                .default
                .removeItem(
                    at: directory
                )
        }

        let store =
            PracticeSessionStore(
                directoryURL:
                    directory
            )

        let now = Date()

        let older =
            PracticeSession(
                startedAt:
                    now.addingTimeInterval(
                        -120
                    ),
                endedAt:
                    now.addingTimeInterval(
                        -60
                    ),
                title: "Older",
                bpm: 80,
                beatsPerBar: 4,
                onTimeToleranceMs: 90,
                inputLatencyCompensationMs:
                    0,
                attempts: []
            )

        let newer =
            PracticeSession(
                startedAt:
                    now.addingTimeInterval(
                        -30
                    ),
                endedAt: now,
                title: "Newer",
                bpm: 120,
                beatsPerBar: 4,
                onTimeToleranceMs: 90,
                inputLatencyCompensationMs:
                    0,
                attempts: []
            )

        try await store.save(
            older
        )

        try await store.save(
            newer
        )

        let values =
            try await store.loadAll()

        XCTAssertEqual(
            values.map(\.title),
            [
                "Newer",
                "Older"
            ]
        )

        try await store.remove(
            id: newer.id
        )

        let remaining =
            try await store.loadAll()

        XCTAssertEqual(
            remaining.map(\.title),
            ["Older"]
        )
    }
}
