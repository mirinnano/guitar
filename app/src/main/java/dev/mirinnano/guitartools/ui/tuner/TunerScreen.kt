package dev.mirinnano.guitartools.ui.tuner

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.mirinnano.guitartools.music.Tuning
import java.util.Locale
import kotlin.math.abs

@Composable
fun TunerScreen(
    modifier: Modifier = Modifier,
    viewModel: TunerViewModel = viewModel()
) {
    val context = LocalContext.current
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    var permissionGranted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED
        )
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        permissionGranted = granted
    }

    LaunchedEffect(permissionGranted) {
        if (permissionGranted) {
            viewModel.start()
        } else {
            viewModel.stop()
        }
    }

    DisposableEffect(Unit) {
        onDispose { viewModel.stop() }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        if (!permissionGranted) {
            Card(
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        imageVector = Icons.Rounded.Mic,
                        contentDescription = null
                    )
                    Text(
                        text = "Microphone access",
                        style = MaterialTheme.typography.titleLarge
                    )
                    Text(
                        text = "The tuner needs the microphone to detect your guitar pitch.",
                        textAlign = TextAlign.Center,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Button(
                        onClick = {
                            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                        }
                    ) {
                        Text("Allow microphone")
                    }
                }
            }
            return@Column
        }

        val reading = state.reading
        val chromaticCents = reading?.cents ?: 0.0
        val target = reading?.let {
            state.selectedTuning.closestString(
                frequencyHz = it.frequencyHz,
                a4Hz = state.a4Hz
            )
        }
        val targetCents = target?.centsFromTarget ?: 0.0
        val normalized = (
            (targetCents.coerceIn(-50.0, 50.0) + 50.0) / 100.0
        ).toFloat()

        Card(
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(28.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = reading?.let { readingValue ->
                        readingValue.note.displayName(
                            state.selectedTuning.accidentalPreference
                        ) + readingValue.octave
                    } ?: "—",
                    style = MaterialTheme.typography.displayLarge
                )

                Text(
                    text = reading?.let { readingValue ->
                        String.format(Locale.US, "%.1f Hz", readingValue.frequencyHz)
                    } ?: "Play a string",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                target?.let { targetValue ->
                    Text(
                        text = "String " + targetValue.string.stringNumber +
                            " · target " + targetValue.string.label,
                        style = MaterialTheme.typography.titleMedium
                    )
                }

                Text(
                    text = target?.let { targetValue ->
                        val rounded = targetValue.centsFromTarget.toInt()
                        if (rounded > 0) "+$rounded cents" else "$rounded cents"
                    } ?: "Listening…",
                    style = MaterialTheme.typography.bodyLarge
                )

                LinearProgressIndicator(
                    progress = { normalized },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp)
                )

                if (target != null && abs(targetCents) <= 5.0) {
                    Text(
                        text = "In tune",
                        color = MaterialTheme.colorScheme.primary,
                        style = MaterialTheme.typography.labelLarge
                    )
                }

                if (reading != null) {
                    Text(
                        text = "Chromatic offset: " +
                            (if (chromaticCents > 0) "+" else "") +
                            chromaticCents.toInt() + " cents",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "Tuning",
                    style = MaterialTheme.typography.titleMedium
                )

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Tuning.Presets.forEach { tuning ->
                        FilterChip(
                            selected = state.selectedTuning.id == tuning.id,
                            onClick = { viewModel.setTuning(tuning) },
                            label = { Text(tuning.name) }
                        )
                    }
                }

                Text(
                    text = state.selectedTuning.strings
                        .sortedByDescending { it.stringNumber }
                        .joinToString("  ") { it.label },
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "Reference pitch",
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = "A4 = " + state.a4Hz.toInt() + " Hz",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Slider(
                    value = state.a4Hz.toFloat(),
                    onValueChange = { viewModel.setReferencePitch(it.toDouble()) },
                    valueRange = 430f..450f
                )
            }
        }

        state.errorMessage?.let { message ->
            Text(
                text = message,
                color = MaterialTheme.colorScheme.error
            )
        }
    }
}
