import Foundation
import XCTest
import GuitarToolsCore
@testable import GuitarToolsMacApp

final class ChordChartMacClientTests: XCTestCase {

    func testSearchesBothSourcesInParallelAndKeepsChordWikiThenUFretOrder() async throws {
        let query = "合成の歌 A+B"
        let wikiResults = [wikiResult(title: "同じ曲"), wikiResult(title: "Wiki second")]
        let ufretResults = [ufretResult(title: "同じ曲", id: 4090), ufretResult(title: "UFret second", id: 4091)]
        let started = expectation(description: "Both sources started before either was released")
        started.expectedFulfillmentCount = 2
        let ufretFinished = expectation(description: "U-FRET completed while ChordWiki was still suspended")
        let wikiGate = StubSearchGate()
        let ufretGate = StubSearchGate()
        let wiki = StubChordChartSourceClient(
            searchOutcome: .success(wikiResults),
            gate: wikiGate,
            started: started
        )
        let ufret = StubChordChartSourceClient(
            searchOutcome: .success(ufretResults),
            gate: ufretGate,
            started: started,
            finished: ufretFinished
        )
        let client = ChordChartMacClient(chordWiki: wiki, ufret: ufret)
        let searchTask = Task { try await client.search(query: query) }

        await fulfillment(of: [started], timeout: 2)
        let wikiQueries = await wiki.requestedQueries()
        let ufretQueries = await ufret.requestedQueries()
        XCTAssertEqual(wikiQueries, [query])
        XCTAssertEqual(ufretQueries, [query])

        // Release both gates even after an expectation failure so a serial implementation cannot hang the suite.
        await ufretGate.release()
        await fulfillment(of: [ufretFinished], timeout: 2)
        await wikiGate.release()
        let results = try await searchTask.value

        XCTAssertEqual(results, wikiResults + ufretResults)
        XCTAssertEqual(results.map(\.sourceName), ["ChordWiki", "ChordWiki", "U-FRET", "U-FRET"])
    }

    func testSearchTrimsTheQueryBeforeForwardingToBothSources() async throws {
        let wiki = StubChordChartSourceClient()
        let ufret = StubChordChartSourceClient()
        let client = ChordChartMacClient(chordWiki: wiki, ufret: ufret)

        _ = try await client.search(query: "  合成 A+B\n")

        let wikiQueries = await wiki.requestedQueries()
        let ufretQueries = await ufret.requestedQueries()
        XCTAssertEqual(wikiQueries, ["合成 A+B"])
        XCTAssertEqual(ufretQueries, ["合成 A+B"])
    }

    func testBlankSearchDoesNotCallEitherSource() async throws {
        let wiki = StubChordChartSourceClient(searchOutcome: .failure(.searchUnavailable))
        let ufret = StubChordChartSourceClient(searchOutcome: .failure(.searchUnavailable))
        let client = ChordChartMacClient(chordWiki: wiki, ufret: ufret)

        for query in ["", " \n\t "] {
            let results = try await client.search(query: query)
            XCTAssertTrue(results.isEmpty)
        }

        let wikiQueries = await wiki.requestedQueries()
        let ufretQueries = await ufret.requestedQueries()
        XCTAssertTrue(wikiQueries.isEmpty)
        XCTAssertTrue(ufretQueries.isEmpty)
    }

    func testReturnsUFretResultsWhenChordWikiSearchFails() async throws {
        let expected = [ufretResult(title: "合成曲", id: 4090)]
        let wiki = StubChordChartSourceClient(searchOutcome: .failure(.searchUnavailable))
        let ufret = StubChordChartSourceClient(searchOutcome: .success(expected))
        let client = ChordChartMacClient(chordWiki: wiki, ufret: ufret)

        let results = try await client.search(query: "合成曲")

        XCTAssertEqual(results, expected)
        let wikiQueries = await wiki.requestedQueries()
        let ufretQueries = await ufret.requestedQueries()
        XCTAssertEqual(wikiQueries, ["合成曲"])
        XCTAssertEqual(ufretQueries, ["合成曲"])
    }

    func testReturnsChordWikiResultsWhenUFretSearchFails() async throws {
        let expected = [wikiResult(title: "合成曲")]
        let wiki = StubChordChartSourceClient(searchOutcome: .success(expected))
        let ufret = StubChordChartSourceClient(searchOutcome: .failure(.searchUnavailable))
        let client = ChordChartMacClient(chordWiki: wiki, ufret: ufret)

        let results = try await client.search(query: "合成曲")

        XCTAssertEqual(results, expected)
        let wikiQueries = await wiki.requestedQueries()
        let ufretQueries = await ufret.requestedQueries()
        XCTAssertEqual(wikiQueries, ["合成曲"])
        XCTAssertEqual(ufretQueries, ["合成曲"])
    }

    func testReturnsEmptyWhenBothSearchesSuccessfullyFindNothing() async throws {
        let wiki = StubChordChartSourceClient()
        let ufret = StubChordChartSourceClient()
        let client = ChordChartMacClient(chordWiki: wiki, ufret: ufret)

        let results = try await client.search(query: "Missing synthetic song")

        XCTAssertTrue(results.isEmpty)
        let wikiQueries = await wiki.requestedQueries()
        let ufretQueries = await ufret.requestedQueries()
        XCTAssertEqual(wikiQueries, ["Missing synthetic song"])
        XCTAssertEqual(ufretQueries, ["Missing synthetic song"])
    }

    func testThrowsWhenNoResultsAndAtLeastOneSourceFails() async {
        for (wikiFails, ufretFails) in [(true, false), (false, true), (true, true)] {
            let wiki = StubChordChartSourceClient(
                searchOutcome: wikiFails ? .failure(.searchUnavailable) : .success([])
            )
            let ufret = StubChordChartSourceClient(
                searchOutcome: ufretFails ? .failure(.searchUnavailable) : .success([])
            )
            let client = ChordChartMacClient(chordWiki: wiki, ufret: ufret)

            do {
                _ = try await client.search(query: "Missing song")
                XCTFail("Expected an error with no results; ChordWiki failed: \(wikiFails), U-FRET failed: \(ufretFails)")
            } catch {
                // No error priority is required when both sources fail.
            }

            let wikiQueries = await wiki.requestedQueries()
            let ufretQueries = await ufret.requestedQueries()
            XCTAssertEqual(wikiQueries, ["Missing song"])
            XCTAssertEqual(ufretQueries, ["Missing song"])
        }
    }

    func testLoadsChordWikiChartsThroughOnlyTheChordWikiClient() async throws {
        let result = wikiResult(title: "合成のWiki曲")
        let expected = fixtureChart(title: "Wiki chart", sourceURL: result.url)
        let wiki = StubChordChartSourceClient(chartOutcome: .success(expected))
        let ufret = StubChordChartSourceClient()
        let client = ChordChartMacClient(chordWiki: wiki, ufret: ufret)

        let chart = try await client.loadChart(result)

        XCTAssertEqual(chart, expected)
        let wikiRequests = await wiki.requestedCharts()
        let ufretRequests = await ufret.requestedCharts()
        XCTAssertEqual(wikiRequests, [result])
        XCTAssertTrue(ufretRequests.isEmpty)
    }

    func testLoadsBothUFretHostsThroughOnlyTheUFretClient() async throws {
        let expected = fixtureChart(
            title: "U-FRET chart",
            sourceURL: URL(string: "https://www.ufret.jp/song.php?data=4090")!
        )
        let wiki = StubChordChartSourceClient()
        let ufret = StubChordChartSourceClient(chartOutcome: .success(expected))
        let client = ChordChartMacClient(chordWiki: wiki, ufret: ufret)
        let results = [
            "http://ufret.jp/song.php?data=4090",
            "https://www.ufret.jp/song.php?data=4090",
            "https://WWW.UFRET.JP/song.php?data=4090"
        ].map {
            ChordWikiSearchResult(title: "合成のU-FRET曲", url: URL(string: $0)!, artist: "合成奏者")
        }

        for result in results {
            let chart = try await client.loadChart(result)
            XCTAssertEqual(chart, expected)
        }

        let wikiRequests = await wiki.requestedCharts()
        let ufretRequests = await ufret.requestedCharts()
        XCTAssertTrue(wikiRequests.isEmpty)
        XCTAssertEqual(ufretRequests, results)
    }

    func testRejectsUnknownChartHostsWithoutCallingEitherSource() async {
        let wiki = StubChordChartSourceClient()
        let ufret = StubChordChartSourceClient()
        let client = ChordChartMacClient(chordWiki: wiki, ufret: ufret)

        for rawURL in [
            "https://example.com/song.php?data=4090",
            "https://ja.chordwiki.org.example.com/wiki/Synthetic",
            "https://www.ufret.jp.example.com/song.php?data=4090",
            "https://example.com/?redirect=https://www.ufret.jp/song.php?data=4090",
            "file:///song.php?data=4090"
        ] {
            let result = ChordWikiSearchResult(title: "Unknown source", url: URL(string: rawURL)!)
            do {
                _ = try await client.loadChart(result)
                XCTFail("Expected an unknown-host error for \(rawURL)")
            } catch {
                // Host dispatch must reject the URL before consulting a provider.
            }
        }

        let wikiRequests = await wiki.requestedCharts()
        let ufretRequests = await ufret.requestedCharts()
        XCTAssertTrue(wikiRequests.isEmpty)
        XCTAssertTrue(ufretRequests.isEmpty)
    }

    func testSelectedChartSourceFailureDoesNotFallBackToTheOtherSource() async {
        for useWiki in [true, false] {
            let result = useWiki ? wikiResult(title: "合成曲") : ufretResult(title: "合成曲", id: 4090)
            let fallback = fixtureChart(title: "Wrong provider", sourceURL: result.url)
            let wiki = StubChordChartSourceClient(
                chartOutcome: useWiki ? .failure(.chartUnavailable) : .success(fallback)
            )
            let ufret = StubChordChartSourceClient(
                chartOutcome: useWiki ? .success(fallback) : .failure(.chartUnavailable)
            )
            let client = ChordChartMacClient(chordWiki: wiki, ufret: ufret)

            do {
                _ = try await client.loadChart(result)
                XCTFail("Expected the selected provider's load failure")
            } catch {
                XCTAssertEqual(error as? StubChartSourceError, .chartUnavailable)
            }

            let wikiRequests = await wiki.requestedCharts()
            let ufretRequests = await ufret.requestedCharts()
            XCTAssertEqual(wikiRequests, useWiki ? [result] : [])
            XCTAssertEqual(ufretRequests, useWiki ? [] : [result])
        }
    }

    private func wikiResult(title: String) -> ChordWikiSearchResult {
        ChordWikiSearchResult(title: title, url: ChordWikiSearchParser.canonicalURL(title: title)!)
    }

    private func ufretResult(title: String, id: Int) -> ChordWikiSearchResult {
        ChordWikiSearchResult(
            title: title,
            url: URL(string: "https://www.ufret.jp/song.php?data=\(id)")!,
            artist: "合成奏者"
        )
    }

    private func fixtureChart(title: String, sourceURL: URL) -> ChordChart {
        ChordChartParser.parse(
            "{title:\(title)}\n{artist:合成奏者}\n{tempo:120}\n[C]合成の歌",
            fallbackTitle: "Fallback",
            sourceURL: sourceURL
        )
    }
}

private enum StubChartSourceError: Error, Equatable, Sendable {
    case searchUnavailable
    case chartUnavailable
}

private actor StubChordChartSourceClient: ChordWikiClientProtocol {
    private let searchOutcome: Result<[ChordWikiSearchResult], StubChartSourceError>
    private let chartOutcome: Result<ChordChart, StubChartSourceError>
    private let gate: StubSearchGate?
    private let started: XCTestExpectation?
    private let finished: XCTestExpectation?
    private var queries: [String] = []
    private var charts: [ChordWikiSearchResult] = []

    init(
        searchOutcome: Result<[ChordWikiSearchResult], StubChartSourceError> = .success([]),
        chartOutcome: Result<ChordChart, StubChartSourceError> = .failure(.chartUnavailable),
        gate: StubSearchGate? = nil,
        started: XCTestExpectation? = nil,
        finished: XCTestExpectation? = nil
    ) {
        self.searchOutcome = searchOutcome
        self.chartOutcome = chartOutcome
        self.gate = gate
        self.started = started
        self.finished = finished
    }

    func search(query: String) async throws -> [ChordWikiSearchResult] {
        queries.append(query)
        started?.fulfill()
        if let gate { await gate.wait() }
        defer { finished?.fulfill() }
        return try searchOutcome.get()
    }

    func loadChart(_ result: ChordWikiSearchResult) async throws -> ChordChart {
        charts.append(result)
        return try chartOutcome.get()
    }

    func requestedQueries() -> [String] { queries }

    func requestedCharts() -> [ChordWikiSearchResult] { charts }
}

private actor StubSearchGate {
    private var released = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !released else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        released = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}
