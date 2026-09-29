package dev.mirinnano.guitartools.music

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class TuningTest {
    @Test
    fun standardAndDropDTuningsHaveExpectedLowString() {
        assertEquals(40, Tuning.Standard.strings.first { it.stringNumber == 6 }.midi)
        assertEquals(38, Tuning.DropD.strings.first { it.stringNumber == 6 }.midi)
    }

    @Test
    fun closestStringMatchesLowEInStandardTuning() {
        val target = Tuning.Standard.closestString(
            frequencyHz = Note.frequencyForMidi(40)
        )

        assertNotNull(target)
        assertEquals(6, target?.string?.stringNumber)
        assertEquals("E2", target?.string?.label)
        assertEquals(0.0, target?.centsFromTarget ?: 99.0, 0.001)
    }

    @Test
    fun presetsHaveUniqueIds() {
        assertEquals(
            Tuning.Presets.size,
            Tuning.Presets.map { it.id }.toSet().size
        )
    }
}
