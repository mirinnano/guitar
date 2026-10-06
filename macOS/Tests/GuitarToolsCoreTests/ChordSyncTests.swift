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
