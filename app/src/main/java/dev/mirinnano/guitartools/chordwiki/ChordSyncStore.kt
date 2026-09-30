package dev.mirinnano.guitartools.chordwiki

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

class ChordSyncStore(
    context: Context
) {

    private val preferences =
        context.applicationContext
            .getSharedPreferences(
                "chordwiki_sync",
                Context.MODE_PRIVATE
            )

    fun load(
        song: ChordWikiSong
    ): List<ChordSyncAnchor> {
        val raw =
            preferences.getString(
                key(song),
                null
            )
                ?: return emptyList()

        return runCatching {
            val array =
                JSONArray(raw)

            buildList {
                for (
                    index in
                    0 until array.length()
                ) {
                    val item =
                        array.getJSONObject(
                            index
                        )

                    add(
                        ChordSyncAnchor(
                            chartBeat =
                                item.getDouble(
                                    "beat"
                                ).toFloat(),
                            videoPositionMs =
                                item.getLong(
                                    "positionMs"
                                ),
                            symbol =
                                item.optString(
                                    "symbol",
                                    ""
                                ),
                            lineIndex =
                                item.optInt(
                                    "line",
                                    -1
                                ),
                            segmentIndex =
                                item.optInt(
                                    "segment",
                                    -1
                                )
                        )
                    )
                }
            }.sortedBy {
                it.chartBeat
            }
        }.getOrElse {
            emptyList()
        }
    }

    fun save(
        song: ChordWikiSong,
        anchors: List<ChordSyncAnchor>
    ) {
        val array =
            JSONArray()

        anchors
            .sortedBy {
                it.chartBeat
            }
            .forEach { anchor ->
                array.put(
                    JSONObject()
                        .put(
                            "beat",
                            anchor.chartBeat
                        )
                        .put(
                            "positionMs",
                            anchor.videoPositionMs
                        )
                        .put(
                            "symbol",
                            anchor.symbol
                        )
                        .put(
                            "line",
                            anchor.lineIndex
                        )
                        .put(
                            "segment",
                            anchor.segmentIndex
                        )
                )
            }

        preferences
            .edit()
            .putString(
                key(song),
                array.toString()
            )
            .apply()
    }

    fun clear(
        song: ChordWikiSong
    ) {
        preferences
            .edit()
            .remove(
                key(song)
            )
            .apply()
    }

    private fun key(
        song: ChordWikiSong
    ): String =
        song.sourceUrl +
            "#" +
            song.youtubeVideoId.orEmpty()
}
