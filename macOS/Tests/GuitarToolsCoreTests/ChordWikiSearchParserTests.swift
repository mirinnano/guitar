import XCTest
@testable import GuitarToolsMacApp

final class ChordWikiSearchParserTests: XCTestCase {

    func testParsesChordWikiSearchResultURLs() {
        let values = ChordWikiSearchParser.parse(
            resultURLs: [
                "https://ja.chordwiki.org/wiki/Little+Busters%21",
                "https://ja.chordwiki.org/wiki.cgi?c=view&t=Song+Two&key=0"
            ]
        )

        XCTAssertEqual(
            values.map(\.title),
            ["Little Busters!", "Song Two"]
        )
        XCTAssertEqual(
            values.map(\.url.absoluteString),
            [
                "https://ja.chordwiki.org/wiki/Little%20Busters!",
                "https://ja.chordwiki.org/wiki/Song%20Two"
            ]
        )
    }

    func testRejectsNonChordWikiAndUtilityURLs() {
        let values = ChordWikiSearchParser.parse(
            resultURLs: [
                "https://example.com/wiki/Not-A-Song",
                "https://ja.chordwiki.org/search.html?q=little",
                "https://ja.chordwiki.org/wiki.cgi?c=history&t=Old-Song",
                "https://ja.chordwiki.org/wiki.cgi?c=edit&t=Song"
            ]
        )

        XCTAssertTrue(values.isEmpty)
    }

    func testDeduplicatesAndLimitsSearchResults() {
        let duplicates = ChordWikiSearchParser.parse(
            resultURLs: [
                "https://ja.chordwiki.org/wiki/Test+Song",
                "https://ja.chordwiki.org/wiki.cgi?t=Test+Song"
            ]
        )
        XCTAssertEqual(duplicates.map(\.title), ["Test Song"])

        let urls = (0..<35).map {
            "https://ja.chordwiki.org/wiki/Song+\($0)"
        }
        XCTAssertEqual(
            ChordWikiSearchParser.parse(resultURLs: urls).count,
            30
        )
    }
}
