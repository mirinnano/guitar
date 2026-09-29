package dev.mirinnano.guitartools.song

import java.net.URLEncoder
import java.nio.charset.StandardCharsets

object ExternalChordLinks {

    fun forSong(
        title: String,
        artist: String
    ): List<ChordSourceLink> {
        val query =
            listOf(title, artist)
                .filter {
                    it.isNotBlank()
                }
                .joinToString(" ")

        val encodedQuery =
            URLEncoder.encode(
                query,
                StandardCharsets.UTF_8
            )

        val chordWikiTitle =
            URLEncoder.encode(
                title,
                StandardCharsets.UTF_8
            ).replace("+", "%20")

        return listOf(
            ChordSourceLink(
                label = "U-FRETで探す",
                url =
                    "https://www.ufret.jp/search.php?key=$encodedQuery"
            ),
            ChordSourceLink(
                label = "ChordWikiで開く",
                url =
                    "https://ja.chordwiki.org/wiki/$chordWikiTitle"
            )
        )
    }
}
