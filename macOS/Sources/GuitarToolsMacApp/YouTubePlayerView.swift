import SwiftUI
import WebKit

@MainActor
final class YouTubePlayerController:
    ObservableObject {

    weak var webView:
        WKWebView?

    private(set) var isReady = false
    @Published private(set) var availablePlaybackRates: [Double] = [1]
    private var playWhenReady = false
    private var pendingSeekMs: Int64?
    private var pendingPlaybackRate: Double?

    func reset() {
        isReady = false
        playWhenReady = false
        pendingSeekMs = nil
        pendingPlaybackRate = nil
    }

    func playerReady(rates: [Double] = [1]) {
        isReady = true
        availablePlaybackRates = rates.isEmpty ? [1] : rates.sorted()
        if let position = pendingSeekMs {
            pendingSeekMs = nil
            seek(toMilliseconds: position)
        }
        if let rate = pendingPlaybackRate {
            pendingPlaybackRate = nil
            setPlaybackRate(rate)
        }
        if playWhenReady {
            playWhenReady = false
            play()
        }
    }

    func play() {
        guard isReady else {
            playWhenReady = true
            return
        }
        evaluate(
            "window.guitarToolsPlay && window.guitarToolsPlay();"
        )
    }

    func pause() {
        playWhenReady = false
        evaluate(
            "window.guitarToolsPause && window.guitarToolsPause();"
        )
    }

    func seek(
        toMilliseconds value:
            Int64
    ) {
        guard isReady else {
            pendingSeekMs = max(value, 0)
            return
        }
        let seconds =
            Double(
                max(value, 0)
            ) /
            1_000

        evaluate(
            "window.guitarToolsSeek && window.guitarToolsSeek(\(seconds));"
        )
    }

    func setPlaybackRate(_ rate: Double) {
        guard rate.isFinite, rate > 0 else { return }
        guard isReady else {
            pendingPlaybackRate = rate
            return
        }
        guard availablePlaybackRates.contains(rate) else { return }
        evaluate("window.guitarToolsRate && window.guitarToolsRate(\(rate));")
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

    var initialPositionMs: Int64 = 0
    var initialPlaybackRate: Double = 1

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
            controller: controller,
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

        controller.reset()
        if initialPositionMs > 0 {
            controller.seek(toMilliseconds: initialPositionMs)
        }
        controller.setPlaybackRate(initialPlaybackRate)
        controller.webView =
            view

        view.loadHTMLString(
            playerHTML(videoID),
            baseURL: URL(string: playerOrigin)
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
        // Tear down the iframe too: stopping navigation alone does not stop audio.
        nsView.loadHTMLString("", baseURL: nil)
        if coordinator.controller.webView === nsView {
            coordinator.controller.reset()
            coordinator.controller.webView = nil
        }
    }

    final class Coordinator:
        NSObject,
        WKScriptMessageHandler {

        let controller: YouTubePlayerController

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
            controller: YouTubePlayerController,
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
            self.controller = controller
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

            if type == "ready" {
                controller.playerReady(rates: object["rates"] as? [Double] ?? [1])
                return
            }

            if type == "error" {
                controller.reset()
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

    private var playerOrigin: String {
        let identifier = Bundle.main.bundleIdentifier ?? "dev.mirinnano.guitartools.mac"
        return "https://\(identifier.lowercased())"
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
          <meta name="referrer" content="strict-origin-when-cross-origin">
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
            var pauseAfterSeek = false;
            var seekTarget = null;

            window.guitarToolsPlay = function() {
              pauseAfterSeek = false;
              if (ready && player) player.playVideo();
            };

            window.guitarToolsPause = function() {
              if (ready && player) player.pauseVideo();
            };

            window.guitarToolsSeek = function(seconds) {
              if (ready && player) {
                pauseAfterSeek = player.getPlayerState() !== YT.PlayerState.PLAYING;
                seekTarget = seconds;
                player.seekTo(seconds, true);
                if (pauseAfterSeek) player.pauseVideo();
              }
            };
            window.guitarToolsRate = function(rate) {
              if (ready && player) player.setPlaybackRate(rate);
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
                if (pauseAfterSeek && state === YT.PlayerState.PAUSED &&
                    Math.abs(player.getCurrentTime() - seekTarget) < 1) {
                  pauseAfterSeek = false;
                }
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
                  autoplay: 0,
                  playsinline: 1,
                  controls: 1,
                  rel: 0,
                  enablejsapi: 1,
                  origin: '\(playerOrigin)'
                },
                events: {
                  onReady: function() {
                    ready = true;
                    send({type: 'ready', rates: player.getAvailablePlaybackRates()});
                    report();
                  },
                  onStateChange: function(event) {
                    if (pauseAfterSeek && event.data === YT.PlayerState.PLAYING) {
                      pauseAfterSeek = false;
                      player.pauseVideo();
                    }
                    report();
                  },
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
