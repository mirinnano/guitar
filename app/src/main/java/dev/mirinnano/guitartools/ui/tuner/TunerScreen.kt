package dev.mirinnano.guitartools.ui.tuner

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.mirinnano.guitartools.R
import dev.mirinnano.guitartools.music.PitchReading
import dev.mirinnano.guitartools.music.Tuning
import dev.mirinnano.guitartools.music.TuningTarget
import java.util.Locale
import kotlin.math.abs

private const val MIN_REFERENCE_PITCH = 430f
private const val MAX_REFERENCE_PITCH = 450f
private const val IN_TUNE_CENTS = 5.0

@Composable
fun TunerScreen(
    modifier: Modifier = Modifier,
    viewModel: TunerViewModel = viewModel()
) {
    val context = LocalContext.current
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    var microphoneGranted by remember {
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
        microphoneGranted = granted
    }

    LaunchedEffect(microphoneGranted) {
        if (microphoneGranted) {
            viewModel.start()
        } else {
            viewModel.stop()
        }
    }

    DisposableEffect(Unit) {
        onDispose(viewModel::stop)
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        if (!microphoneGranted) {
            MicrophonePermissionCard(
                onRequestPermission = {
                    permissionLauncher.launch(
                        Manifest.permission.RECORD_AUDIO
                    )
                }
            )
            return@Column
        }

        val reading = state.reading
        val target = reading?.let {
            state.selectedTuning.closestString(
                frequencyHz = it.frequencyHz,
                a4Hz = state.a4Hz
            )
        }

        PitchCard(
            reading = reading,
            target = target,
            tuning = state.selectedTuning
        )

        TuningPresetCard(
            selectedTuning = state.selectedTuning,
            onTuningSelected = viewModel::setTuning
        )

        ReferencePitchCard(
            a4Hz = state.a4Hz,
            onReferencePitchChange = viewModel::setReferencePitch
        )

        if (state.errorMessage != null) {
            Text(
                text = stringResource(R.string.tuner_error),
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}

@Composable
private fun MicrophonePermissionCard(
    onRequestPermission: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(28.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = Icons.Rounded.Mic,
                contentDescription = null
            )

            Text(
                text = stringResource(R.string.microphone_access),
                style = MaterialTheme.typography.titleLarge
            )

            Text(
                text = stringResource(
                    R.string.microphone_access_description
                ),
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Button(
                onClick = onRequestPermission
            ) {
                Text(
                    stringResource(R.string.allow_microphone)
                )
            }
        }
    }
}

@Composable
private fun PitchCard(
    reading: PitchReading?,
    target: TuningTarget?,
    tuning: Tuning
) {
    val targetCents = target?.centsFromTarget ?: 0.0
    val progress = (
        (targetCents.coerceIn(-50.0, 50.0) + 50.0) / 100.0
    ).toFloat()

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 28.dp, vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                text = reading?.let {
                    it.note.displayName(tuning.accidentalPreference) +
                        it.octave
                } ?: "—",
                style = MaterialTheme.typography.displayLarge,
                color = MaterialTheme.colorScheme.onPrimaryContainer
            )

            Text(
                text = reading?.let {
                    String.format(
                        Locale.US,
                        "%.1f Hz",
                        it.frequencyHz
                    )
                } ?: stringResource(R.string.play_a_string),
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onPrimaryContainer
            )

            if (target != null) {
                Text(
                    text = stringResource(
                        R.string.string_target,
                        target.string.stringNumber,
                        target.string.label
                    ),
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }

            Text(
                text = target?.let {
                    stringResource(
                        R.string.cents_format,
                        it.centsFromTarget.toInt()
                    )
                } ?: stringResource(R.string.listening),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onPrimaryContainer
            )

            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 4.dp),
                trackColor = MaterialTheme.colorScheme.surfaceContainerHighest
            )

            if (
                target != null &&
                abs(target.centsFromTarget) <= IN_TUNE_CENTS
            ) {
                Text(
                    text = stringResource(R.string.in_tune),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }

            if (reading != null) {
                Text(
                    text = stringResource(
                        R.string.chromatic_offset,
                        reading.cents.toInt()
                    ),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }
        }
    }
}

@Composable
private fun TuningPresetCard(
    selectedTuning: Tuning,
    onTuningSelected: (Tuning) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow
        )
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = stringResource(R.string.tuning),
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
                        selected = selectedTuning.id == tuning.id,
                        onClick = {
                            onTuningSelected(tuning)
                        },
                        label = {
                            Text(tuning.name)
                        }
                    )
                }
            }

            Text(
                text = selectedTuning.strings
                    .sortedByDescending { it.stringNumber }
                    .joinToString("  ") { it.label },
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun ReferencePitchCard(
    a4Hz: Double,
    onReferencePitchChange: (Double) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow
        )
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = stringResource(R.string.reference_pitch),
                style = MaterialTheme.typography.titleMedium
            )

            Text(
                text = "A4 = " + a4Hz.toInt() + " Hz",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Slider(
                value = a4Hz.toFloat(),
                onValueChange = {
                    onReferencePitchChange(it.toDouble())
                },
                valueRange =
                    MIN_REFERENCE_PITCH..MAX_REFERENCE_PITCH
            )
        }
    }
}
