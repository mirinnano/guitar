package dev.mirinnano.guitartools.ui.chordwiki

import android.annotation.SuppressLint
import android.graphics.Color
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView

class YouTubePlayerController {

    private var webView: WebView? = null

    internal fun attach(
        view: WebView
    ) {
        webView = view
    }

    fun play() {
        evaluate(
            "window.guitarToolsPlay && window.guitarToolsPlay();"
        )
    }

    fun pause() {
        evaluate(
            "window.guitarToolsPause && window.guitarToolsPause();"
        )
    }

    fun seekTo(
        positionMs: Long
    ) {
        val seconds =
            positionMs
                .coerceAtLeast(0L) /
                1000.0

        evaluate(
            "window.guitarToolsSeek && window.guitarToolsSeek($seconds);"
        )
    }

    internal fun release() {
        webView?.apply {
            removeJavascriptInterface(
                BRIDGE_NAME
            )
            stopLoading()
            loadUrl("about:blank")
            destroy()
        }
        webView = null
    }

    private fun evaluate(
        script: String
    ) {
        webView?.post {
            webView?.evaluateJavascript(
                script,
                null
            )
        }
    }

    private companion object {
        const val BRIDGE_NAME =
            "GuitarToolsBridge"
    }
}

@Composable
fun rememberYouTubePlayerController():
    YouTubePlayerController =
    remember {
        YouTubePlayerController()
    }

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun YouTubeMiniPlayer(
    videoId: String,
    controller: YouTubePlayerController,
    modifier: Modifier = Modifier,
    onProgress:
        (
            positionMs: Long,
            durationMs: Long,
            playing: Boolean,
            playbackRate: Float
        ) -> Unit,
    onUnavailable: () -> Unit
) {
    val latestProgress =
        rememberUpdatedState(onProgress)
    val latestUnavailable =
        rememberUpdatedState(onUnavailable)

    val bridge =
        remember(videoId) {
            YouTubeBridge(
                onProgress = {
                        positionMs,
                        durationMs,
                        playing,
                        playbackRate ->
                    latestProgress.value(
                        positionMs,
                        durationMs,
                        playing,
                        playbackRate
                    )
                },
                onUnavailable = {
                    latestUnavailable.value()
                }
            )
        }

    AndroidView(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 200.dp)
            .aspectRatio(16f / 9f),
        factory = { context ->
            WebView(context).apply {
                setBackgroundColor(
                    Color.TRANSPARENT
                )

                settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    mediaPlaybackRequiresUserGesture =
                        false
                    allowFileAccess = false
                    allowContentAccess = false
                    mixedContentMode =
                        android.webkit
                            .WebSettings
                            .MIXED_CONTENT_NEVER_ALLOW
                }

                webChromeClient =
                    WebChromeClient()

                webViewClient =
                    object :
                        WebViewClient() {
                        override fun shouldOverrideUrlLoading(
                            view: WebView?,
                            request:
                                WebResourceRequest?
                        ): Boolean {
                            if (
                                request == null ||
                                !request.isForMainFrame
                            ) {
                                return false
                            }

                            val host =
                                request.url.host
                                    .orEmpty()

                            return host !=
                                "www.youtube.com" &&
                                host !=
                                "youtube.com"
                        }
                    }

                addJavascriptInterface(
                    bridge,
                    "GuitarToolsBridge"
                )

                controller.attach(this)

                loadDataWithBaseURL(
                    "https://www.youtube.com/",
                    playerHtml(videoId),
                    "text/html",
                    "UTF-8",
                    null
                )
            }
        },
        update = { view ->
            controller.attach(view)
        }
    )

    DisposableEffect(controller, videoId) {
        onDispose {
            controller.release()
        }
    }
}

private class YouTubeBridge(
    private val onProgress:
        (
            positionMs: Long,
            durationMs: Long,
            playing: Boolean,
            playbackRate: Float
        ) -> Unit,
    private val onUnavailable: () -> Unit
) {
    @JavascriptInterface
    fun onProgress(
        positionMs: Long,
        durationMs: Long,
        playing: Boolean,
        playbackRate: Double
    ) {
        onProgress(
            positionMs,
            durationMs,
            playing,
            playbackRate.toFloat()
        )
    }

    @JavascriptInterface
    fun onError(
        code: Int
    ) {
        if (code != 0) {
            onUnavailable()
        }
    }
}

private fun playerHtml(
    videoId: String
): String {
    val safeId =
        videoId.filter {
            it.isLetterOrDigit() ||
                it == '_' ||
                it == '-'
        }

    return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
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
            var lastPlaying = false;

            window.guitarToolsPlay = function() {
              if (ready && player) player.playVideo();
            };

            window.guitarToolsPause = function() {
              if (ready && player) player.pauseVideo();
            };

            window.guitarToolsSeek = function(seconds) {
              if (ready && player) player.seekTo(seconds, true);
            };

            function report() {
              if (!ready || !player) return;
              try {
                var state = player.getPlayerState();
                var playing = state === YT.PlayerState.PLAYING;
                var position = Math.round(player.getCurrentTime() * 1000);
                var duration = Math.round(player.getDuration() * 1000);
                var playbackRate = player.getPlaybackRate() || 1.0;
                GuitarToolsBridge.onProgress(
                  position,
                  duration,
                  playing,
                  playbackRate
                );
                lastPlaying = playing;
              } catch (_) {}
            }

            function onYouTubeIframeAPIReady() {
              player = new YT.Player('player', {
                videoId: '$safeId',
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
                  onStateChange: function() {
                    report();
                  },
                  onError: function(event) {
                    GuitarToolsBridge.onError(
                      event.data || -1
                    );
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
    """.trimIndent()
}
