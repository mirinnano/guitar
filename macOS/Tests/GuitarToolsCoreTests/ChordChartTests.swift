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

    func testReadsWikiCommentTempoWithExplicitTempoTakingPriority() {
        let source = "{c:BPM=164　4/4拍子}\n[C]Hello"
        XCTAssertEqual(
            ChordChartParser.parse(source, fallbackTitle: "Song").bpm,
            164
        )
        XCTAssertEqual(
            ChordChartParser.parse(source + "\n{tempo:96}", fallbackTitle: "Song").bpm,
            96
        )
        XCTAssertEqual(
            ChordChartParser.parse("{tempo:96}\n" + source, fallbackTitle: "Song").bpm,
            96
        )
        XCTAssertNil(
            ChordChartParser.parse("{c:BPM=4000}", fallbackTitle: "Song").bpm
        )
    }

    func testExplicitCapoConvertsRootAndSlashBassAfterAllDirectives() {
        let chart = ChordChartParser.parse("""
            {key:C}
            [C]Hello [G/B]world [N.C.]rest
            {capo:2}
            """, fallbackTitle: "Song")
        XCTAssertEqual(chart.sourceCapo, 2)
        XCTAssertEqual(chart.sourceKey, "C")
        XCTAssertEqual(chart.key, "D")
        XCTAssertEqual(chart.lines.flatMap(\.segments).compactMap(\.chord), ["D", "A/C#", "N.C."])
        XCTAssertTrue(chart.unconvertedChordSymbols.isEmpty)
        XCTAssertEqual(ChordTimelineBuilder.build(chart: chart).events.map(\.symbol), ["D", "A/C#", "N.C."])
    }

    func testCapoSuggestionsInCommentsDoNotTransposeConcertPitchChart() {
        let chart = ChordChartParser.parse("""
            {c:簡単コード：移調-1(Capo:1) Play C}
            [Db]Hello [Ab/C]world
            """, fallbackTitle: "Song")
        XCTAssertEqual(chart.sourceCapo, 0)
        XCTAssertEqual(chart.lines.flatMap(\.segments).compactMap(\.chord), ["Db", "Ab/C"])
    }

    func testNumericSixNineIsAChordQualityNotBass() {
        let chart = ChordChartParser.parse("""
            [C6/9]one [Cm6/9]two [C6/9/G]three [Intro]
            {capo:2}
            """, fallbackTitle: "Song")
        XCTAssertEqual(chart.lines.flatMap(\.segments).compactMap(\.chord), ["D6/9", "Dm6/9", "D6/9/A"])
        XCTAssertTrue(chart.lines.flatMap(\.segments).contains { $0.text.contains("[Intro]") })
    }

    func testUnconvertibleCapoSymbolNeverGetsAWrongPitchDiagram() {
        let chart = ChordChartParser.parse("{capo:2}\n[Cm((7)]word", fallbackTitle: "Song")
        XCTAssertEqual(chart.unconvertedChordSymbols, ["Cm((7)"])
        XCTAssertNil(chart.lines[0].segments[0].chord)
        XCTAssertEqual(chart.lines[0].segments[0].text, "[Cm((7)]word")
    }

    func testUnsupportedQualityStillTransposesInsteadOfPlayingOriginalPitch() {
        let chart = ChordChartParser.parse("{capo:2}\n[C7(b9,#11)]word", fallbackTitle: "Song")
        XCTAssertEqual(chart.lines[0].segments[0].chord, "D7(b9,#11)")
        XCTAssertTrue(chart.unconvertedChordSymbols.isEmpty)
    }

    func testUnconvertibleChordKeepsItsSlotWithoutMovingFollowingChords() {
        let chart = ChordChartParser.parse("{capo:2}\n[Cm((7)]one [G]two", fallbackTitle: "Song")
        let timeline = ChordTimelineBuilder.build(chart: chart)
        XCTAssertEqual(timeline.events.map(\.symbol), ["Cm((7)", "A"])
        XCTAssertEqual(timeline.events.map(\.startBeat), [0, 2])
        XCTAssertEqual(timeline.events.map(\.isPlayable), [false, true])
        XCTAssertEqual(timeline.totalBeats, 4)
        XCTAssertNil(chart.lines[0].segments[0].chord)
    }

    func testInvalidCapoDirectiveSuppressesPotentiallyWrongPitchDiagrams() {
        let chart = ChordChartParser.parse("{capo:unknown}\n[C]hello", fallbackTitle: "Song")
        XCTAssertNotNil(chart.capoDirectiveWarning)
        XCTAssertEqual(chart.unconvertedChordSymbols, ["C"])
        XCTAssertNil(chart.lines[0].segments[0].chord)
        let corrected = ChordChartParser.parse("{capo:unknown}\n[C]hello\n{capo:0}", fallbackTitle: "Song")
        XCTAssertNil(corrected.capoDirectiveWarning)
        XCTAssertEqual(corrected.lines[0].segments[0].chord, "C")
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
