package dev.mirinnano.guitartools.ui.fretboard

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import dev.mirinnano.guitartools.R
import dev.mirinnano.guitartools.music.Chord
import dev.mirinnano.guitartools.music.ChordQuality
import dev.mirinnano.guitartools.music.Note
import dev.mirinnano.guitartools.music.ScaleType
import dev.mirinnano.guitartools.music.Tuning
import dev.mirinnano.guitartools.music.intervalLabel
import dev.mirinnano.guitartools.ui.components.FretboardDiagram

private enum class FretboardMode {
    NOTE,
    SCALE,
    CHORD
}

private enum class FretboardLabelMode {
    NOTE,
    INTERVAL
}

@Composable
fun FretboardScreen(
    modifier: Modifier = Modifier
) {
    var tuning by remember {
        mutableStateOf(Tuning.Standard)
    }
    var mode by remember {
        mutableStateOf(FretboardMode.SCALE)
    }
    var root by remember {
        mutableStateOf(Note.C)
    }
    var scale by remember {
        mutableStateOf(ScaleType.MINOR_PENTATONIC)
    }
    var chordQuality by remember {
        mutableStateOf(ChordQuality.MAJOR)
    }
    var labelMode by remember {
        mutableStateOf(FretboardLabelMode.NOTE)
    }
    var leftHanded by remember {
        mutableStateOf(false)
    }
    var zoom by remember {
        mutableFloatStateOf(56f)
    }

    val highlightedNotes =
        when (mode) {
            FretboardMode.NOTE ->
                setOf(root)

            FretboardMode.SCALE ->
                scale.notes(root)

            FretboardMode.CHORD ->
                Chord(
                    root = root,
                    quality = chordQuality
                ).notes.toSet()
        }

    val labels =
        Note.entries.associateWith { note ->
            when (labelMode) {
                FretboardLabelMode.NOTE ->
                    note.displayName(
                        tuning.accidentalPreference
                    )

                FretboardLabelMode.INTERVAL ->
                    intervalLabel(
                        root = root,
                        note = note
                    )
            }
        }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(
                horizontal = 16.dp,
                vertical = 12.dp
            ),
        verticalArrangement =
            Arrangement.spacedBy(12.dp)
    ) {
        SettingsCard {
            SettingsLabel(
                stringResource(R.string.fretboard_mode)
            )

            ChoiceRow {
                FretboardMode.entries.forEach { item ->
                    FilterChip(
                        selected = mode == item,
                        onClick = {
                            mode = item
                        },
                        label = {
                            Text(
                                when (item) {
                                    FretboardMode.NOTE ->
                                        stringResource(
                                            R.string.single_note
                                        )

                                    FretboardMode.SCALE ->
                                        stringResource(
                                            R.string.scale
                                        )

                                    FretboardMode.CHORD ->
                                        stringResource(
                                            R.string.tab_chords
                                        )
                                }
                            )
                        }
                    )
                }
            }

            SettingsLabel(
                stringResource(R.string.root_note)
            )

            ChoiceRow {
                Note.entries.forEach { note ->
                    FilterChip(
                        selected = root == note,
                        onClick = {
                            root = note
                        },
                        label = {
                            Text(
                                note.displayName(
                                    tuning.accidentalPreference
                                )
                            )
                        }
                    )
                }
            }

            if (mode == FretboardMode.SCALE) {
                ChoiceRow {
                    ScaleType.entries.forEach { type ->
                        FilterChip(
                            selected = scale == type,
                            onClick = {
                                scale = type
                            },
                            label = {
                                Text(type.displayName)
                            }
                        )
                    }
                }
            }

            if (mode == FretboardMode.CHORD) {
                ChoiceRow {
                    ChordQuality.entries.forEach { quality ->
                        FilterChip(
                            selected =
                                chordQuality == quality,
                            onClick = {
                                chordQuality = quality
                            },
                            label = {
                                Text(
                                    if (
                                        quality.symbol.isBlank()
                                    ) {
                                        "Major"
                                    } else {
                                        quality.symbol
                                    }
                                )
                            }
                        )
                    }
                }
            }
        }

        SettingsCard {
            SettingsLabel(
                stringResource(R.string.tuning)
            )

            ChoiceRow {
                Tuning.Presets.forEach { preset ->
                    FilterChip(
                        selected = tuning.id == preset.id,
                        onClick = {
                            tuning = preset
                        },
                        label = {
                            Text(preset.name)
                        }
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text =
                        stringResource(
                            R.string.interval_labels
                        ),
                    modifier = Modifier.weight(1f)
                )
                Switch(
                    checked =
                        labelMode ==
                            FretboardLabelMode.INTERVAL,
                    onCheckedChange = {
                        labelMode =
                            if (it) {
                                FretboardLabelMode.INTERVAL
                            } else {
                                FretboardLabelMode.NOTE
                            }
                    }
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text =
                        stringResource(
                            R.string.left_handed
                        ),
                    modifier = Modifier.weight(1f)
                )
                Switch(
                    checked = leftHanded,
                    onCheckedChange = {
                        leftHanded = it
                    }
                )
            }

            SettingsLabel(
                stringResource(R.string.zoom)
            )

            Slider(
                value = zoom,
                onValueChange = {
                    zoom = it
                },
                valueRange = 40f..84f
            )
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor =
                    MaterialTheme.colorScheme.surfaceContainerLowest
            )
        ) {
            FretboardDiagram(
                tuning = tuning,
                maxFret = 24,
                highlightedNotes = highlightedNotes,
                rootNote = root,
                labels = labels,
                leftHanded = leftHanded,
                cellWidth = zoom.dp,
                modifier = Modifier.padding(12.dp)
            )
        }

        Text(
            text =
                stringResource(
                    R.string.fretboard_footer_24
                ),
            style =
                MaterialTheme.typography.bodySmall,
            color =
                MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun SettingsCard(
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme.surfaceContainerLow
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement =
                Arrangement.spacedBy(10.dp),
            content = content
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
private fun SettingsLabel(
    text: String
) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelLarge,
        color =
            MaterialTheme.colorScheme.onSurfaceVariant
    )
}
