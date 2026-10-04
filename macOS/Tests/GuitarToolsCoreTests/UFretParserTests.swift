import Foundation
import XCTest
import GuitarToolsCore
@testable import GuitarToolsMacApp

final class UFretParserTests: XCTestCase {

    func testSearchParsesListTitlesVersionsArtistsAndCanonicalURLs() throws {
        let html = """
            <html><body>
            <h1>検索結果</h1>
            <ul class="c-list">
              <li class="c-list__item extra">
                <a class="c-list__link" href="/song.php?data=4090&amp;sort=popular#top">
                  <p class="c-list__title"> 合成の歌 <span>初心者ver</span> </p>
                  <p class="c-list__artist"> 合成アーティスト </p>
                </a>
              </li>
              <li class='c-list__item'>
                <a href='https://ufret.jp/song.php?data=4091'>
                  <p class='c-list__title'>別の合成曲</p>
                  <p class='c-list__artist'>別の奏者</p>
                </a>
              </li>
            </ul>
            <nav><a href='/song.php?data=9999'>結果外のリンク</a></nav>
            </body></html>
            """

        let results = try UFretSearchParser.parse(html: html)

        XCTAssertEqual(results.map(\.title), ["合成の歌 初心者ver", "別の合成曲"])
        XCTAssertEqual(results.map(\.artist), ["合成アーティスト", "別の奏者"])
        XCTAssertEqual(results.map(\.url.absoluteString), [
            "https://www.ufret.jp/song.php?data=4090",
            "https://www.ufret.jp/song.php?data=4091"
        ])
    }

    func testSearchDecodesNamedAndNumericHTMLEntities() throws {
        let html = "<ul class='c-list'>" + searchItem(
            href: "/song.php?data=4090&amp;unused=1",
            title: "Rock &amp; &quot;合成&quot; &lt;歌&gt; &#x1F3B8;",
            artist: "O&#39;Artist&nbsp;&amp;&nbsp;&#21512;&#25104;"
        ) + "</ul>"

        let result = try XCTUnwrap(UFretSearchParser.parse(html: html).first)

        XCTAssertEqual(result.title, "Rock & \"合成\" <歌> 🎸")
        XCTAssertEqual(result.artist, "O'Artist & 合成")
        XCTAssertEqual(result.url.absoluteString, "https://www.ufret.jp/song.php?data=4090")
    }

    func testSearchDeduplicatesByCanonicalURLButKeepsDifferentSongIDs() throws {
        let html = "<ul class='c-list'>" + [
            searchItem(href: "/song.php?data=4090", title: "同じ曲", artist: "最初の奏者"),
            searchItem(href: "http://ufret.jp/song.php?data=4090&amp;unused=1#top", title: "重複"),
            searchItem(href: "/song.php?data=4091", title: "同じ曲", artist: "別の奏者"),
            searchItem(href: "https://www.ufret.jp/song.php?data=4091#bottom", title: "重複")
        ].joined(separator: "\n") + "</ul>"

        let results = try UFretSearchParser.parse(html: html)

        XCTAssertEqual(results.map(\.title), ["同じ曲", "同じ曲"])
        XCTAssertEqual(results.map(\.artist), ["最初の奏者", "別の奏者"])
        XCTAssertEqual(results.map(\.url.absoluteString), [
            "https://www.ufret.jp/song.php?data=4090",
            "https://www.ufret.jp/song.php?data=4091"
        ])
    }

    func testSearchLimitsToThirtyUniqueResultsInPageOrder() throws {
        let items = (0..<35).flatMap { index in
            [
                searchItem(href: "/song.php?data=\(5000 + index)", title: "合成曲 \(index)"),
                searchItem(href: "/song.php?data=\(5000 + index)&amp;unused=1", title: "重複 \(index)")
            ]
        }
        let results = try UFretSearchParser.parse(
            html: "<ul class='c-list'>" + items.joined(separator: "\n") + "</ul>"
        )

        XCTAssertEqual(results.count, 30)
        XCTAssertEqual(results.map(\.title), (0..<30).map { "合成曲 \($0)" })
        XCTAssertEqual(results.map(\.url.absoluteString), (0..<30).map {
            "https://www.ufret.jp/song.php?data=\(5000 + $0)"
        })
    }

    func testSearchSkipsInvalidSongURLsAndMissingArtistDefaultsToEmpty() throws {
        let invalidURLs = [
            "https://example.com/song.php?data=4090",
            "https://www.ufret.jp.example.com/song.php?data=4090",
            "ftp://www.ufret.jp/song.php?data=4090",
            "/artist.php?data=4090",
            "/song.php",
            "/song.php?data=0",
            "/song.php?data=-1",
            "/song.php?data=12.5",
            "/song.php?data=4090suffix"
        ]
        let invalidItems = invalidURLs.map {
            searchItem(href: $0, title: "無効なリンク")
        }.joined(separator: "\n")
        let html = """
            <ul class='c-list'>
            \(invalidItems)
            <li class='c-list__item'>
              <a href='/song.php?data=4090'>
                <p class='c-list__title'>有効な合成曲</p>
              </a>
            </li>
            </ul>
            """

        let results = try UFretSearchParser.parse(html: html)

        XCTAssertEqual(results.map(\.title), ["有効な合成曲"])
        XCTAssertEqual(results.first?.artist, "")
    }

    func testRecognizedSearchPagesWithNoResultsReturnEmpty() throws {
        let pages = [
            "<html><body><h1>検索結果</h1><p>0曲</p></body></html>",
            "<html><body><ul class='c-list'></ul></body></html>",
            "<div class='c-list'>" + searchItem(href: "/song.php?data=0", title: "無効") + "</div>"
        ]

        for html in pages {
            XCTAssertTrue(try UFretSearchParser.parse(html: html).isEmpty, html)
        }
    }

    func testUnrecognizedSearchHTMLThrowsInsteadOfReportingNoResults() {
        for html in [
            "",
            "<html><body><h1>アクセス制限</h1></body></html>",
            "<html><head><title>U-FRET</title></head><body>説明のみ</body></html>",
            "<p>検索結果</p>",
            "<a href='/song.php?data=4090'>リストではないリンク</a>"
        ] {
            XCTAssertThrowsError(try UFretSearchParser.parse(html: html), html)
        }
    }

    func testCanonicalSongURLNormalizesSupportedSchemesHostsAndRemovesExtras() throws {
        for rawURL in [
            "http://ufret.jp/song.php?data=4090",
            "https://ufret.jp/song.php?data=4090",
            "http://www.ufret.jp/song.php?data=4090&key=2#top",
            "https://www.ufret.jp/song.php?key=2&data=4090&unused=1#gsc",
            "https://WWW.UFRET.JP/song.php?data=4090"
        ] {
            let url = try XCTUnwrap(URL(string: rawURL))
            XCTAssertEqual(
                UFretSearchParser.canonicalSongURL(from: url)?.absoluteString,
                "https://www.ufret.jp/song.php?data=4090",
                rawURL
            )
        }
    }

    func testCanonicalSongURLRejectsUnsupportedURLsAndNonPositiveNumericIDs() throws {
        for rawURL in [
            "https://example.com/song.php?data=4090",
            "https://ufret.jp.example.com/song.php?data=4090",
            "https://www.ufret.jp.example.com/song.php?data=4090",
            "https://subdomain.ufret.jp/song.php?data=4090",
            "ftp://www.ufret.jp/song.php?data=4090",
            "file:///song.php?data=4090",
            "/song.php?data=4090",
            "https://www.ufret.jp/search.php?data=4090",
            "https://www.ufret.jp/song.php/extra?data=4090",
            "https://www.ufret.jp/song.php",
            "https://www.ufret.jp/song.php?data=",
            "https://www.ufret.jp/song.php?data=0",
            "https://www.ufret.jp/song.php?data=-4090",
            "https://www.ufret.jp/song.php?data=12.5",
            "https://www.ufret.jp/song.php?data=4090suffix"
        ] {
            let url = try XCTUnwrap(URL(string: rawURL))
            XCTAssertNil(UFretSearchParser.canonicalSongURL(from: url), rawURL)
        }
    }

    func testSearchURLEncodesTheKeyIncludingLiteralPlusWithoutAFragment() throws {
        let query = "合成 A+B & C/#?% 🎸"
        let url = try XCTUnwrap(UFretSearchParser.searchURL(query: query))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let encodedQuery = try XCTUnwrap(components.percentEncodedQuery)

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "www.ufret.jp")
        XCTAssertEqual(components.path, "/search.php")
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "key", value: query)])
        XCTAssertTrue(encodedQuery.contains("A%2BB"))
        XCTAssertFalse(encodedQuery.contains("+"))
        XCTAssertNil(components.fragment)
    }

    func testSearchResultPresentationPreservesTheDefaultArtistInitializer() {
        let wiki = ChordWikiSearchResult(
            title: "合成曲",
            url: URL(string: "https://ja.chordwiki.org/wiki/Synthetic")!
        )
        let ufret = ChordWikiSearchResult(
            title: "合成曲",
            url: URL(string: "https://www.ufret.jp/song.php?data=4090")!,
            artist: "合成アーティスト"
        )
        let ufretWithoutArtist = ChordWikiSearchResult(title: ufret.title, url: ufret.url)

        XCTAssertEqual(wiki.artist, "")
        XCTAssertEqual(wiki.sourceName, "ChordWiki")
        XCTAssertEqual(wiki.subtitle, wiki.sourceName)
        XCTAssertEqual(ufret.sourceName, "U-FRET")
        XCTAssertEqual(ufret.subtitle, "合成アーティスト · U-FRET")
        XCTAssertEqual(ufretWithoutArtist.artist, "")
        XCTAssertEqual(ufretWithoutArtist.subtitle, ufretWithoutArtist.sourceName)
    }

    func testChartParsesMetadataEntitiesTempoAndSourceURL() throws {
        let sourceURL = URL(string: "https://www.ufret.jp/song.php?data=4090")!
        let html = chartHTML(
            jsonArray: #"["[C]合成の歌"]"#,
            metadata: """
                <h1>ページ全体の見出し</h1>
                <h1 class='p-detail-head__ttl'> Rock &amp; &quot;合成&quot; &lt;歌&gt; &#x1F3B8; </h1>
                <a href='/artist.php?id=1' class='p-detail-head__artist'> O&#39;Artist&nbsp;&amp;&nbsp;&#21512;&#25104; </a>
                """,
            bpmDeclaration: "const defaultBpm = '120';"
        )

        let chart = try UFretChartParser.parse(html: html, fallbackTitle: "Fallback", sourceURL: sourceURL)

        XCTAssertEqual(chart.sourceTitle, "Fallback")
        XCTAssertEqual(chart.title, "Rock & \"合成\" <歌> 🎸")
        XCTAssertEqual(chart.artist, "O'Artist & 合成")
        XCTAssertEqual(chart.bpm, 120)
        XCTAssertEqual(chart.sourceURL, sourceURL)
        XCTAssertEqual(chart.lines.first?.segments.first?.chord, "C")
        XCTAssertEqual(chart.lines.first?.segments.first?.text, "合成の歌")
    }

    func testChartFallsBackToRequestedTitleWhenMetadataIsMissingOrBlank() throws {
        for metadata in ["", "<h1 class='p-detail-head__ttl'> \n </h1>"] {
            let chart = try UFretChartParser.parse(
                html: chartHTML(jsonArray: #"["[C]合成の歌"]"#, metadata: metadata),
                fallbackTitle: "Requested song",
                sourceURL: nil
            )

            XCTAssertEqual(chart.title, "Requested song")
            XCTAssertEqual(chart.artist, "")
            XCTAssertNil(chart.bpm)
            XCTAssertNil(chart.sourceURL)
        }
    }

    func testChartJSONPreservesUnicodeEscapesQuotesBracketsAndConsecutiveChords() throws {
        // The bracket/semicolon inside a JSON string must not end the array extraction.
        let json = #"""
            ["[C]\u65e5\u672c\u8a9e \ud83c\udfb8 \"歌\" (かっこ) [] [歌詞] ]; = [あと]\r\n", "", "[Am][F]合成の行\\終わり\n", "[G]最後\r"]
            """#
        let chart = try UFretChartParser.parse(
            html: chartHTML(jsonArray: json),
            fallbackTitle: "Fixture",
            sourceURL: nil
        )
        let expected = ChordChartParser.parse(
            "[C]日本語 🎸 \"歌\" (かっこ) [] [歌詞] ]; = [あと]\n\n[Am][F]合成の行\\終わり\n[G]最後",
            fallbackTitle: "Fixture"
        )

        XCTAssertEqual(chart.lines, expected.lines)
        XCTAssertEqual(chart.lines.count, 4)
        guard chart.lines.count == 4 else { return }
        XCTAssertEqual(chart.lines[0].segments.map(\.text).joined(), "日本語 🎸 \"歌\" (かっこ) [] [歌詞] ]; = [あと]")
        XCTAssertEqual(chart.lines[1].kind, .blank)
        XCTAssertEqual(chart.lines[2].segments, [
            ChartSegment(chord: "Am", text: ""),
            ChartSegment(chord: "F", text: "合成の行\\終わり")
        ])
        XCTAssertEqual(chart.lines.flatMap(\.segments).compactMap(\.chord), ["C", "Am", "F", "G"])
    }

    func testChartStripsOnlyTrailingCRLFPerArrayElementAndKeepsInternalNewlines() throws {
        let rows = ["[C]朝\r\n", "\r\n", "[G]  夜  \n\n", "\n[Am]一行目\n二行目\r", "[F]最後\r\n\r\n"]
        let json = String(decoding: try JSONEncoder().encode(rows), as: UTF8.self)
        let chart = try UFretChartParser.parse(
            html: chartHTML(jsonArray: json),
            fallbackTitle: "Fixture",
            sourceURL: nil
        )
        let expected = ChordChartParser.parse(
            "[C]朝\n\n[G]  夜  \n\n[Am]一行目\n二行目\n[F]最後",
            fallbackTitle: "Fixture"
        )

        XCTAssertEqual(chart.lines, expected.lines)
        XCTAssertEqual(chart.lines.map(\.kind), [.content, .blank, .content, .blank, .content, .content, .content])
        guard chart.lines.count == 7 else { return }
        XCTAssertEqual(chart.lines[2].segments.first?.text, "  夜  ")
        XCTAssertEqual(chart.lines[5].segments.first?.text, "二行目")
    }

    func testChartAcceptsQuotedAndNumericTempoWithinInclusiveBounds() throws {
        for (value, expected) in [("'20'", 20), ("\"96\"", 96), ("120", 120), ("'400'", 400)] {
            let chart = try UFretChartParser.parse(
                html: chartHTML(jsonArray: #"["[C]合成の歌"]"#, bpmDeclaration: "const defaultBpm = \(value);"),
                fallbackTitle: "Fixture",
                sourceURL: nil
            )
            XCTAssertEqual(chart.bpm, expected, value)
        }
    }

    func testChartRejectsZeroOutOfRangeAndMalformedTempoWithoutRejectingTheChart() throws {
        for value in ["'0'", "'19'", "'401'", "'4000'", "'-120'", "'120.5'", "'fast'", "''"] {
            let chart = try UFretChartParser.parse(
                html: chartHTML(jsonArray: #"["[C]合成の歌"]"#, bpmDeclaration: "const defaultBpm = \(value);"),
                fallbackTitle: "Fixture",
                sourceURL: nil
            )
            XCTAssertNil(chart.bpm, value)
            XCTAssertEqual(chart.lines.first?.segments.first?.chord, "C")
        }
    }

    func testChartDoesNotImportAdvertisingOrInstructionalYouTubeLinks() throws {
        let html = chartHTML(
            jsonArray: #"["[C]合成の歌"]"#,
            metadata: """
                <aside><a href='https://youtu.be/j7CDb610Bg0'>広告</a></aside>
                <p>弾き方の説明 <a href='https://www.youtube.com/watch?v=-htsLEAtaKs'>動画</a></p>
                <iframe src='https://www.youtube.com/embed/j7CDb610Bg0'></iframe>
                <p>[Am]これは譜面のデータではありません</p>
                """
        )
        let chart = try UFretChartParser.parse(html: html, fallbackTitle: "Fixture", sourceURL: nil)

        XCTAssertNil(chart.youtubeVideoID)
        XCTAssertEqual(chart.lines, [ChartLine(segments: [ChartSegment(chord: "C", text: "合成の歌")])])
    }

    func testChartThrowsForMissingBrokenNonStringOrEmptyJSONData() {
        let scripts = [
            "",
            #"var other_datas = ["[C]合成の歌"];"#,
            #"var ufret_chord_datas = [];"#,
            #"var ufret_chord_datas = ["[C]合成の歌";"#,
            #"var ufret_chord_datas = ['[C]合成の歌'];"#,
            #"var ufret_chord_datas = "[C]配列ではない";"#,
            #"var ufret_chord_datas = ["[C]合成の歌", 42];"#,
            #"var ufret_chord_datas = ["[C]合成の歌", null];"#,
            #"var ufret_chord_datas = ["[C]\q壊れたエスケープ"];"#
        ]

        for script in scripts {
            let html = "<html><body><h1 class='p-detail-head__ttl'>Fixture</h1><script>\(script)</script></body></html>"
            XCTAssertThrowsError(
                try UFretChartParser.parse(html: html, fallbackTitle: "Fixture", sourceURL: nil),
                script
            )
        }
    }

    private func searchItem(href: String, title: String, artist: String = "") -> String {
        """
        <li class='c-list__item'>
          <a href='\(href)'>
            <p class='c-list__title'>\(title)</p>
            <p class='c-list__artist'>\(artist)</p>
          </a>
        </li>
        """
    }

    private func chartHTML(
        jsonArray: String,
        metadata: String = "",
        bpmDeclaration: String = ""
    ) -> String {
        """
        <html><body>
        \(metadata)
        <script>
        \(bpmDeclaration)
        var ufret_chord_datas = \(jsonArray);
        const unrelated = ["not chart data"];
        </script>
        </body></html>
        """
    }
}
