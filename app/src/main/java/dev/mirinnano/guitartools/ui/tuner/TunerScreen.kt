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
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
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
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
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

private const val MIN_REFERENCE_PITCH =
    430f
private const val MAX_REFERENCE_PITCH =
    450f
private const val IN_TUNE_CENTS = 5.0

@Composable
fun TunerScreen(
    modifier: Modifier = Modifier,
    viewModel: TunerViewModel = viewModel()
) {
    val context = LocalContext.current
    val haptics =
        LocalHapticFeedback.current

    val state by
        viewModel.uiState
            .collectAsStateWithLifecycle()

    var microphoneGranted by remember {
        mutableStateOf(
            ContextCompat
                .checkSelfPermission(
                    context,
                    Manifest.permission
                        .RECORD_AUDIO
                ) ==
                PackageManager
                    .PERMISSION_GRANTED
        )
    }

    var previouslyInTune by remember {
        mutableStateOf(false)
    }

    val permissionLauncher =
        rememberLauncherForActivityResult(
            ActivityResultContracts
                .RequestPermission()
        ) { granted ->
            microphoneGranted = granted
        }

    val isInTune =
        state.target?.let {
            abs(it.centsFromTarget) <=
                IN_TUNE_CENTS
        } == true

    LaunchedEffect(
        isInTune,
        state.hapticEnabled
    ) {
        if (
            isInTune &&
            !previouslyInTune &&
            state.hapticEnabled
        ) {
            haptics.performHapticFeedback(
                HapticFeedbackType.LongPress
            )
        }
        previouslyInTune = isInTune
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
            .verticalScroll(
                rememberScrollState()
            )
            .padding(
                horizontal = 20.dp,
                vertical = 16.dp
            ),
        verticalArrangement =
            Arrangement.spacedBy(16.dp)
    ) {
        if (!microphoneGranted) {
            MicrophonePermissionCard(
                onRequestPermission = {
                    permissionLauncher.launch(
                        Manifest.permission
                            .RECORD_AUDIO
                    )
                }
            )
            return@Column
        }

        PitchCard(
            reading = state.reading,
            target = state.target,
            tuning =
                state.selectedTuning
        )

        StringTargetCard(
            state = state,
            onLock =
                viewModel::setLockedString,
            onTone =
                viewModel::playReferenceString
        )

        TuningPresetCard(
            state = state,
            onTuningSelected =
                viewModel::setTuning,
            onCustom =
                viewModel::selectCustomTuning,
            onCustomChange =
                viewModel::changeCustomString
        )

        ReferencePitchCard(
            state = state,
            onReferencePitchChange =
                viewModel::setReferencePitch,
            onSensitivity =
                viewModel::setSensitivity,
            onHaptic =
                viewModel::setHapticEnabled
        )

        if (state.errorMessage != null) {
            Text(
                text = stringResource(
                    R.string.tuner_error
                ),
                color =
                    MaterialTheme.colorScheme
                        .error
            )
        }
    }
}

@Composable
private fun PitchCard(
    reading: PitchReading?,
    target: TuningTarget?,
    tuning: Tuning
) {
    val cents =
        target?.centsFromTarget

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme
                    .primaryContainer
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    horizontal = 24.dp,
                    vertical = 28.dp
                ),
            horizontalAlignment =
                Alignment.CenterHorizontally,
            verticalArrangement =
                Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = reading?.let {
                    it.note.displayName(
                        tuning
                            .accidentalPreference
                    ) + it.octave
                } ?: "—",
                style =
                    MaterialTheme.typography
                        .displayLarge,
                color =
                    MaterialTheme.colorScheme
                        .onPrimaryContainer
            )

            if (target != null) {
                Text(
                    text = stringResource(
                        R.string.string_target,
                        target.string
                            .stringNumber,
                        target.string.label
                    ),
                    style =
                        MaterialTheme.typography
                            .titleMedium,
                    color =
                        MaterialTheme.colorScheme
                            .onPrimaryContainer
                )
            }

            TunerGauge(
                cents = cents
            )

            Text(
                text = target?.let {
                    stringResource(
                        R.string.cents_format,
                        it.centsFromTarget
                            .toInt()
                    )
                } ?: stringResource(
                    R.string.listening
                ),
                style =
                    MaterialTheme.typography
                        .titleMedium,
                color =
                    MaterialTheme.colorScheme
                        .onPrimaryContainer
            )

            if (target != null &&
                abs(
                    target.centsFromTarget
                ) <= IN_TUNE_CENTS
            ) {
                Text(
                    text = stringResource(
                        R.string.in_tune
                    ),
                    style =
                        MaterialTheme.typography
                            .labelLarge,
                    color =
                        MaterialTheme.colorScheme
                            .onPrimaryContainer
                )
            }

            Text(
                text = reading?.let {
                    String.format(
                        Locale.US,
                        "%.1f Hz",
                        it.frequencyHz
                    )
                } ?: stringResource(
                    R.string.play_a_string
                ),
                style =
                    MaterialTheme.typography
                        .bodyMedium,
                color =
                    MaterialTheme.colorScheme
                        .onPrimaryContainer
            )
        }
    }
}

@Composable
private fun StringTargetCard(
    state: TunerUiState,
    onLock: (Int?) -> Unit,
    onTone: (Int) -> Unit
) {
    SettingsCard {
        SectionTitle(
            stringResource(
                R.string.target_string
            )
        )

        ChoiceRow {
            FilterChip(
                selected =
                    state.lockedStringNumber ==
                        null,
                onClick = {
                    onLock(null)
                },
                label = {
                    Text(
                        stringResource(
                            R.string.auto
                        )
                    )
                }
            )

            state.selectedTuning
                .strings
                .sortedByDescending {
                    it.stringNumber
                }
                .forEach { string ->
                    FilterChip(
                        selected =
                            state.lockedStringNumber ==
                                string.stringNumber,
                        onClick = {
                            onLock(
                                string.stringNumber
                            )
                        },
                        label = {
                            Text(
                                string.stringNumber
                                    .toString()
                            )
                        }
                    )
                }
        }

        Text(
            text = stringResource(
                R.string.reference_tones
            ),
            style =
                MaterialTheme.typography
                    .labelLarge,
            color =
                MaterialTheme.colorScheme
                    .onSurfaceVariant
        )

        Row(
            modifier =
                Modifier.fillMaxWidth(),
            horizontalArrangement =
                Arrangement.spacedBy(6.dp)
        ) {
            state.selectedTuning
                .strings
                .sortedByDescending {
                    it.stringNumber
                }
                .forEach { string ->
                    FilledTonalButton(
                        onClick = {
                            onTone(
                                string.stringNumber
                            )
                        },
                        modifier =
                            Modifier.weight(1f)
                    ) {
                        Text(string.label)
                    }
                }
        }
    }
}

@Composable
private fun TuningPresetCard(
    state: TunerUiState,
    onTuningSelected: (Tuning) -> Unit,
    onCustom: () -> Unit,
    onCustomChange: (Int, Int) -> Unit
) {
    SettingsCard {
        SectionTitle(
            stringResource(R.string.tuning)
        )

        ChoiceRow {
            Tuning.Presets.forEach {
                    tuning ->
                FilterChip(
                    selected =
                        state.selectedTuning.id ==
                            tuning.id,
                    onClick = {
                        onTuningSelected(tuning)
                    },
                    label = {
                        Text(tuning.name)
                    }
                )
            }

            FilterChip(
                selected =
                    state.selectedTuning.id ==
                        "custom",
                onClick = onCustom,
                label = {
                    Text("Custom")
                }
            )
        }

        if (
            state.selectedTuning.id ==
            "custom"
        ) {
            state.selectedTuning
                .strings
                .sortedByDescending {
                    it.stringNumber
                }
                .forEach { string ->
                    Row(
                        modifier =
                            Modifier.fillMaxWidth(),
                        verticalAlignment =
                            Alignment.CenterVertically
                    ) {
                        Text(
                            text =
                                stringResource(
                                    R.string.string_number,
                                    string.stringNumber
                                ),
                            modifier =
                                Modifier.weight(1f)
                        )

                        FilledTonalButton(
                            onClick = {
                                onCustomChange(
                                    string.stringNumber,
                                    -1
                                )
                            }
                        ) {
                            Text("−")
                        }

                        Text(
                            text = string.label,
                            modifier =
                                Modifier.padding(
                                    horizontal = 12.dp
                                )
                        )

                        FilledTonalButton(
                            onClick = {
                                onCustomChange(
                                    string.stringNumber,
                                    1
                                )
                            }
                        ) {
                            Text("+")
                        }
                    }
                }
        }
    }
}

@Composable
private fun ReferencePitchCard(
    state: TunerUiState,
    onReferencePitchChange:
        (Double) -> Unit,
    onSensitivity: (Float) -> Unit,
    onHaptic: (Boolean) -> Unit
) {
    SettingsCard {
        SectionTitle(
            stringResource(
                R.string.reference_pitch
            )
        )

        ChoiceRow {
            listOf(432, 440, 442)
                .forEach { hz ->
                    FilterChip(
                        selected =
                            state.a4Hz.toInt() ==
                                hz,
                        onClick = {
                            onReferencePitchChange(
                                hz.toDouble()
                            )
                        },
                        label = {
                            Text("$hz Hz")
                        }
                    )
                }
        }

        Text(
            text =
                "A4 = " +
                    state.a4Hz.toInt() +
                    " Hz",
            color =
                MaterialTheme.colorScheme
                    .onSurfaceVariant
        )

        Slider(
            value =
                state.a4Hz.toFloat(),
            onValueChange = {
                onReferencePitchChange(
                    it.toDouble()
                )
            },
            valueRange =
                MIN_REFERENCE_PITCH..
                    MAX_REFERENCE_PITCH
        )

        Text(
            text = stringResource(
                R.string.input_sensitivity
            ),
            style =
                MaterialTheme.typography
                    .labelLarge
        )

        Slider(
            value = state.sensitivity,
            onValueChange = onSensitivity,
            valueRange = 0f..1f
        )

        Row(
            modifier =
                Modifier.fillMaxWidth(),
            verticalAlignment =
                Alignment.CenterVertically
        ) {
            Text(
                text = stringResource(
                    R.string.haptic_in_tune
                ),
                modifier =
                    Modifier.weight(1f)
            )
            Switch(
                checked =
                    state.hapticEnabled,
                onCheckedChange = onHaptic
            )
        }
    }
}

@Composable
private fun MicrophonePermissionCard(
    onRequestPermission: () -> Unit
) {
    SettingsCard {
        Icon(
            imageVector = Icons.Rounded.Mic,
            contentDescription = null
        )

        Text(
            text = stringResource(
                R.string.microphone_access
            ),
            style =
                MaterialTheme.typography
                    .titleLarge
        )

        Text(
            text = stringResource(
                R.string
                    .microphone_access_description
            ),
            textAlign = TextAlign.Center,
            color =
                MaterialTheme.colorScheme
                    .onSurfaceVariant
        )

        Button(
            onClick = onRequestPermission
        ) {
            Text(
                stringResource(
                    R.string.allow_microphone
                )
            )
        }
    }
}

@Composable
private fun SettingsCard(
    content:
        @Composable Column.() -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme
                    .surfaceContainerLow
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement =
                Arrangement.spacedBy(12.dp),
            content = content
        )
    }
}

@Composable
private fun ChoiceRow(
    content:
        @Composable Row.() -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(
                rememberScrollState()
            ),
        horizontalArrangement =
            Arrangement.spacedBy(8.dp),
        content = content
    )
}

@Composable
private fun SectionTitle(
    text: String
) {
    Text(
        text = text,
        style =
            MaterialTheme.typography
                .titleMedium
    )
}
