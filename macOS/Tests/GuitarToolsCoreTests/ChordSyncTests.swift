import XCTest
@testable import GuitarToolsCore

final class ChordSyncTests:
    XCTestCase {

    func testTempoMapAppliesWithoutAnchorsAndWithOneOffsetAnchor() {
        let tempo = ChordTempoMap(bpm: 120, changes: [TimedTempoChange(startBeat: 4, bpm: 60)])
        let plain = ChordSyncMap(anchors: [], fallbackBPM: 120, fallbackOffsetMs: 1_000, totalBeats: 12, tempoMap: tempo)
        XCTAssertEqual(plain.videoPositionMs(forBeat: 8), 7_000)
        XCTAssertEqual(plain.beat(forVideoPositionMs: 5_000), 6, accuracy: 0.001)
        XCTAssertEqual(plain.localBPM(atBeat: 5), 60, accuracy: 0.001)
        let anchored = ChordSyncMap(anchors: [anchor(beat: 8, milliseconds: 10_000)], fallbackBPM: 120, fallbackOffsetMs: 0, totalBeats: 12, tempoMap: tempo)
        for beat in stride(from: 0.0, through: 12, by: 0.5) {
            XCTAssertEqual(anchored.beat(forVideoPositionMs: anchored.videoPositionMs(forBeat: beat)), beat, accuracy: 0.001)
        }
        XCTAssertEqual(anchored.videoPositionMs(forBeat: 4), 6_000)
    }

    func testTwoAnchorsWarpTime() {
        let map =
            ChordSyncMap(
                anchors: [
                    anchor(
                        beat: 0,
                        milliseconds:
                            2_000
                    ),
                    anchor(
                        beat: 16,
                        milliseconds:
                            11_600
                    )
                ],
                fallbackBPM: 120,
                fallbackOffsetMs: 0,
                totalBeats: 64
            )

        XCTAssertEqual(
            map.beat(
                forVideoPositionMs:
                    6_800
            ),
            8,
            accuracy: 0.001
        )

        XCTAssertEqual(
            map.videoPositionMs(
                forBeat: 8
            ),
            6_800
        )
    }

    func testPiecewiseLocalBPM() {
        let map =
            ChordSyncMap(
                anchors: [
                    anchor(
                        beat: 0,
                        milliseconds: 0
                    ),
                    anchor(
                        beat: 8,
                        milliseconds:
                            4_000
                    ),
                    anchor(
                        beat: 16,
                        milliseconds:
                            10_000
                    )
                ],
                fallbackBPM: 120,
                fallbackOffsetMs: 0,
                totalBeats: 32
            )

        XCTAssertEqual(
            map.localBPM(
                atBeat: 12
            ),
            80,
            accuracy: 0.01
        )
    }

    func testCloseAnchorsDoNotAmplifyTapErrorAcrossTheSong() {
        // Two taps one beat apart, the second 60 ms late: a whole-song warp would
        // drift by minutes. Outside them the chart tempo continues from the last tap.
        let map = ChordSyncMap(anchors: [anchor(beat: 0, milliseconds: 1_000), anchor(beat: 1, milliseconds: 1_560)],
                               fallbackBPM: 120, fallbackOffsetMs: 0, totalBeats: 400)
        XCTAssertEqual(map.videoPositionMs(forBeat: 401 - 1), 1_560 + 399 * 500)
        XCTAssertEqual(map.beat(forVideoPositionMs: 1_560 + 100 * 500), 101, accuracy: 0.001)
        XCTAssertEqual(map.localBPM(atBeat: 200), 120, accuracy: 0.001)
        XCTAssertEqual(map.beat(forVideoPositionMs: 1_280), 0.5, accuracy: 0.001)
    }

    func testWideAnchorsCorrectTempoBeyondThemAndKeepTempoChanges() {
        let tempo = ChordTempoMap(bpm: 120, changes: [TimedTempoChange(startBeat: 8, bpm: 60)])
        // Video runs 10% slower than the chart everywhere.
        let map = ChordSyncMap(anchors: [anchor(beat: 0, milliseconds: 0), anchor(beat: 16, milliseconds: 13_200)],
                               fallbackBPM: 120, fallbackOffsetMs: 0, totalBeats: 32, tempoMap: tempo)
        XCTAssertEqual(map.videoPositionMs(forBeat: 8), 4_400)
        XCTAssertEqual(map.videoPositionMs(forBeat: 24), 22_000)
        XCTAssertEqual(map.localBPM(atBeat: 4), 120 / 1.1, accuracy: 0.001)
        for beat in stride(from: 0.0, through: 32, by: 0.5) {
            XCTAssertEqual(map.beat(forVideoPositionMs: map.videoPositionMs(forBeat: beat)), beat, accuracy: 0.002)
        }
    }

    func testRejectsCrossingAnchor() {
        let anchors = [
            anchor(
                beat: 4,
                milliseconds:
                    4_000
            ),
            anchor(
                beat: 12,
                milliseconds:
                    8_000
            )
        ]

        XCTAssertFalse(
            ChordSyncMap
                .canInsert(
                    anchors:
                        anchors,
                    candidate:
                        anchor(
                            beat: 8,
                            milliseconds:
                                9_000
                        )
                )
        )
    }

    private func anchor(
        beat: Double,
        milliseconds: Int64
    ) -> ChordSyncAnchor {
        ChordSyncAnchor(
            chartBeat: beat,
            videoPositionMs:
                milliseconds,
            symbol: "C",
            lineIndex: 0,
            segmentIndex: 0
        )
    }
}
