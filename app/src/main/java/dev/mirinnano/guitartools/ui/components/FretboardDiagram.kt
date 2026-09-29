package dev.mirinnano.guitartools.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.mirinnano.guitartools.R
import dev.mirinnano.guitartools.music.Fretboard
import dev.mirinnano.guitartools.music.Note
import dev.mirinnano.guitartools.music.Tuning

@Composable
fun FretboardDiagram(
    tuning: Tuning,
    maxFret: Int,
    highlightedNotes: Set<Note>,
    rootNote: Note?,
    labels: Map<Note, String>,
    leftHanded: Boolean,
    modifier: Modifier = Modifier,
    cellWidth: Dp = 56.dp,
    rowHeight: Dp = 44.dp
) {
    val lineColor = MaterialTheme.colorScheme.outline
    val nutColor = MaterialTheme.colorScheme.onSurface
    val rootColor = MaterialTheme.colorScheme.primary
    val rootContent = MaterialTheme.colorScheme.onPrimary
    val highlightColor = MaterialTheme.colorScheme.secondaryContainer
    val highlightContent = MaterialTheme.colorScheme.onSecondaryContainer
    val defaultContent = MaterialTheme.colorScheme.onSurfaceVariant
    val scrollState = rememberScrollState()

    val description = stringResource(
        R.string.fretboard_description,
        tuning.name
    )

    val fretSequence =
        if (leftHanded) {
            (0..maxFret).toList().reversed()
        } else {
            (0..maxFret).toList()
        }

    val totalColumns = maxFret + 1
    val totalRows = 7
    val boardWidth = cellWidth * totalColumns
    val boardHeight = rowHeight * totalRows

    Box(
        modifier = modifier
            .semantics {
                contentDescription = description
            }
            .horizontalScroll(scrollState)
    ) {
        Box(
            modifier = Modifier
                .width(boardWidth)
                .height(boardHeight)
        ) {
            Canvas(
                modifier = Modifier.matchParentSize()
            ) {
                val cellWidthPx = cellWidth.toPx()
                val rowHeightPx = rowHeight.toPx()
                val headerBottom = rowHeightPx

                repeat(6) { row ->
                    val y =
                        headerBottom +
                            (row + 0.5f) * rowHeightPx

                    drawLine(
                        color = lineColor,
                        start = Offset(0f, y),
                        end = Offset(size.width, y),
                        strokeWidth = 1.dp.toPx()
                    )
                }

                for (boundary in 1..maxFret) {
                    val x = boundary * cellWidthPx
                    val isNut =
                        if (leftHanded) {
                            boundary == maxFret
                        } else {
                            boundary == 1
                        }

                    drawLine(
                        color =
                            if (isNut) {
                                nutColor
                            } else {
                                lineColor
                            },
                        start = Offset(x, headerBottom),
                        end = Offset(x, size.height),
                        strokeWidth =
                            if (isNut) {
                                4.dp.toPx()
                            } else {
                                1.dp.toPx()
                            }
                    )
                }
            }

            Column {
                Row {
                    fretSequence.forEach { fret ->
                        FretboardCell(
                            width = cellWidth,
                            height = rowHeight
                        ) {
                            Text(
                                text = fret.toString(),
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }

                tuning.strings
                    .reversed()
                    .forEach { string ->
                        Row {
                            fretSequence.forEach { fret ->
                                val position =
                                    Fretboard.position(
                                        string,
                                        fret
                                    )

                                val highlighted =
                                    position.note in highlightedNotes

                                val isRoot =
                                    rootNote != null &&
                                        position.note == rootNote

                                FretboardCell(
                                    width = cellWidth,
                                    height = rowHeight
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(34.dp)
                                            .background(
                                                color =
                                                    when {
                                                        isRoot ->
                                                            rootColor
                                                        highlighted ->
                                                            highlightColor
                                                        else ->
                                                            Color.Transparent
                                                    },
                                                shape = CircleShape
                                            ),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            text =
                                                labels[position.note]
                                                    ?: position.note.displayName(
                                                        tuning.accidentalPreference
                                                    ),
                                            style = MaterialTheme.typography.labelLarge,
                                            color =
                                                when {
                                                    isRoot ->
                                                        rootContent
                                                    highlighted ->
                                                        highlightContent
                                                    else ->
                                                        defaultContent
                                                }
                                        )
                                    }
                                }
                            }
                        }
                    }
            }
        }
    }
}

@Composable
private fun FretboardCell(
    width: Dp,
    height: Dp,
    content: @Composable () -> Unit
) {
    Box(
        modifier = Modifier
            .width(width)
            .height(height),
        contentAlignment = Alignment.Center
    ) {
        content()
    }
}
