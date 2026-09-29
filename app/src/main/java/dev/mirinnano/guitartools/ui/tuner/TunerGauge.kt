package dev.mirinnano.guitartools.ui.tuner

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import androidx.compose.material3.MaterialTheme
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

@Composable
fun TunerGauge(
    cents: Double?,
    modifier: Modifier = Modifier
) {
    val lineColor =
        MaterialTheme.colorScheme
            .onPrimaryContainer
    val needleColor =
        MaterialTheme.colorScheme.primary
    val inTuneColor =
        MaterialTheme.colorScheme.tertiary

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(150.dp)
    ) {
        val center = Offset(
            size.width / 2f,
            size.height * 0.88f
        )
        val radius = min(
            size.width * 0.43f,
            size.height * 0.78f
        )

        drawArc(
            color = lineColor,
            startAngle = 210f,
            sweepAngle = 120f,
            useCenter = false,
            topLeft = Offset(
                center.x - radius,
                center.y - radius
            ),
            size = Size(
                radius * 2f,
                radius * 2f
            ),
            style = Stroke(
                width = 2.dp.toPx()
            )
        )

        drawArc(
            color = inTuneColor,
            startAngle = 264f,
            sweepAngle = 12f,
            useCenter = false,
            topLeft = Offset(
                center.x - radius,
                center.y - radius
            ),
            size = Size(
                radius * 2f,
                radius * 2f
            ),
            style = Stroke(
                width = 8.dp.toPx(),
                cap = StrokeCap.Round
            )
        )

        for (tick in -50..50 step 10) {
            val angle =
                (
                    210.0 +
                        (tick + 50) /
                            100.0 *
                            120.0
                    ) * PI / 180.0

            val outer = Offset(
                center.x +
                    cos(angle).toFloat() *
                    radius,
                center.y +
                    sin(angle).toFloat() *
                    radius
            )

            val innerRadius =
                radius -
                    if (tick == 0) {
                        18.dp.toPx()
                    } else {
                        10.dp.toPx()
                    }

            val inner = Offset(
                center.x +
                    cos(angle).toFloat() *
                    innerRadius,
                center.y +
                    sin(angle).toFloat() *
                    innerRadius
            )

            drawLine(
                color = lineColor,
                start = inner,
                end = outer,
                strokeWidth =
                    if (tick == 0) {
                        3.dp.toPx()
                    } else {
                        1.5.dp.toPx()
                    },
                cap = StrokeCap.Round
            )
        }

        val clamped =
            cents?.coerceIn(
                -50.0,
                50.0
            ) ?: 0.0

        val needleAngle =
            (
                210.0 +
                    (clamped + 50.0) /
                        100.0 *
                        120.0
                ) * PI / 180.0

        val needleEnd = Offset(
            center.x +
                cos(needleAngle).toFloat() *
                (radius - 22.dp.toPx()),
            center.y +
                sin(needleAngle).toFloat() *
                (radius - 22.dp.toPx())
        )

        drawLine(
            color = needleColor,
            start = center,
            end = needleEnd,
            strokeWidth = 4.dp.toPx(),
            cap = StrokeCap.Round
        )

        drawCircle(
            color = needleColor,
            radius = 7.dp.toPx(),
            center = center
        )
    }
}
