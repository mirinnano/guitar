import XCTest
@testable import GuitarToolsCore

final class ChordFollowPracticeTests:
    XCTestCase {

    private let event =
        TimedChordEvent(
            id: 1,
            symbol: "Bbmaj7",
            lineIndex: 0,
            segmentIndex: 0,
            startBeat: 4,
            durationBeats: 2
        )

    func testEnharmonicChordMatch() {
        let result =
            ChordFollowEvaluator
                .attempt(
                    event: event,
                    playedChord:
                        "A#maj7",
                    timingErrorMs: 24
                )

        XCTAssertEqual(
            result.harmony,
            .correct
        )
        XCTAssertEqual(
            result.timing,
            .onTime
        )
    }

    func testTimingAndHarmonyAreIndependent() {
        let result =
            ChordFollowEvaluator
                .attempt(
                    event: event,
                    playedChord: "Gm",
                    timingErrorMs: 145
                )

        XCTAssertEqual(
            result.harmony,
            .incorrect
        )
        XCTAssertEqual(
            result.timing,
            .late
        )
    }

    func testStatistics() {
        let attempts = [
            ChordFollowEvaluator
                .attempt(
                    event: event,
                    playedChord:
                        "A#maj7",
                    timingErrorMs: 20
                ),
            ChordFollowEvaluator
                .attempt(
                    event:
                        TimedChordEvent(
                            id: 2,
                            symbol: "C",
                            lineIndex: 1,
                            segmentIndex: 0,
                            startBeat: 8,
                            durationBeats: 2
                        ),
                    playedChord: "Am",
                    timingErrorMs: -120
                )
        ]

        let stats =
            ChordFollowEvaluator
                .statistics(
                    attempts: attempts
                )

        XCTAssertEqual(
            stats.correctChords,
            1
        )
        XCTAssertEqual(
            stats.onTimeAttempts,
            1
        )
        XCTAssertEqual(
            stats.meanAbsoluteTimingErrorMs,
            70,
            accuracy: 0.001
        )
    }
}
