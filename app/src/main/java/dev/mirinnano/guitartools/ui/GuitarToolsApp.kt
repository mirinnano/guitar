package dev.mirinnano.guitartools.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.GridOn
import androidx.compose.material.icons.rounded.LibraryMusic
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import dev.mirinnano.guitartools.ui.chords.ChordsScreen
import dev.mirinnano.guitartools.ui.fretboard.FretboardScreen
import dev.mirinnano.guitartools.ui.metronome.MetronomeScreen
import dev.mirinnano.guitartools.ui.tuner.TunerScreen

private enum class ToolTab(
    val title: String,
    val label: String,
    val icon: ImageVector
) {
    Metronome("Metronome", "Metro", Icons.Rounded.Timer),
    Tuner("Tuner", "Tuner", Icons.Rounded.GraphicEq),
    Chords("Chords", "Chords", Icons.Rounded.LibraryMusic),
    Fretboard("Fretboard", "Fretboard", Icons.Rounded.GridOn)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GuitarToolsApp() {
    var selected by remember { mutableStateOf(ToolTab.Metronome) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(selected.title) }
            )
        },
        bottomBar = {
            NavigationBar {
                ToolTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = selected == tab,
                        onClick = { selected = tab },
                        icon = {
                            Icon(
                                imageVector = tab.icon,
                                contentDescription = tab.title
                            )
                        },
                        label = { Text(tab.label) }
                    )
                }
            }
        }
    ) { padding ->
        val modifier = Modifier.padding(padding)

        when (selected) {
            ToolTab.Metronome -> MetronomeScreen(modifier)
            ToolTab.Tuner -> TunerScreen(modifier)
            ToolTab.Chords -> ChordsScreen(modifier)
            ToolTab.Fretboard -> FretboardScreen(modifier)
        }
    }
}
