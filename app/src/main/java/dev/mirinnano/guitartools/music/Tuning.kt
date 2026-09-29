package dev.mirinnano.guitartools.music

data class StringTuning(
    val stringNumber: Int,
    val midi: Int,
    val label: String
)

data class Tuning(
    val name: String,
    val strings: List<StringTuning>
) {
    companion object {
        val Standard = Tuning(
            name = "Standard",
            strings = listOf(
                StringTuning(6, 40, "E2"),
                StringTuning(5, 45, "A2"),
                StringTuning(4, 50, "D3"),
                StringTuning(3, 55, "G3"),
                StringTuning(2, 59, "B3"),
                StringTuning(1, 64, "E4")
            )
        )
    }
}
