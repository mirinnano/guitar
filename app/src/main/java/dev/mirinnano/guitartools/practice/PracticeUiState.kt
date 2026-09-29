package dev.mirinnano.guitartools.practice

import dev.mirinnano.guitartools.song.SongSearchResult

data class PracticeUiState(
    val title: String = "コード進行練習",
    val artist: String = "",
    val progression: List<ProgressionStep> =
        listOf(
            ProgressionStep("C", "C"),
            ProgressionStep("G", "G"),
            ProgressionStep("Am", "Am"),
            ProgressionStep("F", "F")
        ),
    val bpm: Int = 80,
    val beatsPerBar: Int = 4,
    val beatUnit: Int = 4,
    val currentStepIndex: Int = 0,
    val beatInStep: Int = 0,
    val isPlaying: Boolean = false,
    val autoScroll: Boolean = true,
    val syncBackingTrack: Boolean = true,
    val syncOffsetMs: Long = 0L,
    val importText: String = "",
    val searchQuery: String = "",
    val searchResults: List<SongSearchResult> =
        emptyList(),
    val isSearching: Boolean = false,
    val searchError: String? = null,
    val selectedSong: SongSearchResult? = null
)
