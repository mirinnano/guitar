package dev.mirinnano.guitartools.ui.metronome

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.mirinnano.guitartools.R
import dev.mirinnano.guitartools.audio.BeatAccent
import dev.mirinnano.guitartools.audio.ClickSound
import dev.mirinnano.guitartools.audio.MetronomeConfig
import dev.mirinnano.guitartools.audio.MetronomeSubdivision

private val TempoSteps =
    listOf(-5, -1, 1, 5)

private data class MeterPreset(
    val beats: Int,
    val unit: Int
) {
    val label: String
        get() = "$beats/$unit"
}

private val MeterPresets = listOf(
    MeterPreset(4, 4),
    MeterPreset(3, 4),
    MeterPreset(6, 8),
    MeterPreset(2, 4)
)

@Composable
fun MetronomeScreen(
    modifier: Modifier = Modifier,
    viewModel: MetronomeViewModel = viewModel()
) {
    val state by
        viewModel.uiState.collectAsStateWithLifecycle()

    val context = LocalContext.current
    val bluetoothAudioConnected =
        isBluetoothAudioConnected(context)

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
        TempoCard(
            state = state
        )

        if (bluetoothAudioConnected) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor =
                        MaterialTheme.colorScheme
                            .tertiaryContainer
                )
            ) {
                Text(
                    text = stringResource(
                        R.string.bluetooth_latency_warning
                    ),
                    modifier = Modifier.padding(14.dp),
                    style =
                        MaterialTheme.typography.bodySmall,
                    color =
                        MaterialTheme.colorScheme
                            .onTertiaryContainer
                )
            }
        }

        BeatIndicator(
            state = state
        )

        Slider(
            value = state.bpm.toFloat(),
            onValueChange = {
                viewModel.setBpm(it.toInt())
            },
            valueRange =
                MetronomeConfig.MIN_BPM.toFloat()..
                    MetronomeConfig.MAX_BPM.toFloat()
        )

        TempoStepButtons(
            onStep = viewModel::changeBpm
        )

        FilledTonalButton(
            onClick =
                viewModel::registerTempoTap,
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(
                imageVector =
                    Icons.Rounded.TouchApp,
                contentDescription = null
            )
            Text(
                text = stringResource(
                    R.string.tap_tempo
                ),
                modifier =
                    Modifier.padding(start = 8.dp)
            )
        }

        if (state.playbackFailed) {
            PlaybackError(
                onDismiss =
                    viewModel::dismissPlaybackError
            )
        }

        Button(
            onClick =
                viewModel::togglePlayback,
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(
                imageVector =
                    if (state.isPlaying) {
                        Icons.Rounded.Pause
                    } else {
                        Icons.Rounded.PlayArrow
                    },
                contentDescription = null
            )
            Text(
                text = stringResource(
                    if (state.isPlaying) {
                        R.string.stop
                    } else {
                        R.string.start
                    }
                ),
                modifier =
                    Modifier.padding(start = 8.dp)
            )
        }

        RhythmSettingsCard(
            state = state,
            onMeter = viewModel::setTimeSignature,
            onSubdivision =
                viewModel::setSubdivision,
            onAccent =
                viewModel::cycleAccent,
            onClickSound =
                viewModel::setClickSound,
            onCountIn =
                viewModel::setCountInBars
        )

        SpeedTrainerCard(
            state = state,
            viewModel = viewModel
        )
    }
}

@Composable
private fun TempoCard(
    state: MetronomeUiState
) {
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
                .padding(24.dp),
            horizontalAlignment =
                Alignment.CenterHorizontally
        ) {
            Text(
                text = state.bpm.toString(),
                style =
                    MaterialTheme.typography
                        .displayLarge,
                color =
                    MaterialTheme.colorScheme
                        .onPrimaryContainer
            )
            Text(
                text = stringResource(
                    R.string.bpm
                ),
                style =
                    MaterialTheme.typography
                        .labelLarge,
                color =
                    MaterialTheme.colorScheme
                        .onPrimaryContainer
            )

            if (state.isCountIn) {
                Text(
                    text = stringResource(
                        R.string.count_in
                    ),
                    style =
                        MaterialTheme.typography
                            .labelMedium,
                    color =
                        MaterialTheme.colorScheme
                            .onPrimaryContainer
                )
            }
        }
    }
}

@Composable
private fun BeatIndicator(
    state: MetronomeUiState
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement =
            Arrangement.Center
    ) {
        repeat(state.beatsPerBar) { index ->
            val active =
                state.isPlaying &&
                    state.currentBeat == index

            Surface(
                modifier = Modifier
                    .padding(horizontal = 5.dp)
                    .size(
                        if (active) {
                            22.dp
                        } else {
                            14.dp
                        }
                    ),
                shape = CircleShape,
                color = if (active) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme
                        .surfaceContainerHighest
                }
            ) {}
        }
    }
}

@Composable
private fun TempoStepButtons(
    onStep: (Int) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement =
            Arrangement.spacedBy(8.dp)
    ) {
        TempoSteps.forEach { step ->
            FilledTonalButton(
                onClick = {
                    onStep(step)
                },
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    if (step > 0) {
                        "+$step"
                    } else {
                        step.toString()
                    }
                )
            }
        }
    }
}

@Composable
private fun RhythmSettingsCard(
    state: MetronomeUiState,
    onMeter: (Int, Int) -> Unit,
    onSubdivision:
        (MetronomeSubdivision) -> Unit,
    onAccent: (Int) -> Unit,
    onClickSound: (ClickSound) -> Unit,
    onCountIn: (Int) -> Unit
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
            modifier = Modifier.padding(20.dp),
            verticalArrangement =
                Arrangement.spacedBy(14.dp)
        ) {
            SectionTitle(
                stringResource(
                    R.string.rhythm_settings
                )
            )

            Label(
                stringResource(
                    R.string.time_signature
                )
            )
            ChoiceRow {
                MeterPresets.forEach { meter ->
                    FilterChip(
                        selected =
                            state.beatsPerBar ==
                                meter.beats &&
                                state.beatUnit ==
                                meter.unit,
                        onClick = {
                            onMeter(
                                meter.beats,
                                meter.unit
                            )
                        },
                        label = {
                            Text(meter.label)
                        }
                    )
                }
            }

            Label(
                stringResource(
                    R.string.subdivision
                )
            )
            ChoiceRow {
                MetronomeSubdivision.entries
                    .forEach { subdivision ->
                        FilterChip(
                            selected =
                                state.subdivision ==
                                    subdivision,
                            onClick = {
                                onSubdivision(
                                    subdivision
                                )
                            },
                            label = {
                                Text(
                                    subdivision.label
                                )
                            }
                        )
                    }
            }

            Label(
                stringResource(
                    R.string.beat_accents
                )
            )
            Row(
                horizontalArrangement =
                    Arrangement.spacedBy(8.dp)
            ) {
                state.accents.forEachIndexed {
                        index,
                        accent ->

                    FilledTonalButton(
                        onClick = {
                            onAccent(index)
                        },
                        modifier =
                            Modifier.weight(1f)
                    ) {
                        Text(
                            when (accent) {
                                BeatAccent.ACCENT ->
                                    "●"
                                BeatAccent.NORMAL ->
                                    "○"
                                BeatAccent.MUTE ->
                                    "–"
                            }
                        )
                    }
                }
            }

            Label(
                stringResource(
                    R.string.click_sound
                )
            )
            ChoiceRow {
                ClickSound.entries.forEach {
                        sound ->
                    FilterChip(
                        selected =
                            state.clickSound == sound,
                        onClick = {
                            onClickSound(sound)
                        },
                        label = {
                            Text(
                                when (sound) {
                                    ClickSound.DIGITAL ->
                                        "Digital"
                                    ClickSound.WOOD ->
                                        "Wood"
                                    ClickSound.HI_HAT ->
                                        "Hi-hat"
                                }
                            )
                        }
                    )
                }
            }

            Label(
                stringResource(
                    R.string.count_in
                )
            )
            ChoiceRow {
                (0..2).forEach { bars ->
                    FilterChip(
                        selected =
                            state.countInBars == bars,
                        onClick = {
                            onCountIn(bars)
                        },
                        label = {
                            Text(
                                if (bars == 0) {
                                    stringResource(
                                        R.string.off
                                    )
                                } else {
                                    stringResource(
                                        R.string.bars_count,
                                        bars
                                    )
                                }
                            )
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun SpeedTrainerCard(
    state: MetronomeUiState,
    viewModel: MetronomeViewModel
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
            modifier = Modifier.padding(20.dp),
            verticalArrangement =
                Arrangement.spacedBy(12.dp)
        ) {
            Row(
                verticalAlignment =
                    Alignment.CenterVertically
            ) {
                Column(
                    modifier = Modifier.weight(1f)
                ) {
                    SectionTitle(
                        stringResource(
                            R.string.speed_trainer
                        )
                    )
                    Text(
                        text = stringResource(
                            R.string.speed_trainer_description
                        ),
                        style =
                            MaterialTheme.typography
                                .bodySmall,
                        color =
                            MaterialTheme.colorScheme
                                .onSurfaceVariant
                    )
                }
                Switch(
                    checked =
                        state.speedTrainerEnabled,
                    onCheckedChange =
                        viewModel::setSpeedTrainerEnabled
                )
            }

            if (state.speedTrainerEnabled) {
                TrainerValue(
                    label = stringResource(
                        R.string.start_bpm
                    ),
                    value = state.speedStartBpm,
                    range =
                        MetronomeConfig.MIN_BPM..
                            state.speedEndBpm,
                    onChange =
                        viewModel::setSpeedStartBpm
                )

                TrainerValue(
                    label = stringResource(
                        R.string.goal_bpm
                    ),
                    value = state.speedEndBpm,
                    range =
                        state.speedStartBpm..
                            MetronomeConfig.MAX_BPM,
                    onChange =
                        viewModel::setSpeedEndBpm
                )

                TrainerValue(
                    label = stringResource(
                        R.string.step_bpm
                    ),
                    value = state.speedStepBpm,
                    range = 1..20,
                    onChange =
                        viewModel::setSpeedStepBpm
                )

                TrainerValue(
                    label = stringResource(
                        R.string.bars_per_step
                    ),
                    value =
                        state.speedBarsPerStep,
                    range = 1..16,
                    onChange =
                        viewModel::setSpeedBarsPerStep
                )
            }
        }
    }
}

@Composable
private fun TrainerValue(
    label: String,
    value: Int,
    range: IntRange,
    onChange: (Int) -> Unit
) {
    Column {
        Row(
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                label,
                modifier = Modifier.weight(1f)
            )
            Text(
                value.toString(),
                color =
                    MaterialTheme.colorScheme
                        .primary
            )
        }
        Slider(
            value = value.toFloat(),
            onValueChange = {
                onChange(it.toInt())
            },
            valueRange =
                range.first.toFloat()..
                    range.last.toFloat()
        )
    }
}

@Composable
private fun ChoiceRow(
    content: @Composable RowScope.() -> Unit
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
private fun Label(text: String) {
    Text(
        text = text,
        style =
            MaterialTheme.typography.labelLarge,
        color =
            MaterialTheme.colorScheme
                .onSurfaceVariant
    )
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        style =
            MaterialTheme.typography.titleMedium
    )
}

@Composable
private fun PlaybackError(
    onDismiss: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme
                    .errorContainer
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    horizontal = 16.dp,
                    vertical = 8.dp
                ),
            verticalAlignment =
                Alignment.CenterVertically
        ) {
            Text(
                text = stringResource(
                    R.string.metronome_error
                ),
                color =
                    MaterialTheme.colorScheme
                        .onErrorContainer,
                modifier = Modifier.weight(1f)
            )
            TextButton(
                onClick = onDismiss
            ) {
                Text("OK")
            }
        }
    }
}


private fun isBluetoothAudioConnected(
    context: Context
): Boolean {
    val audioManager =
        context.getSystemService(
            Context.AUDIO_SERVICE
        ) as AudioManager

    return audioManager
        .getDevices(
            AudioManager.GET_DEVICES_OUTPUTS
        )
        .any { device ->
            when (device.type) {
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> true

                else -> {
                    if (
                        Build.VERSION.SDK_INT >= 31
                    ) {
                        device.type ==
                            AudioDeviceInfo.TYPE_BLE_HEADSET ||
                            device.type ==
                            AudioDeviceInfo.TYPE_BLE_SPEAKER
                    } else {
                        false
                    }
                }
            }
        }
}
