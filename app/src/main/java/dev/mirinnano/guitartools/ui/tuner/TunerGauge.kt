package dev.mirinnano.guitartools.ui.tuner

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

private const val MIN_CENTS = -50.0
private const val MAX_CENTS = 50.0
private const val IN_TUNE_CENTS = 5.0

private const val ARC_START_DEGREES = 210.0
private const val ARC_SWEEP_DEGREES = 120.0

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

        val arcBounds = Size(
            radius * 2f,
            radius * 2f
        )
        val arcTopLeft = Offset(
            center.x - radius,
            center.y - radius
        )

        drawArc(
            color = lineColor,
            startAngle =
                ARC_START_DEGREES.toFloat(),
            sweepAngle =
                ARC_SWEEP_DEGREES.toFloat(),
            useCenter = false,
            topLeft = arcTopLeft,
            size = arcBounds,
            style = Stroke(
                width = 2.dp.toPx()
            )
        )

        val inTuneStart =
            centsToDegrees(-IN_TUNE_CENTS)
        val inTuneEnd =
            centsToDegrees(IN_TUNE_CENTS)

        drawArc(
            color = inTuneColor,
            startAngle =
                inTuneStart.toFloat(),
            sweepAngle =
                (inTuneEnd - inTuneStart)
                    .toFloat(),
            useCenter = false,
            topLeft = arcTopLeft,
            size = arcBounds,
            style = Stroke(
                width = 7.dp.toPx(),
                cap = StrokeCap.Round
            )
        )

        for (tick in -50..50 step 10) {
            val angle =
                centsToRadians(
                    tick.toDouble()
                )

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
                color =
                    if (
                        tick in
                        -IN_TUNE_CENTS.toInt()..
                            IN_TUNE_CENTS.toInt()
                    ) {
                        inTuneColor
                    } else {
                        lineColor
                    },
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
                MIN_CENTS,
                MAX_CENTS
            ) ?: 0.0

        val needleAngle =
            centsToRadians(clamped)

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

private fun centsToDegrees(
    cents: Double
): Double {
    val normalized =
        (
            cents.coerceIn(
                MIN_CENTS,
                MAX_CENTS
            ) - MIN_CENTS
            ) /
            (MAX_CENTS - MIN_CENTS)

    return ARC_START_DEGREES +
        normalized *
            ARC_SWEEP_DEGREES
}

private fun centsToRadians(
    cents: Double
): Double =
    centsToDegrees(cents) *
        PI / 180.0
