import Foundation
import WebKit

@MainActor
enum ChordWikiSearchWebLoader {

    static func search(
        query: String
    ) async throws -> [ChordWikiSearchResult] {
        try await ChordWikiSearchWebSession()
            .search(query: query)
    }
}

@MainActor
private final class ChordWikiSearchWebSession:
    NSObject,
    WKNavigationDelegate {

    private var webView: WKWebView?
    private var continuation:
        CheckedContinuation<[ChordWikiSearchResult], Error>?
    private var timeoutTask: Task<Void, Never>?
    private var extractionTask: Task<Void, Never>?

    func search(
        query: String
    ) async throws -> [ChordWikiSearchResult] {
        var components = URLComponents(
            string: "https://ja.chordwiki.org/search.html"
        )!
        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]

        guard let url = components.url else {
            throw ChordWikiMacClient.ClientError.invalidURL
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
            configuration: configuration
        )
        self.webView = webView
        webView.navigationDelegate = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            timeoutTask = Task { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: 20_000_000_000)
                } catch {
                    return
                }

                self?.finish(
                    .failure(
                        ChordWikiMacClient.ClientError.searchTimedOut
                    )
                )
            }
            webView.load(URLRequest(url: url))
        }
    }

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation?
    ) {
        guard continuation != nil, extractionTask == nil else {
            return
        }

        extractionTask = Task { [weak self, weak webView] in
            guard let self, let webView else {
                return
            }

            do {
                let value = try await webView.callAsyncJavaScript(
                    Self.resultURLsJavaScript,
                    arguments: [:],
                    in: nil,
                    contentWorld: .page
                )
                guard let json = value as? String else {
                    throw ChordWikiMacClient.ClientError.invalidSearchResponse
                }
                guard json != "__SEARCH_TIMED_OUT__" else {
                    throw ChordWikiMacClient.ClientError.searchTimedOut
                }

                let resultURLs = try JSONDecoder().decode(
                    [String].self,
                    from: Data(json.utf8)
                )
                self.finish(
                    .success(
                        ChordWikiSearchParser.parse(
                            resultURLs: resultURLs
                        )
                    )
                )
            } catch {
                self.finish(.failure(error))
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation?,
        withError error: Error
    ) {
        finish(.failure(error))
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation?,
        withError error: Error
    ) {
        finish(.failure(error))
    }

    private func finish(
        _ result: Result<[ChordWikiSearchResult], Error>
    ) {
        guard let continuation else {
            return
        }

        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        extractionTask?.cancel()
        extractionTask = nil
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        webView = nil
        continuation.resume(with: result)
    }

    private static let resultURLsJavaScript = """
    const deadline = Date.now() + 15000;
    while (Date.now() < deadline) {
      const urls = [...document.querySelectorAll(
        ".gsc-results .gsc-webResult .gs-title a[href]"
      )]
        .map((anchor) => anchor.href)
        .filter((url) => url.startsWith("https://ja.chordwiki.org/wiki/"));
      if (urls.length > 0) return JSON.stringify(urls);
      if (document.querySelector(".gsc-results .gs-no-results-result")) return "[]";
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    return "__SEARCH_TIMED_OUT__";
    """
}
