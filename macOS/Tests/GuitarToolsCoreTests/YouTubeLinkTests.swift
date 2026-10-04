import XCTest
@testable import GuitarToolsCore

final class YouTubeLinkTests: XCTestCase {
    func testSupportedVideoLinksAndChartDirective() {
        let id = "j7CDb610Bg0"
        for text in [
            "{MV>http://www.youtube.com/watch?v=\(id)}",
            "https://www.youtube.com/watch?feature=share&v=\(id)&t=10",
            "<a href=\"https://www.youtube.com/watch?feature=share&amp;v=\(id)\">YouTube</a>",
            "https://youtu.be/\(id)?si=example",
            "https://m.youtube.com/watch?v=\(id)",
            "https://music.youtube.com/watch?v=\(id)",
            "https://www.youtube.com/shorts/\(id)",
            "https://www.youtube.com/live/\(id)",
            "https://www.youtube-nocookie.com/embed/\(id)",
            "{youtube: \(id)}"
        ] {
            XCTAssertEqual(YouTubeLink.videoID(in: text), id, text)
        }
    }

    func testRejectsInvalidLinks() {
        for text in [
            "https://youtube.com.evil.test/watch?v=j7CDb610Bg0",
            "https://example.com/watch?v=j7CDb610Bg0",
            "https://www.youtube.com/watch?v=short",
            "https://youtu.be/j7CDb610Bg0extra",
            "https://www.youtube.com/playlist?list=j7CDb610Bg0",
            "javascript:alert(1)"
        ] {
            XCTAssertNil(YouTubeLink.videoID(in: text), text)
        }
    }

    func testPageVideoFallbackDoesNotChangeChartContent() {
        let chart = ChordChartParser.parse(
            "{title:Song}\n[C]Hello",
            fallbackTitle: "Song",
            linkedMediaHTML: "<a href=\"https://www.youtube.com/watch?v=j7CDb610Bg0\">YouTube</a>"
        )
        XCTAssertEqual(chart.youtubeVideoID, "j7CDb610Bg0")
        XCTAssertEqual(chart.lines.count, 1)
        XCTAssertEqual(chart.lines.first?.segments.first?.chord, "C")
    }

    func testSourceLinkTakesPriorityOverPageFallback() {
        let chart = ChordChartParser.parse(
            "{youtube: -htsLEAtaKs}\n[C]Hello",
            fallbackTitle: "Song",
            linkedMediaHTML: "https://youtu.be/j7CDb610Bg0"
        )
        XCTAssertEqual(chart.youtubeVideoID, "-htsLEAtaKs")
    }
}
