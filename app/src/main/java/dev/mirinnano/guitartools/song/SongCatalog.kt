package dev.mirinnano.guitartools.song

data class SongSearchResult(
    val id: String,
    val title: String,
    val artist: String,
    val durationMs: Long? = null,
    val bpm: Int? = null,
    val timeSignature: String? = null,
    val musicalKey: String? = null,
    val sourceName: String,
    val sourceUrl: String? = null
)

interface SongSearchProvider {
    suspend fun search(
        query: String
    ): List<SongSearchResult>
}

data class ChordSourceLink(
    val label: String,
    val url: String
)
