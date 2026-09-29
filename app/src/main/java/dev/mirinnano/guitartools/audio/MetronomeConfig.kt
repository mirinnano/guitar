package dev.mirinnano.guitartools.audio

enum class MetronomeSubdivision(
    val pulsesPerBeat: Int,
    val label: String
) {
    QUARTER(1, "4分"),
    EIGHTH(2, "8分"),
    TRIPLET(3, "3連"),
    SIXTEENTH(4, "16分")
}

enum class BeatAccent {
    ACCENT,
    NORMAL,
    MUTE
}

enum class ClickSound {
    DIGITAL,
    WOOD,
    HI_HAT
}

data class BeatEvent(
    val beatInBar: Int,
    val subdivisionIndex: Int,
    val isCountIn: Boolean,
    val accent: BeatAccent
) {
    val isMainBeat: Boolean
        get() = subdivisionIndex == 0
}

data class MetronomeConfig(
    val bpm: Int = DEFAULT_BPM,
    val beatsPerBar: Int = DEFAULT_BEATS_PER_BAR,
    val beatUnit: Int = 4,
    val subdivision: MetronomeSubdivision = MetronomeSubdivision.QUARTER,
    val accents: List<BeatAccent> = defaultAccents(DEFAULT_BEATS_PER_BAR),
    val clickSound: ClickSound = ClickSound.DIGITAL,
    val countInBars: Int = 0
) {
    init {
        require(bpm in MIN_BPM..MAX_BPM)
        require(beatsPerBar in MIN_BEATS_PER_BAR..MAX_BEATS_PER_BAR)
        require(beatUnit in setOf(2, 4, 8, 16))
        require(accents.size == beatsPerBar)
        require(countInBars in 0..MAX_COUNT_IN_BARS)
    }

    fun accentForBeat(beat: Int): BeatAccent =
        accents[Math.floorMod(beat, accents.size)]

    companion object {
        const val MIN_BPM = 30
        const val MAX_BPM = 300
        const val DEFAULT_BPM = 120

        const val MIN_BEATS_PER_BAR = 1
        const val MAX_BEATS_PER_BAR = 12
        const val DEFAULT_BEATS_PER_BAR = 4
        const val MAX_COUNT_IN_BARS = 4

        fun defaultAccents(beatsPerBar: Int): List<BeatAccent> =
            List(beatsPerBar) { index ->
                if (index == 0) BeatAccent.ACCENT else BeatAccent.NORMAL
            }
    }
}
