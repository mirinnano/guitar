import Foundation
import GuitarToolsCore
import XCTest
@testable import GuitarToolsMacApp

final class ChordWikiMacClientMediaTests: XCTestCase {
    func testLoadsSongInfoVideoFromTheResultPageNotTheCGIHomepage() async throws {
        let result = ChordWikiSearchResult(title: "鳥の詩",
            url: URL(string: "https://ja.chordwiki.org/wiki/%E9%B3%A5%E3%81%AE%E8%A9%A9")!)
        let requests = MediaRequests()
        defer { _ = MediaURLProtocol.fixtures.withLock { $0.removeValue(forKey: requests.id) } }
        let client = makeClient(requests: requests)
        let chart = try await client.loadChart(result)

        XCTAssertEqual(chart.youtubeVideoID, "AVBoHNqMNwg")
        XCTAssertEqual(chart.lines.first?.segments.first?.chord, "GM7")
        let urls = requests.urls
        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(urls.last, result.url)
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(urls.first), resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "c" })?.value, "edit")
    }

    func testUnavailableSongPageStillLoadsTheChart() async throws {
        let requests = MediaRequests(mediaUnavailable: true)
        defer { _ = MediaURLProtocol.fixtures.withLock { $0.removeValue(forKey: requests.id) } }
        let client = makeClient(requests: requests)
        let chart = try await client.loadChart(ChordWikiSearchResult(title: "鳥の詩",
            url: URL(string: "https://ja.chordwiki.org/wiki/%E9%B3%A5%E3%81%AE%E8%A9%A9")!))
        XCTAssertNil(chart.youtubeVideoID)
        XCTAssertEqual(chart.lines.first?.segments.first?.chord, "GM7")
    }

    private func makeClient(requests: MediaRequests) -> ChordWikiMacClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MediaURLProtocol.self]
        // Each session has its own fixture; no shared static handler between tests.
        MediaURLProtocol.fixtures.withLock { $0[requests.id] = requests }
        configuration.httpAdditionalHeaders = ["X-Guitar-Media-Test": requests.id]
        let configuredSession = URLSession(configuration: configuration)
        return ChordWikiMacClient(session: configuredSession)
    }
}

private final class MediaRequests: @unchecked Sendable {
    let id = UUID().uuidString
    let mediaUnavailable: Bool
    private let lock = NSLock()
    private var recorded: [URL] = []
    init(mediaUnavailable: Bool = false) { self.mediaUnavailable = mediaUnavailable }
    var urls: [URL] { lock.lock(); defer { lock.unlock() }; return recorded }
    func response(for url: URL) -> (Int, String) {
        lock.lock(); recorded.append(url); lock.unlock()
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if query.contains(where: { $0.name == "c" && $0.value == "edit" }) {
            return (200, "<textarea name='chord'>{title:Test}\n[GM7]test [A]line</textarea>")
        }
        if url.path.hasPrefix("/wiki/") {
            // Link structure observed in 鳥の詩's 楽曲情報; no video in the chord source.
            return mediaUnavailable ? (503, "Unavailable") :
                (200, "<a href=\"https://www.youtube.com/watch?v=AVBoHNqMNwg\" target=\"_blank\">YouTube</a>")
        }
        return (200, "<html><h1>ChordWiki</h1>コード譜共有サイト</html>")
    }
}

private final class MediaFixtureStore: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: MediaRequests] = [:]
    func withLock<T>(_ body: (inout [String: MediaRequests]) -> T) -> T {
        lock.lock(); defer { lock.unlock() }; return body(&values)
    }
}

private final class MediaURLProtocol: URLProtocol, @unchecked Sendable {
    static let fixtures = MediaFixtureStore()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, let id = request.value(forHTTPHeaderField: "X-Guitar-Media-Test"),
              let fixture = Self.fixtures.withLock({ $0[id] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        let (status, body) = fixture.response(for: url)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status,
            httpVersion: nil, headerFields: ["Content-Type": "text/html; charset=utf-8"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
