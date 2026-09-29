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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.mirinnano.guitartools.music.Fretboard
import dev.mirinnano.guitartools.music.Note
import dev.mirinnano.guitartools.music.Tuning

@Composable
fun FretboardDiagram(
    tuning: Tuning,
    maxFret: Int,
    highlightedNote: Note?,
    modifier: Modifier = Modifier,
    cellWidth: Dp = 56.dp,
    rowHeight: Dp = 44.dp
) {
    val lineColor = MaterialTheme.colorScheme.outline
    val nutColor = MaterialTheme.colorScheme.onSurface
    val highlightColor = MaterialTheme.colorScheme.primaryContainer
    val highlightContentColor = MaterialTheme.colorScheme.onPrimaryContainer
    val defaultContentColor = MaterialTheme.colorScheme.onSurface
    val scrollState = rememberScrollState()

    val totalColumns = maxFret + 1
    val totalRows = 7
    val boardWidth = cellWidth * totalColumns
    val boardHeight = rowHeight * totalRows

    Box(
        modifier = modifier.horizontalScroll(scrollState)
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

                for (stringRow in 0 until 6) {
                    val y = headerBottom + (stringRow + 0.5f) * rowHeightPx
                    drawLine(
                        color = lineColor,
                        start = Offset(0f, y),
                        end = Offset(size.width, y),
                        strokeWidth = 1.dp.toPx()
                    )
                }

                for (fretBoundary in 1..maxFret) {
                    val x = fretBoundary * cellWidthPx
                    drawLine(
                        color = if (fretBoundary == 1) nutColor else lineColor,
                        start = Offset(x, headerBottom),
                        end = Offset(x, size.height),
                        strokeWidth = if (fretBoundary == 1) {
                            4.dp.toPx()
                        } else {
                            1.dp.toPx()
                        }
                    )
                }
            }

            Column {
                Row {
                    (0..maxFret).forEach { fret ->
                        Box(
                            modifier = Modifier
                                .width(cellWidth)
                                .height(rowHeight),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = fret.toString(),
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }

                tuning.strings.reversed().forEach { string ->
                    Row {
                        (0..maxFret).forEach { fret ->
                            val position = Fretboard.position(string, fret)
                            val highlighted = highlightedNote == position.note

                            Box(
                                modifier = Modifier
                                    .width(cellWidth)
                                    .height(rowHeight),
                                contentAlignment = Alignment.Center
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(32.dp)
                                        .background(
                                            color = if (highlighted) {
                                                highlightColor
                                            } else {
                                                Color.Transparent
                                            },
                                            shape = CircleShape
                                        ),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = position.note.displayName,
                                        style = MaterialTheme.typography.labelLarge,
                                        color = if (highlighted) {
                                            highlightContentColor
                                        } else {
                                            defaultContentColor
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
