package dev.mirinnano.guitartools.chordwiki

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.jsoup.Jsoup
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI
import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

class ChordWikiClient {

    suspend fun search(
        query: String
    ): List<ChordWikiSearchResult> =
        withContext(Dispatchers.IO) {
            val normalized = query.trim()

            if (normalized.isEmpty()) {
                return@withContext emptyList()
            }

            val encoded =
                URLEncoder.encode(
                    normalized,
                    StandardCharsets.UTF_8
                )

            val html = request(
                BASE_URL +
                    "/wiki.cgi?c=search&q=" +
                    encoded
            )

            parseSearchResults(html)
        }

    suspend fun loadSong(
        result: ChordWikiSearchResult
    ): ChordWikiSong =
        withContext(Dispatchers.IO) {
            val encodedTitle =
                URLEncoder.encode(
                    result.title,
                    StandardCharsets.UTF_8
                )

            val html = request(
                BASE_URL +
                    "/wiki.cgi?c=edit&t=" +
                    encodedTitle
            )

            val source =
                extractChordSource(html)
                    ?: throw IOException(
                        "ChordWikiの譜面データを取得できませんでした"
                    )

            ChordWikiParser.parse(
                source = source,
                fallbackTitle = result.title,
                sourceUrl = result.url
            )
        }

    private fun request(
        url: String
    ): String {
        val connection =
            (
                URI(url)
                    .toURL()
                    .openConnection()
                    as HttpURLConnection
                ).apply {
                requestMethod = "GET"
                connectTimeout = 10_000
                readTimeout = 10_000
                instanceFollowRedirects = true
                setRequestProperty(
                    "Accept",
                    "text/html,application/xhtml+xml"
                )
                setRequestProperty(
                    "Accept-Language",
                    "ja,en;q=0.7"
                )
                setRequestProperty(
                    "User-Agent",
                    "GuitarTools/0.2 (+https://github.com/mirinnano/guitar)"
                )
            }

        try {
            val status =
                connection.responseCode

            if (status !in 200..299) {
                throw IOException(
                    "ChordWiki HTTP " + status
                )
            }

            return connection.inputStream
                .bufferedReader(
                    StandardCharsets.UTF_8
                )
                .use {
                    it.readText()
                }
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        private const val BASE_URL =
            "https://ja.chordwiki.org"

        internal fun parseSearchResults(
            html: String
        ): List<ChordWikiSearchResult> {
            val document =
                Jsoup.parse(
                    html,
                    BASE_URL
                )

            val seen =
                linkedSetOf<String>()

            return buildList {
                document
                    .select("a[href]")
                    .forEach { element ->
                        val absolute =
                            element.absUrl("href")
                                .ifBlank {
                                    return@forEach
                                }

                        if (
                            !absolute.startsWith(
                                BASE_URL
                            )
                        ) {
                            return@forEach
                        }

                        val uri =
                            runCatching {
                                URI(absolute)
                            }.getOrNull()
                                ?: return@forEach

                        val path =
                            uri.path.orEmpty()

                        if (
                            path != "/wiki.cgi" &&
                            !path.startsWith("/wiki/")
                        ) {
                            return@forEach
                        }

                        val command =
                            queryParameter(
                                uri.rawQuery,
                                "c"
                            )

                        if (
                            command in setOf(
                                "search",
                                "edit",
                                "diff",
                                "new",
                                "history",
                                "infoedit"
                            )
                        ) {
                            return@forEach
                        }

                        val title =
                            titleFromUri(uri)
                                ?.trim()
                                ?.takeIf {
                                    it.isNotEmpty()
                                }
                                ?: return@forEach

                        if (!seen.add(title)) {
                            return@forEach
                        }

                        add(
                            ChordWikiSearchResult(
                                title = title,
                                url =
                                    canonicalViewUrl(
                                        title
                                    )
                            )
                        )
                    }
            }.take(30)
        }

        internal fun extractChordSource(
            html: String
        ): String? =
            Jsoup.parse(html)
                .selectFirst(
                    "textarea[name=chord]"
                )
                ?.wholeText()
                ?.takeIf {
                    it.isNotBlank()
                }

        private fun titleFromUri(
            uri: URI
        ): String? {
            val path =
                uri.path.orEmpty()

            if (path.startsWith("/wiki/")) {
                val encoded =
                    uri.rawPath
                        .substringAfterLast("/")

                return decode(encoded)
            }

            if (path == "/wiki.cgi") {
                return queryParameter(
                    uri.rawQuery,
                    "t"
                )
            }

            return null
        }

        private fun queryParameter(
            rawQuery: String?,
            name: String
        ): String? =
            rawQuery
                ?.split("&")
                ?.firstOrNull {
                    it.substringBefore("=") == name
                }
                ?.substringAfter(
                    "=",
                    ""
                )
                ?.let(::decode)

        private fun decode(
            value: String
        ): String =
            URLDecoder.decode(
                value,
                StandardCharsets.UTF_8
            )

        private fun canonicalViewUrl(
            title: String
        ): String =
            BASE_URL +
                "/wiki/" +
                URLEncoder.encode(
                    title,
                    StandardCharsets.UTF_8
                )
    }
}
