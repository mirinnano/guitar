package dev.mirinnano.guitartools.ui

import androidx.annotation.StringRes
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.GridOn
import androidx.compose.material.icons.rounded.LibraryMusic
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.School
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import dev.mirinnano.guitartools.R
import dev.mirinnano.guitartools.ui.chords.ChordsScreen
import dev.mirinnano.guitartools.ui.chordwiki.ChordWikiScreen
import dev.mirinnano.guitartools.ui.fretboard.FretboardScreen
import dev.mirinnano.guitartools.ui.metronome.MetronomeScreen
import dev.mirinnano.guitartools.practice.PracticeScreen
import dev.mirinnano.guitartools.ui.tuner.TunerScreen

private enum class ToolTab(
    @StringRes val titleRes: Int,
    val icon: ImageVector
) {
    Metronome(R.string.tab_metronome, Icons.Rounded.Timer),
    Tuner(R.string.tab_tuner, Icons.Rounded.GraphicEq),
    Chords(R.string.tab_chords, Icons.Rounded.LibraryMusic),
    ChordWiki(R.string.tab_chordwiki, Icons.Rounded.MusicNote),
    Fretboard(R.string.tab_fretboard, Icons.Rounded.GridOn),
    Practice(R.string.tab_practice, Icons.Rounded.School)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GuitarToolsApp() {
    var selectedTab by remember {
        mutableStateOf(ToolTab.Metronome)
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.surface,
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = stringResource(selectedTab.titleRes),
                        style = MaterialTheme.typography.titleLarge
                    )
                }
            )
        },
        bottomBar = {
            NavigationBar {
                ToolTab.entries.forEach { tab ->
                    val label = stringResource(tab.titleRes)

                    NavigationBarItem(
                        selected = selectedTab == tab,
                        onClick = { selectedTab = tab },
                        icon = {
                            Icon(
                                imageVector = tab.icon,
                                contentDescription = label
                            )
                        },
                        label = {
                            Text(label)
                        }
                    )
                }
            }
        }
    ) { contentPadding ->
        val screenModifier = Modifier.padding(contentPadding)

        when (selectedTab) {
            ToolTab.Metronome -> MetronomeScreen(screenModifier)
            ToolTab.Tuner -> TunerScreen(screenModifier)
            ToolTab.Chords -> ChordsScreen(screenModifier)
            ToolTab.ChordWiki -> ChordWikiScreen(screenModifier)
            ToolTab.Fretboard -> FretboardScreen(screenModifier)
            ToolTab.Practice -> PracticeScreen(screenModifier)
        }
    }
}
