import XCTest
@testable import GuitarToolsMacApp

final class PrecisionMetronomeTests:
    XCTestCase {

    func testPulseStateAdvancesBeatAndSubdivision() {
        let config =
            MacMetronomeConfig(
                bpm: 120,
                beatsPerBar: 4,
                beatUnit: 4,
                subdivision:
                    .eighth,
                accents: [
                    .accent,
                    .normal,
                    .normal,
                    .normal
                ],
                clickSound:
                    .digital,
                countInBars: 0
            )

        var state =
            MacMetronomePulseState(
                startingBeat: 0,
                config: config
            )

        let first =
            state.nextEvent(
                config: config
            )

        let second =
            state.nextEvent(
                config: config
            )

        let third =
            state.nextEvent(
                config: config
            )

        XCTAssertEqual(
            first.beatInBar,
            0
        )

        XCTAssertEqual(
            first.subdivisionIndex,
            0
        )

        XCTAssertTrue(
            first.isMainBeat
        )

        XCTAssertEqual(
            second.beatInBar,
            0
        )

        XCTAssertEqual(
            second.subdivisionIndex,
            1
        )

        XCTAssertFalse(
            second.isMainBeat
        )

        XCTAssertEqual(
            third.beatInBar,
            1
        )

        XCTAssertEqual(
            third.subdivisionIndex,
            0
        )
    }

    func testCountInOverridesUserMutePattern() {
        let config =
            MacMetronomeConfig(
                bpm: 100,
                beatsPerBar: 2,
                beatUnit: 4,
                subdivision:
                    .quarter,
                accents: [
                    .mute,
                    .mute
                ],
                clickSound:
                    .wood,
                countInBars: 1
            )

        var state =
            MacMetronomePulseState(
                startingBeat: 0,
                config: config
            )

        let countInDownbeat =
            state.nextEvent(
                config: config
            )

        let countInSecond =
            state.nextEvent(
                config: config
            )

        let firstRealBeat =
            state.nextEvent(
                config: config
            )

        XCTAssertTrue(
            countInDownbeat
                .isCountIn
        )

        XCTAssertEqual(
            countInDownbeat
                .accent,
            .accent
        )

        XCTAssertTrue(
            countInSecond
                .isCountIn
        )

        XCTAssertEqual(
            countInSecond
                .accent,
            .normal
        )

        XCTAssertFalse(
            firstRealBeat
                .isCountIn
        )

        XCTAssertEqual(
            firstRealBeat
                .accent,
            .mute
        )
    }

    func testPulseIntervalsAreTempoAndSubdivisionDerived() {
        let quarter =
            MacMetronomeConfig(
                bpm: 120,
                subdivision:
                    .quarter
            )

        let sixteenth =
            MacMetronomeConfig(
                bpm: 120,
                subdivision:
                    .sixteenth
            )

        XCTAssertEqual(
            MacMetronomePulseState
                .intervalSeconds(
                    config:
                        quarter
                ),
            0.5,
            accuracy: 0.000_001
        )

        XCTAssertEqual(
            MacMetronomePulseState
                .intervalSeconds(
                    config:
                        sixteenth
                ),
            0.125,
            accuracy: 0.000_001
        )
    }

    func testStartingBeatWrapsIntoMeter() {
        let config =
            MacMetronomeConfig(
                beatsPerBar: 4
            )

        var state =
            MacMetronomePulseState(
                startingBeat: 6,
                config: config
            )

        let event =
            state.nextEvent(
                config: config
            )

        XCTAssertEqual(
            event.beatInBar,
            2
        )
    }
}
