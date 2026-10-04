import Foundation
import GuitarToolsCore

actor UFretMacClient: ChordWikiClientProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String) async throws -> [ChordWikiSearchResult] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        guard let url = UFretSearchParser.searchURL(query: normalized) else {
            throw ClientError.invalidURL
        }
        return try UFretSearchParser.parse(html: await requestText(url))
    }

    func loadChart(_ result: ChordWikiSearchResult) async throws -> ChordChart {
        guard let url = UFretSearchParser.canonicalSongURL(from: result.url) else {
            throw ClientError.invalidURL
        }
        return try UFretChartParser.parse(
            html: await requestText(url),
            fallbackTitle: result.title,
            sourceURL: url
        )
    }

    private func requestText(_ url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("GuitarToolsMac/0.3 (+https://github.com/mirinnano/guitar)", forHTTPHeaderField: "User-Agent")
        request.setValue("ja,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClientError.httpFailure
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw ClientError.invalidEncoding
        }
        return html
    }

    enum ClientError: LocalizedError {
        case invalidURL
        case httpFailure
        case invalidEncoding
        case invalidSearchResponse
        case missingChordSource

        var errorDescription: String? {
            switch self {
            case .invalidURL: "U-FRETのURLを作成できませんでした。"
            case .httpFailure: "U-FRETへの接続に失敗しました。"
            case .invalidEncoding: "U-FRETの応答を読み取れませんでした。"
            case .invalidSearchResponse: "U-FRETの検索結果を読み取れませんでした。"
            case .missingChordSource: "U-FRETのコード譜を取得できませんでした。"
            }
        }
    }
}
