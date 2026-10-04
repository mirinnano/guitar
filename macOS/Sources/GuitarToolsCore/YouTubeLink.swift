import Foundation

public enum YouTubeLink {
    /// Finds a supported YouTube video URL in chart source, HTML, or pasted text.
    public static func videoID(in text: String) -> String? {
        let decoded = text.replacingOccurrences(of: "&amp;", with: "&")
        let urlPattern = #"https?://[^\s<>"'\}]+"#
        let regex = try! NSRegularExpression(
            pattern: urlPattern,
            options: [.caseInsensitive]
        )
        let ns = decoded as NSString

        for match in regex.matches(in: decoded, range: NSRange(location: 0, length: ns.length)) {
            guard let url = URL(string: ns.substring(with: match.range)),
                  let host = url.host?.lowercased() else {
                continue
            }
            let path = url.path.split(separator: "/").map(String.init)
            let candidate: String?
            switch host {
            case "youtu.be", "www.youtu.be":
                candidate = path.first
            case "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com":
                if path.first == "watch" {
                    candidate = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "v" })?.value
                } else if path.count == 2, ["embed", "shorts", "live"].contains(path[0]) {
                    candidate = path[1]
                } else {
                    candidate = nil
                }
            case "youtube-nocookie.com", "www.youtube-nocookie.com":
                candidate = path.count == 2 && path[0] == "embed" ? path[1] : nil
            default:
                candidate = nil
            }
            if let candidate, isValid(candidate) {
                return candidate
            }
        }

        let directive = try! NSRegularExpression(
            pattern: #"\{(?:youtube|yt)\s*:\s*([A-Za-z0-9_-]{11})\s*\}"#,
            options: [.caseInsensitive]
        )
        if let match = directive.firstMatch(in: decoded, range: NSRange(location: 0, length: ns.length)) {
            return ns.substring(with: match.range(at: 1))
        }
        return nil
    }

    private static func isValid(_ value: String) -> Bool {
        value.utf8.count == 11 && value.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) ||
            (48...57).contains($0) || $0 == 45 || $0 == 95
        }
    }
}
