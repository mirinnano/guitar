package dev.mirinnano.guitartools.chordwiki

import kotlin.math.roundToLong

data class ChordSyncAnchor(
    val chartBeat: Float,
    val videoPositionMs: Long,
    val symbol: String,
    val lineIndex: Int,
    val segmentIndex: Int
)

enum class ChordSyncPrecision {
    BPM_ONLY,
    OFFSET_LOCKED,
    GLOBAL_WARP,
    PIECEWISE_WARP
}

data class ChordSyncStatus(
    val precision: ChordSyncPrecision,
    val anchorCount: Int,
    val localBpm: Float
)

class ChordSyncMap(
    anchors: List<ChordSyncAnchor>,
    private val fallbackBpm: Int,
    private val fallbackOffsetMs: Long,
    private val totalBeats: Float
) {

    val anchors: List<ChordSyncAnchor> =
        anchors
            .sortedBy { it.chartBeat }
            .distinctBy { it.chartBeat }

    val precision: ChordSyncPrecision
        get() =
            when (anchors.size) {
                0 ->
                    ChordSyncPrecision.BPM_ONLY
                1 ->
                    ChordSyncPrecision.OFFSET_LOCKED
                2 ->
                    ChordSyncPrecision.GLOBAL_WARP
                else ->
                    ChordSyncPrecision.PIECEWISE_WARP
            }

    fun beatForVideoPosition(
        positionMs: Long
    ): Float {
        if (totalBeats <= 0f) {
            return 0f
        }

        val raw =
            when (anchors.size) {
                0 ->
                    (
                        positionMs -
                            fallbackOffsetMs
                        ).toFloat() *
                        fallbackBpm /
                        60_000f

                1 -> {
                    val anchor =
                        anchors.first()

                    anchor.chartBeat +
                        (
                            positionMs -
                                anchor.videoPositionMs
                            ).toFloat() *
                        fallbackBpm /
                        60_000f
                }

                else ->
                    beatFromAnchors(
                        positionMs
                    )
            }

        return raw.coerceIn(
            0f,
            totalBeats
        )
    }

    fun videoPositionForBeat(
        beat: Float
    ): Long {
        val target =
            beat.coerceIn(
                0f,
                totalBeats
            )

        return when (anchors.size) {
            0 ->
                (
                    fallbackOffsetMs +
                        target *
                        60_000f /
                        fallbackBpm
                    ).roundToLong()

            1 -> {
                val anchor =
                    anchors.first()

                (
                    anchor.videoPositionMs +
                        (
                            target -
                                anchor.chartBeat
                            ) *
                        60_000f /
                        fallbackBpm
                    ).roundToLong()
            }

            else ->
                positionFromAnchors(target)
        }.coerceAtLeast(0L)
    }

    fun localBpmAtBeat(
        beat: Float
    ): Float {
        if (anchors.size < 2) {
            return fallbackBpm.toFloat()
        }

        val pair =
            anchorPairForBeat(
                beat.coerceIn(
                    0f,
                    totalBeats
                )
            )

        val deltaBeat =
            pair.second.chartBeat -
                pair.first.chartBeat

        val deltaMs =
            pair.second.videoPositionMs -
                pair.first.videoPositionMs

        if (
            deltaBeat <= 0f ||
            deltaMs <= 0L
        ) {
            return fallbackBpm.toFloat()
        }

        return deltaBeat *
            60_000f /
            deltaMs.toFloat()
    }

    fun statusAtBeat(
        beat: Float
    ): ChordSyncStatus =
        ChordSyncStatus(
            precision = precision,
            anchorCount = anchors.size,
            localBpm =
                localBpmAtBeat(beat)
        )

    private fun beatFromAnchors(
        positionMs: Long
    ): Float {
        val pair =
            anchorPairForPosition(
                positionMs
            )

        val deltaMs =
            pair.second.videoPositionMs -
                pair.first.videoPositionMs

        if (deltaMs <= 0L) {
            return pair.first.chartBeat
        }

        val ratio =
            (
                positionMs -
                    pair.first.videoPositionMs
                ).toFloat() /
                deltaMs.toFloat()

        return pair.first.chartBeat +
            (
                pair.second.chartBeat -
                    pair.first.chartBeat
                ) *
            ratio
    }

    private fun positionFromAnchors(
        beat: Float
    ): Long {
        val pair =
            anchorPairForBeat(beat)

        val deltaBeat =
            pair.second.chartBeat -
                pair.first.chartBeat

        if (deltaBeat <= 0f) {
            return pair.first.videoPositionMs
        }

        val ratio =
            (
                beat -
                    pair.first.chartBeat
                ) /
                deltaBeat

        return (
            pair.first.videoPositionMs +
                (
                    pair.second.videoPositionMs -
                        pair.first.videoPositionMs
                    ) *
                ratio
            ).roundToLong()
    }

    private fun anchorPairForPosition(
        positionMs: Long
    ): Pair<ChordSyncAnchor, ChordSyncAnchor> {
        if (
            positionMs <=
            anchors.first().videoPositionMs
        ) {
            return anchors[0] to
                anchors[1]
        }

        if (
            positionMs >=
            anchors.last().videoPositionMs
        ) {
            return anchors[
                anchors.lastIndex - 1
            ] to anchors.last()
        }

        val upperIndex =
            anchors.indexOfFirst {
                it.videoPositionMs >=
                    positionMs
            }

        return anchors[
            upperIndex - 1
        ] to anchors[upperIndex]
    }

    private fun anchorPairForBeat(
        beat: Float
    ): Pair<ChordSyncAnchor, ChordSyncAnchor> {
        if (
            beat <=
            anchors.first().chartBeat
        ) {
            return anchors[0] to
                anchors[1]
        }

        if (
            beat >=
            anchors.last().chartBeat
        ) {
            return anchors[
                anchors.lastIndex - 1
            ] to anchors.last()
        }

        val upperIndex =
            anchors.indexOfFirst {
                it.chartBeat >= beat
            }

        return anchors[
            upperIndex - 1
        ] to anchors[upperIndex]
    }

    companion object {
        fun canInsert(
            anchors: List<ChordSyncAnchor>,
            candidate: ChordSyncAnchor
        ): Boolean {
            val withoutSameBeat =
                anchors.filterNot {
                    nearlySameBeat(
                        it.chartBeat,
                        candidate.chartBeat
                    )
                }

            val previous =
                withoutSameBeat
                    .filter {
                        it.chartBeat <
                            candidate.chartBeat
                    }
                    .maxByOrNull {
                        it.chartBeat
                    }

            val next =
                withoutSameBeat
                    .filter {
                        it.chartBeat >
                            candidate.chartBeat
                    }
                    .minByOrNull {
                        it.chartBeat
                    }

            if (
                previous != null &&
                candidate.videoPositionMs <=
                previous.videoPositionMs
            ) {
                return false
            }

            if (
                next != null &&
                candidate.videoPositionMs >=
                next.videoPositionMs
            ) {
                return false
            }

            return true
        }

        fun upsert(
            anchors: List<ChordSyncAnchor>,
            candidate: ChordSyncAnchor
        ): List<ChordSyncAnchor> {
            require(
                canInsert(
                    anchors,
                    candidate
                )
            )

            return (
                anchors.filterNot {
                    nearlySameBeat(
                        it.chartBeat,
                        candidate.chartBeat
                    )
                } +
                    candidate
                ).sortedBy {
                it.chartBeat
            }
        }

        private fun nearlySameBeat(
            a: Float,
            b: Float
        ): Boolean =
            kotlin.math.abs(a - b) <
                0.0001f
    }
}
