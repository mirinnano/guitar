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
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import dev.mirinnano.guitartools.music.ChordShape

@Composable
fun ChordDiagram(
    shape: ChordShape,
    modifier: Modifier = Modifier
) {
    val lineColor = MaterialTheme.colorScheme.onSurface
    val dotColor = MaterialTheme.colorScheme.primary

    Column(
        modifier = modifier.semantics {
            contentDescription = shape.name + " chord diagram"
        },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            shape.frets.forEach { fret ->
                Text(
                    text = when {
                        fret < 0 -> "×"
                        fret == 0 -> "○"
                        else -> " "
                    },
                    style = MaterialTheme.typography.labelLarge
                )
            }
        }

        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(164.dp)
        ) {
            val insetX = 8.dp.toPx()
            val insetY = 4.dp.toPx()
            val left = insetX
            val right = size.width - insetX
            val top = insetY
            val bottom = size.height - insetY
            val stringSpacing = (right - left) / 5f
            val fretSpacing = (bottom - top) / 5f

            for (string in 0..5) {
                val x = left + string * stringSpacing
                drawLine(
                    color = lineColor,
                    start = Offset(x, top),
                    end = Offset(x, bottom),
                    strokeWidth = 1.5.dp.toPx(),
                    cap = StrokeCap.Round
                )
            }

            for (fretLine in 0..5) {
                val y = top + fretLine * fretSpacing
                drawLine(
                    color = lineColor,
                    start = Offset(left, y),
                    end = Offset(right, y),
                    strokeWidth = if (fretLine == 0 && shape.baseFret == 1) {
                        4.dp.toPx()
                    } else {
                        1.5.dp.toPx()
                    },
                    cap = StrokeCap.Round
                )
            }

            shape.frets.forEachIndexed { stringIndex, absoluteFret ->
                if (absoluteFret <= 0) return@forEachIndexed

                val relativeFret = absoluteFret - shape.baseFret + 1
                if (relativeFret !in 1..5) return@forEachIndexed

                val x = left + stringIndex * stringSpacing
                val y = top + (relativeFret - 0.5f) * fretSpacing

                drawCircle(
                    color = dotColor,
                    radius = 8.dp.toPx(),
                    center = Offset(x, y)
                )
            }
        }

        if (shape.baseFret > 1) {
            Text(
                text = "Fret ${shape.baseFret}",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Text(
            text = shape.fingers.joinToString("  ") { finger ->
                finger?.toString() ?: "–"
            },
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
