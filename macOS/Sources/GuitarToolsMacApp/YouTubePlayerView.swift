import SwiftUI
import WebKit

@MainActor
final class YouTubePlayerController:
    ObservableObject {

    weak var webView:
        WKWebView?

    func play() {
        evaluate(
            "window.guitarToolsPlay && window.guitarToolsPlay();"
        )
    }

    func pause() {
        evaluate(
            "window.guitarToolsPause && window.guitarToolsPause();"
        )
    }

    func seek(
        toMilliseconds value:
            Int64
    ) {
        let seconds =
            Double(
                max(value, 0)
            ) /
            1_000

        evaluate(
            "window.guitarToolsSeek && window.guitarToolsSeek(\(seconds));"
        )
    }

    private func evaluate(
        _ script: String
    ) {
        webView?
            .evaluateJavaScript(
                script
            )
    }
}

struct YouTubePlayerView:
    NSViewRepresentable {

    let videoID: String

    @ObservedObject
    var controller:
        YouTubePlayerController

    let onProgress:
        (
            _ positionMs: Int64,
            _ durationMs: Int64,
            _ playing: Bool,
            _ playbackRate:
                Double
        ) -> Void

    let onUnavailable:
        () -> Void

    func makeCoordinator()
        -> Coordinator {
        Coordinator(
            onProgress:
                onProgress,
            onUnavailable:
                onUnavailable
        )
    }

    func makeNSView(
        context: Context
    ) -> WKWebView {
        let configuration =
            WKWebViewConfiguration()

        configuration
            .defaultWebpagePreferences
            .allowsContentJavaScript =
            true

        configuration
            .mediaTypesRequiringUserActionForPlayback =
            []

        configuration
            .userContentController
            .add(
                context.coordinator,
                name:
                    "guitarTools"
            )

        let view =
            WKWebView(
                frame: .zero,
                configuration:
                    configuration
            )

        controller.webView =
            view

        view.loadHTMLString(
            playerHTML(videoID),
            baseURL:
                URL(
                    string:
                        "https://www.youtube.com/"
                )
        )

        return view
    }

    func updateNSView(
        _ nsView: WKWebView,
        context: Context
    ) {
        controller.webView =
            nsView
    }

    static func dismantleNSView(
        _ nsView: WKWebView,
        coordinator: Coordinator
    ) {
        nsView
            .configuration
            .userContentController
            .removeScriptMessageHandler(
                forName:
                    "guitarTools"
            )

        nsView.stopLoading()
    }

    final class Coordinator:
        NSObject,
        WKScriptMessageHandler {

        let onProgress:
            (
                Int64,
                Int64,
                Bool,
                Double
            ) -> Void

        let onUnavailable:
            () -> Void

        init(
            onProgress:
                @escaping (
                    Int64,
                    Int64,
                    Bool,
                    Double
                ) -> Void,
            onUnavailable:
                @escaping () -> Void
        ) {
            self.onProgress =
                onProgress
            self.onUnavailable =
                onUnavailable
        }

        func userContentController(
            _ userContentController:
                WKUserContentController,
            didReceive message:
                WKScriptMessage
        ) {
            guard
                let object =
                    message.body
                    as? [String: Any],
                let type =
                    object["type"]
                    as? String
            else {
                return
            }

            if type == "error" {
                onUnavailable()
                return
            }

            guard
                type == "progress"
            else {
                return
            }

            let position =
                (
                    object[
                        "positionMs"
                    ] as? NSNumber
                )?
                .int64Value
                ?? 0

            let duration =
                (
                    object[
                        "durationMs"
                    ] as? NSNumber
                )?
                .int64Value
                ?? 0

            let playing =
                (
                    object[
                        "playing"
                    ] as? NSNumber
                )?
                .boolValue
                ?? false

            let rate =
                (
                    object[
                        "playbackRate"
                    ] as? NSNumber
                )?
                .doubleValue
                ?? 1

            onProgress(
                position,
                duration,
                playing,
                rate
            )
        }
    }

    private func playerHTML(
        _ videoID: String
    ) -> String {
        let safe =
            videoID.filter {
                $0.isLetter ||
                $0.isNumber ||
                $0 == "_" ||
                $0 == "-"
            }

        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <style>
            html,body,#player {
              width:100%;
              height:100%;
              margin:0;
              padding:0;
              background:transparent;
              overflow:hidden;
            }
          </style>
        </head>
        <body>
          <div id="player"></div>
          <script>
            var player = null;
            var ready = false;

            window.guitarToolsPlay = function() {
              if (ready && player) player.playVideo();
            };

            window.guitarToolsPause = function() {
              if (ready && player) player.pauseVideo();
            };

            window.guitarToolsSeek = function(seconds) {
              if (ready && player) player.seekTo(seconds, true);
            };

            function send(payload) {
              try {
                window.webkit.messageHandlers.guitarTools.postMessage(payload);
              } catch (_) {}
            }

            function report() {
              if (!ready || !player) return;
              try {
                var state = player.getPlayerState();
                send({
                  type: 'progress',
                  positionMs: Math.round(player.getCurrentTime() * 1000),
                  durationMs: Math.round(player.getDuration() * 1000),
                  playing: state === YT.PlayerState.PLAYING,
                  playbackRate: player.getPlaybackRate() || 1
                });
              } catch (_) {}
            }

            function onYouTubeIframeAPIReady() {
              player = new YT.Player('player', {
                videoId: '\(safe)',
                playerVars: {
                  playsinline: 1,
                  controls: 1,
                  rel: 0,
                  enablejsapi: 1,
                  origin: 'https://www.youtube.com'
                },
                events: {
                  onReady: function() {
                    ready = true;
                    report();
                  },
                  onStateChange: report,
                  onError: function(event) {
                    send({
                      type: 'error',
                      code: event.data || -1
                    });
                  }
                }
              });
            }

            var tag = document.createElement('script');
            tag.src = 'https://www.youtube.com/iframe_api';
            document.head.appendChild(tag);

            setInterval(report, 100);
          </script>
        </body>
        </html>
        """
    }
}
