package dev.mirinnano.guitartools.ui.chordwiki

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.AssistChip
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedIconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.mirinnano.guitartools.R
import dev.mirinnano.guitartools.chordwiki.ChordSyncMap
import dev.mirinnano.guitartools.chordwiki.ChordSyncPrecision
import dev.mirinnano.guitartools.chordwiki.ChordWikiUiState

@Composable
fun ChordSyncCalibrationCard(
    state: ChordWikiUiState,
    onCalibrationMode: (Boolean) -> Unit,
    onNudgeAnchor:
        (
            chartBeat: Float,
            deltaMs: Long
        ) -> Unit,
    onRemoveAnchor: (Float) -> Unit,
    onClearAnchors: () -> Unit,
    modifier: Modifier = Modifier
) {
    val timeline =
        state.timeline
            ?: return

    val syncMap =
        remember(
            state.syncAnchors,
            state.bpm,
            state.youtubeOffsetMs,
            timeline.totalBeats
        ) {
            ChordSyncMap(
                anchors =
                    state.syncAnchors,
                fallbackBpm =
                    state.bpm,
                fallbackOffsetMs =
                    state.youtubeOffsetMs,
                totalBeats =
                    timeline.totalBeats
            )
        }

    val status =
        syncMap.statusAtBeat(
            state.currentBeat
        )

    ElevatedCard(
        modifier =
            modifier.fillMaxWidth(),
        colors =
            CardDefaults.elevatedCardColors(
                containerColor =
                    MaterialTheme.colorScheme
                        .surfaceContainerLow
            )
    ) {
        Column(
            modifier =
                Modifier.padding(16.dp),
            verticalArrangement =
                Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier =
                    Modifier.fillMaxWidth(),
                verticalAlignment =
                    Alignment.CenterVertically
            ) {
                Icon(
                    imageVector =
                        Icons.Rounded.Tune,
                    contentDescription = null,
                    tint =
                        MaterialTheme.colorScheme
                            .primary
                )

                Spacer(
                    Modifier.width(10.dp)
                )

                Column(
                    modifier =
                        Modifier.weight(1f)
                ) {
                    Text(
                        text =
                            stringResource(
                                R.string.chordwiki_precision_sync
                            ),
                        style =
                            MaterialTheme.typography
                                .titleMedium
                    )

                    Text(
                        text =
                            stringResource(
                                R.string.chordwiki_precision_sync_hint
                            ),
                        style =
                            MaterialTheme.typography
                                .bodySmall,
                        color =
                            MaterialTheme.colorScheme
                                .onSurfaceVariant
                    )
                }

                FilterChip(
                    selected =
                        state.calibrationMode,
                    onClick = {
                        onCalibrationMode(
                            !state.calibrationMode
                        )
                    },
                    label = {
                        Text(
                            if (
                                state.calibrationMode
                            ) {
                                stringResource(
                                    R.string.done
                                )
                            } else {
                                stringResource(
                                    R.string.chordwiki_calibrate
                                )
                            }
                        )
                    }
                )
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(
                        rememberScrollState()
                    ),
                horizontalArrangement =
                    Arrangement.spacedBy(8.dp)
            ) {
                AssistChip(
                    onClick = {},
                    label = {
                        Text(
                            precisionLabel(
                                status.precision
                            )
                        )
                    }
                )

                AssistChip(
                    onClick = {},
                    label = {
                        Text(
                            stringResource(
                                R.string.chordwiki_anchor_count,
                                status.anchorCount
                            )
                        )
                    }
                )

                if (
                    status.anchorCount >= 2
                ) {
                    AssistChip(
                        onClick = {},
                        label = {
                            Text(
                                stringResource(
                                    R.string.chordwiki_local_bpm,
                                    status.localBpm
                                )
                            )
                        }
                    )
                }

                if (
                    state.youtubePlaybackRate !=
                    1f
                ) {
                    AssistChip(
                        onClick = {},
                        label = {
                            Text(
                                stringResource(
                                    R.string.chordwiki_playback_rate,
                                    state.youtubePlaybackRate
                                )
                            )
                        }
                    )
                }
            }

            if (state.calibrationMode) {
                Text(
                    text =
                        stringResource(
                            R.string.chordwiki_calibration_instruction
                        ),
                    style =
                        MaterialTheme.typography
                            .bodyMedium,
                    color =
                        MaterialTheme.colorScheme
                            .primary,
                    fontWeight =
                        FontWeight.SemiBold
                )
            }

            state.syncNotice?.let {
                Text(
                    text = it,
                    style =
                        MaterialTheme.typography
                            .bodySmall,
                    color =
                        MaterialTheme.colorScheme
                            .onSurfaceVariant
                )
            }

            if (
                state.syncAnchors.isNotEmpty()
            ) {
                Column(
                    verticalArrangement =
                        Arrangement.spacedBy(6.dp)
                ) {
                    state.syncAnchors
                        .forEachIndexed {
                                index,
                                anchor ->
                            Row(
                                modifier =
                                    Modifier
                                        .fillMaxWidth(),
                                verticalAlignment =
                                    Alignment.CenterVertically,
                                horizontalArrangement =
                                    Arrangement.spacedBy(6.dp)
                            ) {
                                Column(
                                    modifier =
                                        Modifier.weight(1f)
                                ) {
                                    Text(
                                        text =
                                            (
                                                index + 1
                                                ).toString() +
                                                ". " +
                                                anchor.symbol,
                                        style =
                                            MaterialTheme.typography
                                                .labelLarge,
                                        fontWeight =
                                            FontWeight.SemiBold
                                    )

                                    Text(
                                        text =
                                            formatPreciseTime(
                                                anchor.videoPositionMs
                                            ) +
                                                "  •  beat " +
                                                formatBeat(
                                                    anchor.chartBeat
                                                ),
                                        style =
                                            MaterialTheme.typography
                                                .bodySmall,
                                        color =
                                            MaterialTheme.colorScheme
                                                .onSurfaceVariant
                                    )
                                }

                                OutlinedIconButton(
                                    onClick = {
                                        onNudgeAnchor(
                                            anchor.chartBeat,
                                            -50L
                                        )
                                    }
                                ) {
                                    Icon(
                                        imageVector =
                                            Icons.Rounded.Remove,
                                        contentDescription =
                                            stringResource(
                                                R.string.chordwiki_nudge_earlier
                                            )
                                    )
                                }

                                OutlinedIconButton(
                                    onClick = {
                                        onNudgeAnchor(
                                            anchor.chartBeat,
                                            50L
                                        )
                                    }
                                ) {
                                    Icon(
                                        imageVector =
                                            Icons.Rounded.Add,
                                        contentDescription =
                                            stringResource(
                                                R.string.chordwiki_nudge_later
                                            )
                                    )
                                }

                                OutlinedIconButton(
                                    onClick = {
                                        onRemoveAnchor(
                                            anchor.chartBeat
                                        )
                                    }
                                ) {
                                    Icon(
                                        imageVector =
                                            Icons.Rounded.Delete,
                                        contentDescription =
                                            stringResource(
                                                R.string.chordwiki_remove_anchor
                                            )
                                    )
                                }
                            }
                        }
                }

                OutlinedButton(
                    onClick =
                        onClearAnchors
                ) {
                    Text(
                        stringResource(
                            R.string.chordwiki_reset_calibration
                        )
                    )
                }
            }
        }
    }
}

@Composable
private fun precisionLabel(
    precision: ChordSyncPrecision
): String =
    when (precision) {
        ChordSyncPrecision.BPM_ONLY ->
            stringResource(
                R.string.chordwiki_precision_bpm_only
            )

        ChordSyncPrecision.OFFSET_LOCKED ->
            stringResource(
                R.string.chordwiki_precision_one_anchor
            )

        ChordSyncPrecision.GLOBAL_WARP ->
            stringResource(
                R.string.chordwiki_precision_two_anchors
            )

        ChordSyncPrecision.PIECEWISE_WARP ->
            stringResource(
                R.string.chordwiki_precision_piecewise
            )
    }

private fun formatPreciseTime(
    durationMs: Long
): String {
    val safe =
        durationMs.coerceAtLeast(0L)
    val minutes =
        safe / 60_000L
    val seconds =
        (
            safe % 60_000L
            ) / 1_000L
    val millis =
        safe % 1_000L

    return "%d:%02d.%03d".format(
        minutes,
        seconds,
        millis
    )
}

private fun formatBeat(
    beat: Float
): String =
    if (
        kotlin.math.abs(
            beat -
                beat.toInt()
        ) < 0.001f
    ) {
        beat.toInt()
            .toString()
    } else {
        "%.2f".format(beat)
    }
