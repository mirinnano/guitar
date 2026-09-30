import XCTest
@testable import GuitarToolsMacApp

final class ChordWikiSearchParserTests:
    XCTestCase {

    func testParsesWikiCGITitleWithoutViewCommand() {
        let html =
            """
            <html>
              <body>
                <a href="/wiki.cgi?t=Little+Busters%21">
                  <span>表示テキストは曲名と一致しなくてもよい</span>
                </a>
              </body>
            </html>
            """

        let values =
            ChordWikiSearchParser
                .parse(html: html)

        XCTAssertEqual(
            values.count,
            1
        )
        XCTAssertEqual(
            values.first?.title,
            "Little Busters!"
        )
        XCTAssertEqual(
            values.first?
                .url
                .absoluteString,
            "https://ja.chordwiki.org/wiki/Little%20Busters!"
        )
    }

    func testParsesPrettyWikiPath() {
        let html =
            """
            <a href="/wiki/%E5%A4%8F%E5%BD%B1">夏影</a>
            """

        let values =
            ChordWikiSearchParser
                .parse(html: html)

        XCTAssertEqual(
            values.first?.title,
            "夏影"
        )
    }

    func testAcceptsExplicitViewCommand() {
        let html =
            """
            <a href="/wiki.cgi?c=view&amp;t=AIR">AIR</a>
            """

        let values =
            ChordWikiSearchParser
                .parse(html: html)

        XCTAssertEqual(
            values.first?.title,
            "AIR"
        )
    }

    func testRejectsEditSearchAndHistoryLinks() {
        let html =
            """
            <a href="/wiki.cgi?c=edit&amp;t=Song">edit</a>
            <a href="/wiki.cgi?c=search&amp;q=Song">search</a>
            <a href="/wiki.cgi?c=history&amp;t=Song">history</a>
            """

        XCTAssertTrue(
            ChordWikiSearchParser
                .parse(html: html)
                .isEmpty
        )
    }

    func testDeduplicatesSameTitleAcrossLinkForms() {
        let html =
            """
            <a href="/wiki/Test%20Song">one</a>
            <a href="/wiki.cgi?t=Test+Song">two</a>
            """

        let values =
            ChordWikiSearchParser
                .parse(html: html)

        XCTAssertEqual(
            values.count,
            1
        )
        XCTAssertEqual(
            values.first?.title,
            "Test Song"
        )
    }
}
