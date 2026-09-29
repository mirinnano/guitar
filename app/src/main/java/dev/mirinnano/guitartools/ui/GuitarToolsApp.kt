package dev.mirinnano.guitartools.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import dev.mirinnano.guitartools.ui.chords.ChordsScreen
import dev.mirinnano.guitartools.ui.fretboard.FretboardScreen
import dev.mirinnano.guitartools.ui.metronome.MetronomeScreen
import dev.mirinnano.guitartools.ui.tuner.TunerScreen

private enum class ToolTab(val label: String, val glyph: String) {
    Metronome("Metro", "♩"),
    Tuner("Tuner", "♪"),
    Chords("Chords", "C"),
    Fretboard("Fret", "⌗")
}

@Composable
fun GuitarToolsApp() {
    var selected by remember { mutableStateOf(ToolTab.Metronome) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                ToolTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = selected == tab,
                        onClick = { selected = tab },
                        icon = { Text(tab.glyph) },
                        label = { Text(tab.label) }
                    )
                }
            }
        }
    ) { padding ->
        when (selected) {
            ToolTab.Metronome -> MetronomeScreen(Modifier.padding(padding))
            ToolTab.Tuner -> TunerScreen(Modifier.padding(padding))
            ToolTab.Chords -> ChordsScreen(Modifier.padding(padding))
            ToolTab.Fretboard -> FretboardScreen(Modifier.padding(padding))
        }
    }
}
