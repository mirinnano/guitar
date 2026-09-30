package dev.mirinnano.guitartools.chordwiki

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ChordWikiUiState(
    val query: String = "",
    val results: List<ChordWikiSearchResult> =
        emptyList(),
    val selectedSong: ChordWikiSong? = null,
    val isSearching: Boolean = false,
    val isLoadingSong: Boolean = false,
    val hasSearched: Boolean = false,
    val error: String? = null
)

class ChordWikiViewModel(
    private val client: ChordWikiClient =
        ChordWikiClient()
) : ViewModel() {

    private val _uiState =
        MutableStateFlow(ChordWikiUiState())

    val uiState: StateFlow<ChordWikiUiState> =
        _uiState.asStateFlow()

    private var searchJob: Job? = null
    private var loadJob: Job? = null

    fun setQuery(
        value: String
    ) {
        _uiState.update {
            it.copy(query = value)
        }
    }

    fun search() {
        val query =
            _uiState.value.query.trim()

        if (query.isEmpty()) {
            return
        }

        searchJob?.cancel()
        searchJob =
            viewModelScope.launch {
                _uiState.update {
                    it.copy(
                        isSearching = true,
                        hasSearched = true,
                        error = null
                    )
                }

                runCatching {
                    client.search(query)
                }.onSuccess { results ->
                    _uiState.update {
                        it.copy(
                            results = results,
                            isSearching = false,
                            error = null
                        )
                    }
                }.onFailure { error ->
                    _uiState.update {
                        it.copy(
                            results = emptyList(),
                            isSearching = false,
                            error =
                                error.message
                                    ?: "ChordWikiの検索に失敗しました"
                        )
                    }
                }
            }
    }

    fun openSong(
        result: ChordWikiSearchResult
    ) {
        loadJob?.cancel()
        loadJob =
            viewModelScope.launch {
                _uiState.update {
                    it.copy(
                        isLoadingSong = true,
                        error = null
                    )
                }

                runCatching {
                    client.loadSong(result)
                }.onSuccess { song ->
                    _uiState.update {
                        it.copy(
                            selectedSong = song,
                            isLoadingSong = false,
                            error = null
                        )
                    }
                }.onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoadingSong = false,
                            error =
                                error.message
                                    ?: "ChordWikiの譜面を取得できませんでした"
                        )
                    }
                }
            }
    }

    fun closeSong() {
        loadJob?.cancel()
        _uiState.update {
            it.copy(
                selectedSong = null,
                isLoadingSong = false,
                error = null
            )
        }
    }

    override fun onCleared() {
        searchJob?.cancel()
        loadJob?.cancel()
    }
}
