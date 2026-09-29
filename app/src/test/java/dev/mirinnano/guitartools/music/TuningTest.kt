package dev.mirinnano.guitartools.music

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class TuningTest {

    @Test
    fun commonTuningsHaveExpectedLowString() {
        assertEquals(
            40,
            Tuning.Standard.strings
                .first {
                    it.stringNumber == 6
                }.midi
        )
        assertEquals(
            38,
            Tuning.DropD.strings
                .first {
                    it.stringNumber == 6
                }.midi
        )
        assertEquals(
            36,
            Tuning.DropC.strings
                .first {
                    it.stringNumber == 6
                }.midi
        )
    }

    @Test
    fun closestStringMatchesLowE() {
        val target =
            Tuning.Standard.closestString(
                frequencyHz =
                    Note.frequencyForMidi(40)
            )

        assertNotNull(target)
        assertEquals(
            6,
            target?.string?.stringNumber
        )
        assertEquals(
            0.0,
            target?.centsFromTarget
                ?: 99.0,
            0.001
        )
    }

    @Test
    fun lockedStringTargetsRequestedString() {
        val target =
            Tuning.Standard.targetForString(
                stringNumber = 5,
                frequencyHz =
                    Note.frequencyForMidi(45)
            )

        assertEquals(
            5,
            target?.string?.stringNumber
        )
        assertEquals(
            0.0,
            target?.centsFromTarget
                ?: 99.0,
            0.001
        )
    }

    @Test
    fun customTuningCanChangeOneString() {
        val custom =
            Tuning.CustomDefault
                .withStringMidi(
                    stringNumber = 6,
                    midi = 38
                )

        assertEquals("custom", custom.id)
        assertEquals(
            38,
            custom.strings.first {
                it.stringNumber == 6
            }.midi
        )
        assertEquals(
            "D2",
            custom.strings.first {
                it.stringNumber == 6
            }.label
        )
    }

    @Test
    fun presetsHaveUniqueIds() {
        assertEquals(
            Tuning.Presets.size,
            Tuning.Presets
                .map { it.id }
                .toSet()
                .size
        )
    }
}
