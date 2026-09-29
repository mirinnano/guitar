package dev.mirinnano.guitartools.song

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

class MusicBrainzSongProvider : SongSearchProvider {

    private val requestMutex = Mutex()
    private var lastRequestAtMs = 0L

    override suspend fun search(
        query: String
    ): List<SongSearchResult> {
        if (query.isBlank()) {
            return emptyList()
        }

        return requestMutex.withLock {
            val now = System.currentTimeMillis()
            val waitMs =
                (1_050L - (now - lastRequestAtMs))
                    .coerceAtLeast(0L)

            if (waitMs > 0L) {
                delay(waitMs)
            }

            lastRequestAtMs =
                System.currentTimeMillis()

            withContext(Dispatchers.IO) {

            val encoded = URLEncoder.encode(
                query,
                StandardCharsets.UTF_8
            )

            val url =
                URI(
                    "https://musicbrainz.org/ws/2/recording/?query=$encoded&fmt=json&limit=20"
                ).toURL()

            val connection =
                (url.openConnection() as HttpURLConnection)
                    .apply {
                        requestMethod = "GET"
                        connectTimeout = 8_000
                        readTimeout = 8_000
                        setRequestProperty(
                            "Accept",
                            "application/json"
                        )
                        setRequestProperty(
                            "User-Agent",
                            "GuitarTools/0.2 (https://github.com/mirinnano/guitar)"
                        )
                    }

            try {
                val body =
                    connection.inputStream
                        .bufferedReader()
                        .use { it.readText() }

                val root = JSONObject(body)
                val recordings =
                    root.optJSONArray("recordings")
                        ?: return@withContext emptyList()

                buildList {
                    for (
                        index in
                        0 until recordings.length()
                    ) {
                        val item =
                            recordings.optJSONObject(index)
                                ?: continue

                        val artists =
                            item.optJSONArray("artist-credit")

                        val artistName =
                            if (
                                artists != null &&
                                artists.length() > 0
                            ) {
                                artists
                                    .optJSONObject(0)
                                    ?.optString("name")
                                    .orEmpty()
                            } else {
                                ""
                            }

                        add(
                            SongSearchResult(
                                id =
                                    item.optString("id"),
                                title =
                                    item.optString("title"),
                                artist =
                                    artistName,
                                durationMs =
                                    item.optLong(
                                        "length"
                                    ).takeIf {
                                        it > 0L
                                    },
                                sourceName =
                                    "MusicBrainz",
                                sourceUrl =
                                    item.optString("id")
                                        .takeIf {
                                            it.isNotBlank()
                                        }
                                        ?.let {
                                            "https://musicbrainz.org/recording/$it"
                                        }
                            )
                        )
                    }
                }
            } finally {
                connection.disconnect()
            }
            }
        }
    }
}
