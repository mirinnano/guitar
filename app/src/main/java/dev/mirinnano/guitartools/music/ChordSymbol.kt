package dev.mirinnano.guitartools.music

private val RootSemitones = mapOf(
    'C' to 0,
    'D' to 2,
    'E' to 4,
    'F' to 5,
    'G' to 7,
    'A' to 9,
    'B' to 11
)

fun normalizeChordLookup(
    raw: String
): String? {
    var symbol = raw
        .trim()
        .replace("♯", "#")
        .replace("♭", "b")

    if (
        symbol.equals("N.C.", true) ||
        symbol.equals("NC", true)
    ) {
        return null
    }

    symbol =
        symbol.substringBefore("/")
            .trim()

    val match =
        Regex(
            "^([A-Ga-g])([#b]?)(.*)$"
        ).matchEntire(symbol)
            ?: return null

    val rootLetter =
        match.groupValues[1]
            .uppercase()
            .single()

    val accidental =
        match.groupValues[2]

    val rawSuffix =
        match.groupValues[3]
            .trim()
            .replace("△", "maj")
            .replace("M", "maj")

    val base =
        RootSemitones[rootLetter]
            ?: return null

    val semitone = Math.floorMod(
        base +
            when (accidental) {
                "#" -> 1
                "b" -> -1
                else -> 0
            },
        12
    )

    val root =
        Note.entries[semitone]
            .displayName

    val suffix =
        normalizeSuffix(rawSuffix)
            ?: return null

    return root + suffix
}

private fun normalizeSuffix(
    raw: String
): String? {
    val suffix =
        raw
            .replace("(", "")
            .replace(")", "")
            .replace(" ", "")

    return when {
        suffix.isEmpty() -> ""
        suffix == "m" -> "m"
        suffix == "5" -> "5"
        suffix == "6" -> "6"
        suffix == "m6" -> "m6"
        suffix == "7" -> "7"
        suffix.equals(
            "maj7",
            ignoreCase = true
        ) -> "maj7"
        suffix == "m7" -> "m7"
        suffix == "9" -> "9"
        suffix.equals(
            "maj9",
            ignoreCase = true
        ) -> "maj9"
        suffix == "m9" -> "m9"
        suffix.equals(
            "sus2",
            ignoreCase = true
        ) -> "sus2"
        suffix.equals(
            "sus4",
            ignoreCase = true
        ) -> "sus4"
        suffix.equals(
            "sus",
            ignoreCase = true
        ) -> "sus4"
        suffix.equals(
            "add9",
            ignoreCase = true
        ) -> "add9"
        suffix.equals(
            "dim",
            ignoreCase = true
        ) -> "dim"
        suffix.equals(
            "aug",
            ignoreCase = true
        ) || suffix == "+" -> "aug"
        else -> null
    }
}
