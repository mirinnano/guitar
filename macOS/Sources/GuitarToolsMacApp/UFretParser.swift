import Foundation
import GuitarToolsCore

enum UFretSearchParser {
    private static let baseURL = URL(string: "https://www.ufret.jp")!

    static func searchURL(query: String) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/search.php"
        components.queryItems = [URLQueryItem(name: "key", value: query)]
        // PHP treats a literal '+' in a query as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }

    static func canonicalSongURL(from url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              ["ufret.jp", "www.ufret.jp"].contains(components.host?.lowercased() ?? ""),
              components.port == nil, components.user == nil, components.password == nil,
              components.path == "/song.php",
              let rawID = components.queryItems?.first(where: { $0.name == "data" })?.value,
              !rawID.isEmpty, rawID.allSatisfy({ "0123456789".contains($0) }),
              let id = UInt64(rawID), id > 0
        else { return nil }

        return URL(string: "https://www.ufret.jp/song.php?data=\(id)")
    }

    static func parse(html: String) throws -> [ChordWikiSearchResult] {
        let items = UFretHTML.contents(tag: "li", className: "c-list__item", in: html)
        var results: [ChordWikiSearchResult] = []
        var seen = Set<URL>()
        for item in items {
            guard let href = UFretHTML.capture(#"<a\b[^>]*\bhref\s*=\s*["']([^"']+)["']"#, in: item),
                  let absoluteURL = URL(string: UFretHTML.decode(href), relativeTo: baseURL)?.absoluteURL,
                  let url = canonicalSongURL(from: absoluteURL),
                  let titleHTML = UFretHTML.contents(tag: "p", className: "c-list__title", in: item).first
            else { continue }

            let title = UFretHTML.text(titleHTML)
            guard !title.isEmpty, seen.insert(url).inserted else { continue }
            let artist = UFretHTML.contents(tag: "p", className: "c-list__artist", in: item)
                .first.map(UFretHTML.text) ?? ""
            results.append(ChordWikiSearchResult(title: title, url: url, artist: artist))
            if results.count == 30 { break }
        }

        // Distinguish a genuine empty search from an error/challenge page returned with HTTP 200.
        let heading = UFretHTML.capture(#"<h1\b[^>]*>(.*?)</h1\s*>"#, in: html)
            .map(UFretHTML.text) ?? ""
        let hasResultsList = !UFretHTML.contents(tag: "ul", className: "c-list", in: html).isEmpty
        guard !results.isEmpty || heading.contains("検索結果") || !items.isEmpty || hasResultsList else {
            throw UFretMacClient.ClientError.invalidSearchResponse
        }
        return results
    }
}

enum UFretChartParser {
    static func parse(html: String, fallbackTitle: String, sourceURL: URL?) throws -> ChordChart {
        // Match the JSON array without treating ']' inside a quoted lyric as its end.
        // Decode data only; none of the remote page's JavaScript is executed.
        guard let json = UFretHTML.capture(
            #"\bufret_chord_datas\s*=\s*(\[(?:"(?:\\.|[^"\\])*"|[^\]"])*\])\s*;"#,
            in: html
        ), let rows = try? JSONDecoder().decode([String].self, from: Data(json.utf8)),
              rows.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        else { throw UFretMacClient.ClientError.missingChordSource }

        // U-FRET rows already carry CR suffixes. Keep one line per array entry, including blank rows.
        let source = rows.map { row in
            var line = row
            while line.last?.isNewline == true { line.removeLast() }
            return line
        }.joined(separator: "\n")
        let parsed = ChordChartParser.parse(source, fallbackTitle: fallbackTitle, sourceURL: sourceURL)
        let title = UFretHTML.contents(tag: "h1", className: "p-detail-head__ttl", in: html)
            .first.map(UFretHTML.text) ?? ""
        let artist = UFretHTML.contents(tag: "a", className: "p-detail-head__artist", in: html)
            .first.map(UFretHTML.text) ?? ""
        let bpm = UFretHTML.capture(#"\bdefaultBpm\s*=\s*("[0-9]+"|'[0-9]+'|[0-9]+)\s*;"#, in: html)
            .flatMap { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))) }
            .flatMap { (20...400).contains($0) ? $0 : nil }

        // Page-level videos include ads and feature tutorials, not necessarily this song.
        return ChordChart(
            sourceTitle: fallbackTitle,
            title: title.isEmpty ? fallbackTitle : title,
            artist: artist,
            bpm: bpm,
            lines: parsed.lines,
            sourceURL: sourceURL
        )
    }
}

private enum UFretHTML {
    static func capture(_ pattern: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html)
        else { return nil }
        return String(html[range])
    }

    static func contents(tag: String, className: String, in html: String) -> [String] {
        let name = NSRegularExpression.escapedPattern(for: className)
        let pattern = "<\(tag)\\b[^>]*\\bclass\\s*=\\s*[\"'](?:[^\"']*\\s)?\(name)(?:\\s[^\"']*)?[\"'][^>]*>(.*?)</\(tag)\\s*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        else { return [] }
        return regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
            Range(match.range(at: 1), in: html).map { String(html[$0]) }
        }
    }

    static func text(_ html: String) -> String {
        let value = html.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
        return decode(value).components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func decode(_ value: String) -> String {
        let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "]
        let regex = try! NSRegularExpression(pattern: #"&(#(?:[xX][0-9A-Fa-f]+|[0-9]+)|amp|lt|gt|quot|apos|nbsp);"#)
        var result = value
        for match in regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).reversed() {
            let ns = result as NSString
            let token = ns.substring(with: match.range(at: 1))
            let replacement: String?
            if token.hasPrefix("#") {
                let digits = String(token.dropFirst())
                let hex = digits.lowercased().hasPrefix("x")
                let number = UInt32(hex ? String(digits.dropFirst()) : digits, radix: hex ? 16 : 10)
                replacement = number.flatMap(UnicodeScalar.init).map(String.init)
            } else {
                replacement = named[token]
            }
            if let replacement {
                result = ns.replacingCharacters(in: match.range, with: replacement)
            }
        }
        return result
    }
}
