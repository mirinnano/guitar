import XCTest
@testable import GuitarToolsCore

final class ChordChartTests:
    XCTestCase {

    func testParsesMetadataAndChordPositions() {
        let chart =
            ChordChartParser.parse(
                """
                {title:Test Song}
                {artist:Artist}
                {key:C}
                {tempo:120}
                {time:4/4}
                [C]Hello [G]world |
                """,
                fallbackTitle:
                    "Fallback"
            )

        XCTAssertEqual(
            chart.title,
            "Test Song"
        )
        XCTAssertEqual(
            chart.artist,
            "Artist"
        )
        XCTAssertEqual(
            chart.bpm,
            120
        )
        XCTAssertEqual(
            chart.beatsPerBar,
            4
        )

        let timeline =
            ChordTimelineBuilder
                .build(chart: chart)

        XCTAssertEqual(
            timeline.events.count,
            2
        )
        XCTAssertEqual(
            timeline.events[0]
                .symbol,
            "C"
        )
        XCTAssertEqual(
            timeline.events[0]
                .startBeat,
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            timeline.events[1]
                .symbol,
            "G"
        )
        XCTAssertEqual(
            timeline.events[1]
                .startBeat,
            2,
            accuracy: 0.001
        )
    }

    func testSectionLabelIsNotChord() {
        let chart =
            ChordChartParser.parse(
                """
                [Aメロ]
                [Am]hello
                """,
                fallbackTitle: "Test"
            )

        XCTAssertNil(
            chart.lines[0]
                .segments
                .first?
                .chord
        )

        XCTAssertEqual(
            chart.lines[0]
                .segments
                .first?
                .text,
            "[Aメロ]"
        )
    }
}
