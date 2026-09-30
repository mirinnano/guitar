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

enum ChordWikiSearchParser {

    private static let baseURL =
        URL(
            string:
                "https://ja.chordwiki.org"
        )!

    private static let excludedCommands =
        Set(
            [
                "search",
                "edit",
                "diff",
                "new",
                "history",
                "infoedit"
            ]
        )

    static func parse(
        html: String
    ) -> [ChordWikiSearchResult] {
        let pattern =
            #"(?is)<a[^>]+href\s*=\s*["']([^"']+)["'][^>]*>"#

        guard let regex =
            try? NSRegularExpression(
                pattern: pattern
            )
        else {
            return []
        }

        let ns =
            html as NSString

        var seen =
            Set<String>()

        var values:
            [ChordWikiSearchResult] = []

        for match in regex.matches(
            in: html,
            range: NSRange(
                location: 0,
                length: ns.length
            )
        ) {
            let rawHref =
                htmlDecode(
                    ns.substring(
                        with:
                            match.range(
                                at: 1
                            )
                    )
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            guard
                let absoluteURL =
                    URL(
                        string: rawHref,
                        relativeTo:
                            baseURL
                    )?
                    .absoluteURL,
                absoluteURL.host ==
                    baseURL.host,
                let title =
                    title(
                        from:
                            absoluteURL
                    ),
                !seen.contains(title),
                let canonical =
                    canonicalURL(
                        title: title
                    )
            else {
                continue
            }

            seen.insert(title)

            values.append(
                ChordWikiSearchResult(
                    title: title,
                    url: canonical
                )
            )

            if values.count >= 30 {
                break
            }
        }

        return values
    }

    static func title(
        from url: URL
    ) -> String? {
        guard
            url.host ==
                baseURL.host,
            let components =
                URLComponents(
                    url: url,
                    resolvingAgainstBaseURL:
                        true
                )
        else {
            return nil
        }

        let path =
            components.path

        if path.hasPrefix(
            "/wiki/"
        ) {
            let encodedPath =
                components
                    .percentEncodedPath

            let encodedTitle =
                String(
                    encodedPath
                        .dropFirst(
                            "/wiki/"
                                .count
                        )
                )

            return decodedComponent(
                encodedTitle
            )
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .nilIfBlank
        }

        guard
            path == "/wiki.cgi"
        else {
            return nil
        }

        let command =
            rawQueryParameter(
                components
                    .percentEncodedQuery,
                name: "c"
            )?
            .lowercased()

        if let command,
           excludedCommands
            .contains(command) {
            return nil
        }

        return rawQueryParameter(
            components
                .percentEncodedQuery,
            name: "t"
        )?
        .trimmingCharacters(
            in:
                .whitespacesAndNewlines
        )
        .nilIfBlank
    }

    static func canonicalURL(
        title: String
    ) -> URL? {
        var allowed =
            CharacterSet
                .urlPathAllowed

        allowed.remove(
            charactersIn:
                "/?#%"
        )

        guard let encoded =
            title.addingPercentEncoding(
                withAllowedCharacters:
                    allowed
            )
        else {
            return nil
        }

        return URL(
            string:
                "https://ja.chordwiki.org/wiki/\(encoded)"
        )
    }

    private static func rawQueryParameter(
        _ rawQuery: String?,
        name: String
    ) -> String? {
        rawQuery?
            .split(
                separator: "&",
                omittingEmptySubsequences:
                    false
            )
            .first {
                pair in

                pair
                    .split(
                        separator: "=",
                        maxSplits: 1,
                        omittingEmptySubsequences:
                            false
                    )
                    .first
                    .map(String.init) ==
                name
            }
            .map(String.init)
            .map {
                pair in

                let value =
                    pair
                        .split(
                            separator: "=",
                            maxSplits: 1,
                            omittingEmptySubsequences:
                                false
                        )

                guard
                    value.count == 2
                else {
                    return ""
                }

                return decodedComponent(
                    String(value[1])
                )
            }
    }

    private static func decodedComponent(
        _ value: String
    ) -> String {
        value
            .replacingOccurrences(
                of: "+",
                with: " "
            )
            .removingPercentEncoding
        ?? value
    }

    private static func htmlDecode(
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

        for match in regex
            .matches(
                in: result,
                range: NSRange(
                    location: 0,
                    length:
                        (result as NSString)
                            .length
                )
            )
            .reversed() {
            let ns =
                result as NSString

            let token =
                ns.substring(
                    with:
                        match.range(at: 1)
                )

            let scalarValue:
                UInt32?

            if token.lowercased()
                .hasPrefix("x") {
                scalarValue =
                    UInt32(
                        token.dropFirst(),
                        radix: 16
                    )
            } else {
                scalarValue =
                    UInt32(token)
            }

            if let scalarValue,
               let scalar =
                UnicodeScalar(
                    scalarValue
                ) {
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

        let normalized =
            query.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !normalized.isEmpty
        else {
            return []
        }

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
                value: normalized
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

        return ChordWikiSearchParser
            .parse(html: html)
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
            "text/html,application/xhtml+xml",
            forHTTPHeaderField:
                "Accept"
        )

        request.setValue(
            "GuitarToolsMac/0.3 (+https://github.com/mirinnano/guitar)",
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

        return decodeHTMLText(
            ns.substring(
                with:
                    match.range(at: 1)
            )
        )
    }

    private func decodeHTMLText(
        _ value: String
    ) -> String {
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

private extension String {

    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
