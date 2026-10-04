import Foundation
import GuitarToolsCore

enum ChordChartSource: Sendable {
    case chordWiki
    case ufret

    init?(url: URL?) {
        switch url?.host?.lowercased() {
        case "ja.chordwiki.org": self = .chordWiki
        case "ufret.jp", "www.ufret.jp": self = .ufret
        default: return nil
        }
    }

    var name: String {
        switch self {
        case .chordWiki: "ChordWiki"
        case .ufret: "U-FRET"
        }
    }
}

extension ChordChart {
    var sourceName: String {
        ChordChartSource(url: sourceURL)?.name ?? "コード譜"
    }
}

/// Keeps the existing chart/search contract while dispatching to each source's loader.
actor ChordChartMacClient: ChordWikiClientProtocol {
    private let chordWiki: any ChordWikiClientProtocol
    private let ufret: any ChordWikiClientProtocol

    init(
        chordWiki: any ChordWikiClientProtocol = ChordWikiMacClient(),
        ufret: any ChordWikiClientProtocol = UFretMacClient()
    ) {
        self.chordWiki = chordWiki
        self.ufret = ufret
    }

    func search(query: String) async throws -> [ChordWikiSearchResult] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        async let wikiResults = Self.search(client: chordWiki, query: normalized)
        async let ufretResults = Self.search(client: ufret, query: normalized)
        let outcomes = await (wikiResults, ufretResults)

        var results: [ChordWikiSearchResult] = []
        var firstError: Error?
        for outcome in [outcomes.0, outcomes.1] {
            switch outcome {
            case .success(let matches): results.append(contentsOf: matches)
            case .failure(let error): firstError = firstError ?? error
            }
        }

        // A failed source must not hide usable results from the other source, or imply zero hits.
        if results.isEmpty, let firstError { throw firstError }
        return results
    }

    func loadChart(_ result: ChordWikiSearchResult) async throws -> ChordChart {
        switch ChordChartSource(url: result.url) {
        case .chordWiki: try await chordWiki.loadChart(result)
        case .ufret: try await ufret.loadChart(result)
        case nil: throw ChordWikiMacClient.ClientError.invalidURL
        }
    }

    private static func search(
        client: any ChordWikiClientProtocol,
        query: String
    ) async -> Result<[ChordWikiSearchResult], Error> {
        do {
            return .success(try await client.search(query: query))
        } catch {
            return .failure(error)
        }
    }
}
