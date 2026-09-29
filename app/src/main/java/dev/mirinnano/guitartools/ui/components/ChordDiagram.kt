package dev.mirinnano.guitartools.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import dev.mirinnano.guitartools.R
import dev.mirinnano.guitartools.music.ChordShape

private const val STRING_COUNT = 6
private const val DISPLAYED_FRET_COUNT = 5

@Composable
fun ChordDiagram(
    shape: ChordShape,
    modifier: Modifier = Modifier,
    compact: Boolean = false
) {
    val lineColor = MaterialTheme.colorScheme.onSurface
    val markerColor = MaterialTheme.colorScheme.primary
    val description = stringResource(
        R.string.chord_diagram_description,
        shape.name
    )

    val diagramHeight = if (compact) 112.dp else 164.dp
    val markerRadius = if (compact) 5.dp else 7.dp
    val barreWidth = if (compact) 11.dp else 15.dp

    Column(
        modifier = modifier.semantics {
            contentDescription = description
        },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(
            if (compact) 2.dp else 4.dp
        )
    ) {
        OpenAndMutedStrings(
            shape = shape,
            compact = compact
        )

        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(diagramHeight)
        ) {
            val horizontalInset = 8.dp.toPx()
            val verticalInset = 4.dp.toPx()

            val left = horizontalInset
            val right = size.width - horizontalInset
            val top = verticalInset
            val bottom = size.height - verticalInset

            val stringSpacing =
                (right - left) / (STRING_COUNT - 1)
            val fretSpacing =
                (bottom - top) / DISPLAYED_FRET_COUNT

            fun xForStringNumber(
                stringNumber: Int
            ): Float {
                val stringIndex =
                    STRING_COUNT - stringNumber

                return left +
                    stringIndex * stringSpacing
            }

            fun yForFret(
                absoluteFret: Int
            ): Float {
                val relativeFret =
                    absoluteFret - shape.baseFret + 1

                return top +
                    (relativeFret - 0.5f) *
                    fretSpacing
            }

            repeat(STRING_COUNT) { stringIndex ->
                val x =
                    left + stringIndex * stringSpacing

                drawLine(
                    color = lineColor,
                    start = Offset(x, top),
                    end = Offset(x, bottom),
                    strokeWidth = 1.5.dp.toPx(),
                    cap = StrokeCap.Round
                )
            }

            for (
                fretLine in
                0..DISPLAYED_FRET_COUNT
            ) {
                val y =
                    top + fretLine * fretSpacing

                drawLine(
                    color = lineColor,
                    start = Offset(left, y),
                    end = Offset(right, y),
                    strokeWidth = if (
                        fretLine == 0 &&
                        shape.baseFret == 1
                    ) {
                        4.dp.toPx()
                    } else {
                        1.5.dp.toPx()
                    },
                    cap = StrokeCap.Round
                )
            }

            shape.barres.forEach { barre ->
                val relativeFret =
                    barre.fret -
                        shape.baseFret +
                        1

                if (
                    relativeFret !in
                    1..DISPLAYED_FRET_COUNT
                ) {
                    return@forEach
                }

                drawLine(
                    color = markerColor,
                    start = Offset(
                        xForStringNumber(
                            barre.fromString
                        ),
                        yForFret(barre.fret)
                    ),
                    end = Offset(
                        xForStringNumber(
                            barre.toString
                        ),
                        yForFret(barre.fret)
                    ),
                    strokeWidth =
                        barreWidth.toPx(),
                    cap = StrokeCap.Round
                )
            }

            shape.frets.forEachIndexed {
                    stringIndex,
                    absoluteFret ->

                if (absoluteFret <= 0) {
                    return@forEachIndexed
                }

                val relativeFret =
                    absoluteFret -
                        shape.baseFret +
                        1

                if (
                    relativeFret !in
                    1..DISPLAYED_FRET_COUNT
                ) {
                    return@forEachIndexed
                }

                val stringNumber =
                    STRING_COUNT - stringIndex

                drawCircle(
                    color = markerColor,
                    radius =
                        markerRadius.toPx(),
                    center = Offset(
                        xForStringNumber(
                            stringNumber
                        ),
                        yForFret(
                            absoluteFret
                        )
                    )
                )
            }
        }

        if (shape.baseFret > 1) {
            Text(
                text = stringResource(
                    R.string.fret_number,
                    shape.baseFret
                ),
                style = if (compact) {
                    MaterialTheme.typography.labelSmall
                } else {
                    MaterialTheme.typography.labelMedium
                },
                color =
                    MaterialTheme.colorScheme
                        .onSurfaceVariant
            )
        }

        Text(
            text = shape.fingers.joinToString(
                "  "
            ) { finger ->
                finger?.toString() ?: "–"
            },
            style = if (compact) {
                MaterialTheme.typography.labelSmall
            } else {
                MaterialTheme.typography.labelMedium
            },
            color =
                MaterialTheme.colorScheme
                    .onSurfaceVariant
        )
    }
}

@Composable
private fun OpenAndMutedStrings(
    shape: ChordShape,
    compact: Boolean
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp),
        horizontalArrangement =
            Arrangement.SpaceBetween
    ) {
        shape.frets.forEach { fret ->
            Text(
                text = when {
                    fret < 0 -> "×"
                    fret == 0 -> "○"
                    else -> " "
                },
                style = if (compact) {
                    MaterialTheme.typography.labelMedium
                } else {
                    MaterialTheme.typography.labelLarge
                }
            )
        }
    }
}
