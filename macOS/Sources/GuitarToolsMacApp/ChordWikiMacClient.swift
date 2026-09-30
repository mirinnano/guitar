import Foundation
import GuitarToolsCore

struct ChordWikiSearchResult:
    Identifiable,
    Hashable,
    Sendable {

    let title: String
    let url: URL

    var id: String {
        url.absoluteString
    }
}

actor ChordWikiMacClient {

    private let session:
        URLSession

    init(
        session:
            URLSession = .shared
    ) {
        self.session = session
    }

    func search(
        query: String
    ) async throws
        -> [ChordWikiSearchResult] {

        var components =
            URLComponents(
                string:
                    "https://ja.chordwiki.org/wiki.cgi"
            )!

        components.queryItems = [
            URLQueryItem(
                name: "c",
                value: "search"
            ),
            URLQueryItem(
                name: "q",
                value: query
            )
        ]

        guard let url =
            components.url
        else {
            throw ClientError
                .invalidURL
        }

        let html =
            try await requestText(url)

        return parseSearchResults(
            html
        )
    }

    func loadChart(
        _ result:
            ChordWikiSearchResult
    ) async throws
        -> ChordChart {

        var components =
            URLComponents(
                string:
                    "https://ja.chordwiki.org/wiki.cgi"
            )!

        components.queryItems = [
            URLQueryItem(
                name: "c",
                value: "edit"
            ),
            URLQueryItem(
                name: "t",
                value: result.title
            )
        ]

        guard let url =
            components.url
        else {
            throw ClientError
                .invalidURL
        }

        let html =
            try await requestText(url)

        guard let source =
            extractChordSource(
                html
            )
        else {
            throw ClientError
                .missingChordSource
        }

        return ChordChartParser
            .parse(
                source,
                fallbackTitle:
                    result.title,
                sourceURL:
                    result.url
            )
    }

    private func requestText(
        _ url: URL
    ) async throws -> String {
        var request =
            URLRequest(url: url)

        request.timeoutInterval = 12
        request.setValue(
            "GuitarToolsMac/0.1",
            forHTTPHeaderField:
                "User-Agent"
        )
        request.setValue(
            "ja,en;q=0.8",
            forHTTPHeaderField:
                "Accept-Language"
        )

        let (
            data,
            response
        ) =
            try await session.data(
                for: request
            )

        guard
            let http =
                response as?
                HTTPURLResponse,
            (200..<300)
                .contains(
                    http.statusCode
                )
        else {
            throw ClientError
                .httpFailure
        }

        guard let text =
            String(
                data: data,
                encoding: .utf8
            )
        else {
            throw ClientError
                .invalidEncoding
        }

        return text
    }

    private func parseSearchResults(
        _ html: String
    ) -> [ChordWikiSearchResult] {
        let pattern =
            #"(?is)<a[^>]+href=["']([^"']+)["'][^>]*>(.*?)</a>"#

        guard let regex =
            try? NSRegularExpression(
                pattern: pattern
            )
        else {
            return []
        }

        let ns =
            html as NSString

        var seen = Set<String>()
        var results:
            [ChordWikiSearchResult] = []

        for match in regex.matches(
            in: html,
            range: NSRange(
                location: 0,
                length: ns.length
            )
        ) {
            let href =
                htmlDecode(
                    ns.substring(
                        with:
                            match.range(
                                at: 1
                            )
                    )
                )

            let rawTitle =
                ns.substring(
                    with:
                        match.range(
                            at: 2
                        )
                )

            let title =
                htmlDecode(
                    rawTitle
                        .replacingOccurrences(
                            of:
                                #"<[^>]+>"#,
                            with: "",
                            options:
                                .regularExpression
                        )
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            guard
                !title.isEmpty,
                isChartLink(href),
                !seen.contains(title),
                let url =
                    resolvedURL(
                        href: href,
                        title: title
                    )
            else {
                continue
            }

            seen.insert(title)

            results.append(
                ChordWikiSearchResult(
                    title: title,
                    url: url
                )
            )
        }

        return results
    }

    private func isChartLink(
        _ href: String
    ) -> Bool {
        if href.contains(
            "c=edit"
        ) ||
            href.contains(
                "c=search"
            ) ||
            href.contains(
                "c=history"
            ) ||
            href.contains(
                "c=diff"
            ) {
            return false
        }

        return href.contains(
            "/wiki/"
        ) ||
            href.contains(
                "c=view"
            )
    }

    private func resolvedURL(
        href: String,
        title: String
    ) -> URL? {
        if let absolute =
            URL(string: href),
           absolute.scheme != nil {
            return absolute
        }

        if let relative =
            URL(
                string: href,
                relativeTo:
                    URL(
                        string:
                            "https://ja.chordwiki.org"
                    )
            ) {
            return relative
                .absoluteURL
        }

        let escaped =
            title
                .addingPercentEncoding(
                    withAllowedCharacters:
                        .urlPathAllowed
                )
                ?? title

        return URL(
            string:
                "https://ja.chordwiki.org/wiki/\(escaped)"
        )
    }

    private func extractChordSource(
        _ html: String
    ) -> String? {
        let pattern =
            #"(?is)<textarea[^>]*name\s*=\s*["']chord["'][^>]*>(.*?)</textarea>"#

        guard
            let regex =
                try? NSRegularExpression(
                    pattern: pattern
                )
        else {
            return nil
        }

        let ns =
            html as NSString

        guard let match =
            regex.firstMatch(
                in: html,
                range: NSRange(
                    location: 0,
                    length: ns.length
                )
            )
        else {
            return nil
        }

        return htmlDecode(
            ns.substring(
                with:
                    match.range(at: 1)
            )
        )
    }

    private func htmlDecode(
        _ value: String
    ) -> String {
        var result =
            value
                .replacingOccurrences(
                    of: "&amp;",
                    with: "&"
                )
                .replacingOccurrences(
                    of: "&lt;",
                    with: "<"
                )
                .replacingOccurrences(
                    of: "&gt;",
                    with: ">"
                )
                .replacingOccurrences(
                    of: "&quot;",
                    with: "\""
                )
                .replacingOccurrences(
                    of: "&#39;",
                    with: "'"
                )
                .replacingOccurrences(
                    of: "&nbsp;",
                    with: " "
                )

        let pattern =
            #"&#(x?[0-9A-Fa-f]+);"#

        guard let regex =
            try? NSRegularExpression(
                pattern: pattern
            )
        else {
            return result
        }

        let matches =
            regex.matches(
                in: result,
                range: NSRange(
                    location: 0,
                    length:
                        (result as NSString)
                            .length
                )
            )
            .reversed()

        for match in matches {
            let ns =
                result as NSString

            let token =
                ns.substring(
                    with:
                        match.range(at: 1)
                )

            let value: UInt32?

            if token.lowercased()
                .hasPrefix("x") {
                value =
                    UInt32(
                        token.dropFirst(),
                        radix: 16
                    )
            } else {
                value =
                    UInt32(token)
            }

            if let value,
               let scalar =
                UnicodeScalar(value) {
                result =
                    ns.replacingCharacters(
                        in:
                            match.range(at: 0),
                        with:
                            String(
                                Character(
                                    scalar
                                )
                            )
                    )
            }
        }

        return result
    }

    enum ClientError:
        LocalizedError {

        case invalidURL
        case httpFailure
        case invalidEncoding
        case missingChordSource

        var errorDescription:
            String? {
            switch self {
            case .invalidURL:
                "URLを作成できませんでした。"
            case .httpFailure:
                "ChordWikiへの接続に失敗しました。"
            case .invalidEncoding:
                "ChordWikiの応答を読み取れませんでした。"
            case .missingChordSource:
                "コード譜ソースを取得できませんでした。"
            }
        }
    }
}
