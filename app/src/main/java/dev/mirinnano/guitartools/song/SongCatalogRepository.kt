package dev.mirinnano.guitartools.song

import dev.mirinnano.guitartools.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

class GetSongBpmProvider(
    private val apiKey: String =
        BuildConfig.GETSONGBPM_API_KEY
) : SongSearchProvider {

    override suspend fun search(
        query: String
    ): List<SongSearchResult> =
        withContext(Dispatchers.IO) {
            if (
                query.isBlank() ||
                apiKey.isBlank()
            ) {
                return@withContext emptyList()
            }

            val lookup =
                URLEncoder.encode(
                    "song:$query",
                    StandardCharsets.UTF_8
                )

            val key =
                URLEncoder.encode(
                    apiKey,
                    StandardCharsets.UTF_8
                )

            val url =
                URI(
                    "https://api.getsong.co/search/?api_key=$key&type=both&lookup=$lookup&limit=20"
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
                    }

            try {
                val body =
                    connection.inputStream
                        .bufferedReader()
                        .use { it.readText() }

                parseResults(body)
            } finally {
                connection.disconnect()
            }
        }

    private fun parseResults(
        body: String
    ): List<SongSearchResult> {
        val array =
            when {
                body.trimStart()
                    .startsWith("[") ->
                    JSONArray(body)

                else -> {
                    val root = JSONObject(body)
                    root.optJSONArray("search")
                        ?: root.optJSONArray("songs")
                        ?: root.optJSONArray("results")
                        ?: JSONArray()
                }
            }

        return buildList {
            for (
                index in
                0 until array.length()
            ) {
                val item =
                    array.optJSONObject(index)
                        ?: continue

                val artistObject =
                    item.optJSONObject("artist")

                val artistName =
                    artistObject
                        ?.optString("name")
                        .orEmpty()

                val sourceUrl =
                    item.optString("uri")
                        .takeIf {
                            it.startsWith("http")
                        }

                add(
                    SongSearchResult(
                        id =
                            item.optString("id"),
                        title =
                            item.optString("title"),
                        artist =
                            artistName,
                        bpm =
                            item.optString("tempo")
                                .toIntOrNull(),
                        timeSignature =
                            item.optString("time_sig")
                                .takeIf {
                                    it.isNotBlank()
                                },
                        musicalKey =
                            item.optString("key_of")
                                .takeIf {
                                    it.isNotBlank()
                                },
                        sourceName =
                            "GetSongBPM",
                        sourceUrl = sourceUrl
                    )
                )
            }
        }
    }
}

class SongCatalogRepository(
    private val bpmProvider:
        SongSearchProvider =
        GetSongBpmProvider(),
    private val metadataProvider:
        SongSearchProvider =
        MusicBrainzSongProvider()
) : SongSearchProvider {

    override suspend fun search(
        query: String
    ): List<SongSearchResult> {
        val withTempo =
            runCatching {
                bpmProvider.search(query)
            }.getOrDefault(emptyList())

        if (withTempo.isNotEmpty()) {
            return withTempo
        }

        return metadataProvider.search(query)
    }
}
