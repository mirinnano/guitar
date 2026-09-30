package dev.mirinnano.guitartools.chordwiki

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChordSyncMapTest {

    @Test
    fun oneAnchorLocksOffsetButKeepsNominalTempo() {
        val map =
            ChordSyncMap(
                anchors =
                    listOf(
                        anchor(
                            beat = 8f,
                            ms = 10_000L
                        )
                    ),
                fallbackBpm = 120,
                fallbackOffsetMs = 0L,
                totalBeats = 64f
            )

        assertEquals(
            10f,
            map.beatForVideoPosition(
                11_000L
            ),
            0.001f
        )
    }

    @Test
    fun twoAnchorsCorrectGlobalTempo() {
        val map =
            ChordSyncMap(
                anchors =
                    listOf(
                        anchor(
                            beat = 0f,
                            ms = 2_000L
                        ),
                        anchor(
                            beat = 16f,
                            ms = 11_600L
                        )
                    ),
                fallbackBpm = 120,
                fallbackOffsetMs = 0L,
                totalBeats = 64f
            )

        assertEquals(
            8f,
            map.beatForVideoPosition(
                6_800L
            ),
            0.001f
        )

        assertEquals(
            6_800L,
            map.videoPositionForBeat(
                8f
            )
        )
    }

    @Test
    fun threeAnchorsUsePiecewiseTempo() {
        val map =
            ChordSyncMap(
                anchors =
                    listOf(
                        anchor(0f, 0L),
                        anchor(8f, 4_000L),
                        anchor(16f, 10_000L)
                    ),
                fallbackBpm = 120,
                fallbackOffsetMs = 0L,
                totalBeats = 32f
            )

        assertEquals(
            12f,
            map.beatForVideoPosition(
                7_000L
            ),
            0.001f
        )

        assertEquals(
            80f,
            map.localBpmAtBeat(
                12f
            ),
            0.01f
        )
    }

    @Test
    fun rejectsCrossingAnchor() {
        val anchors =
            listOf(
                anchor(4f, 4_000L),
                anchor(12f, 8_000L)
            )

        assertFalse(
            ChordSyncMap.canInsert(
                anchors,
                anchor(8f, 9_000L)
            )
        )

        assertTrue(
            ChordSyncMap.canInsert(
                anchors,
                anchor(8f, 6_000L)
            )
        )
    }

    @Test
    fun upsertReplacesSameBeat() {
        val result =
            ChordSyncMap.upsert(
                listOf(
                    anchor(4f, 4_000L)
                ),
                anchor(4f, 4_250L)
            )

        assertEquals(1, result.size)
        assertEquals(
            4_250L,
            result.first()
                .videoPositionMs
        )
    }

    private fun anchor(
        beat: Float,
        ms: Long
    ): ChordSyncAnchor =
        ChordSyncAnchor(
            chartBeat = beat,
            videoPositionMs = ms,
            symbol = "C",
            lineIndex = 0,
            segmentIndex = 0
        )
}
