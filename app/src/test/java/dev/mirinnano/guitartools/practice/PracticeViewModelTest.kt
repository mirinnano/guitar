package dev.mirinnano.guitartools.practice

import dev.mirinnano.guitartools.MainDispatcherRule
import dev.mirinnano.guitartools.audio.BeatAccent
import dev.mirinnano.guitartools.audio.BeatEvent
import dev.mirinnano.guitartools.audio.MetronomeConfig
import dev.mirinnano.guitartools.audio.MetronomePlayer
import dev.mirinnano.guitartools.song.SongSearchProvider
import dev.mirinnano.guitartools.song.SongSearchResult
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PracticeViewModelTest {

    @get:Rule
    val mainDispatcherRule =
        MainDispatcherRule()

    @Test
    fun progressionAdvancesOnMainBeats() {
        val player =
            FakeMetronomePlayer()

        val viewModel =
            PracticeViewModel(
                metronome = player,
                songProvider =
                    FakeSongProvider()
            )

        viewModel.togglePlayback()

        repeat(4) {
            player.beat(
                BeatEvent(
                    beatInBar = it,
                    subdivisionIndex = 0,
                    isCountIn = false,
                    accent =
                        BeatAccent.NORMAL
                )
            )
        }

        assertEquals(
            1,
            viewModel.uiState.value
                .currentStepIndex
        )
        assertEquals(
            0,
            viewModel.uiState.value
                .beatInStep
        )
    }

    @Test
    fun countInDoesNotAdvanceProgression() {
        val player =
            FakeMetronomePlayer()

        val viewModel =
            PracticeViewModel(
                metronome = player,
                songProvider =
                    FakeSongProvider()
            )

        viewModel.togglePlayback()

        repeat(4) {
            player.beat(
                BeatEvent(
                    beatInBar = it,
                    subdivisionIndex = 0,
                    isCountIn = true,
                    accent =
                        BeatAccent.NORMAL
                )
            )
        }

        assertEquals(
            0,
            viewModel.uiState.value
                .currentStepIndex
        )
        assertEquals(
            0,
            viewModel.uiState.value
                .beatInStep
        )
    }

    @Test
    fun backingTrackPositionSelectsMatchingChord() {
        val viewModel =
            PracticeViewModel(
                metronome =
                    FakeMetronomePlayer(),
                songProvider =
                    FakeSongProvider()
            )

        viewModel.setBpm(80)
        viewModel.syncToPlaybackPosition(
            3_000L
        )

        assertEquals(
            1,
            viewModel.uiState.value
                .currentStepIndex
        )
        assertEquals(
            0,
            viewModel.uiState.value
                .beatInStep
        )
    }


    @Test
    fun backingTrackOffsetDelaysChordSync() {
        val viewModel =
            PracticeViewModel(
                metronome =
                    FakeMetronomePlayer(),
                songProvider =
                    FakeSongProvider()
            )

        viewModel.setBpm(80)
        viewModel.setSyncOffsetMs(
            3_000L
        )

        viewModel.syncToPlaybackPosition(
            3_000L
        )

        assertEquals(
            0,
            viewModel.uiState.value
                .currentStepIndex
        )
        assertEquals(
            0,
            viewModel.uiState.value
                .beatInStep
        )

        viewModel.syncToPlaybackPosition(
            6_000L
        )

        assertEquals(
            1,
            viewModel.uiState.value
                .currentStepIndex
        )
        assertEquals(
            0,
            viewModel.uiState.value
                .beatInStep
        )
    }

    @Test
    fun selectingSongAppliesAvailableBpm() {
        val viewModel =
            PracticeViewModel(
                metronome =
                    FakeMetronomePlayer(),
                songProvider =
                    FakeSongProvider()
            )

        viewModel.selectSong(
            SongSearchResult(
                id = "1",
                title = "Song",
                artist = "Artist",
                bpm = 128,
                timeSignature = "6/8",
                sourceName = "test"
            )
        )

        assertEquals(
            128,
            viewModel.uiState.value.bpm
        )
        assertEquals(
            "Song",
            viewModel.uiState.value.title
        )
        assertEquals(
            6,
            viewModel.uiState.value
                .beatsPerBar
        )
        assertEquals(
            8,
            viewModel.uiState.value
                .beatUnit
        )
    }

    @Test
    fun songSearchExposesResults() = runTest {
        val result =
            SongSearchResult(
                id = "1",
                title = "Song",
                artist = "Artist",
                bpm = 120,
                sourceName = "test"
            )

        val viewModel =
            PracticeViewModel(
                metronome =
                    FakeMetronomePlayer(),
                songProvider =
                    FakeSongProvider(
                        listOf(result)
                    )
            )

        viewModel.setSearchQuery("Song")
        viewModel.searchSongs()
        advanceUntilIdle()

        assertFalse(
            viewModel.uiState.value
                .isSearching
        )
        assertEquals(
            listOf(result),
            viewModel.uiState.value
                .searchResults
        )
    }

    private class FakeSongProvider(
        private val results:
            List<SongSearchResult> =
            emptyList()
    ) : SongSearchProvider {
        override suspend fun search(
            query: String
        ): List<SongSearchResult> =
            results
    }

    private class FakeMetronomePlayer :
        MetronomePlayer {

        override var isRunning:
            Boolean = false

        private var onBeat:
            ((BeatEvent) -> Unit)? = null

        override fun start(
            configProvider:
                () -> MetronomeConfig,
            onBeat:
                (BeatEvent) -> Unit,
            onError:
                (Throwable) -> Unit
        ) {
            isRunning = true
            this.onBeat = onBeat
        }

        override fun stop() {
            isRunning = false
        }

        fun beat(event: BeatEvent) {
            onBeat?.invoke(event)
        }
    }
}
