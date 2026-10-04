import Foundation

/// A strict chord parser shared by no-capo voicing and concert-pitch transposition.
/// Numeric 6/9 is a quality; only a final slash followed by a note is a bass.
struct ParsedGuitarChordSymbol {
    let chord: GuitarChord
    let bass: GuitarNote?
    let rootSpelling: String
    let qualitySpelling: String
    let bassSpelling: String?

    init?(_ raw: String) {
        guard let written = GuitarChordLexeme(raw),
              let quality = Self.quality(written.qualitySpelling),
              let root = Self.note(written.rootSpelling) else { return nil }
        chord = GuitarChord(root: root, quality: quality)
        bass = written.bassSpelling.flatMap(Self.note)
        rootSpelling = written.rootSpelling
        qualitySpelling = written.qualitySpelling
        bassSpelling = written.bassSpelling
    }

    static func note(_ text: String) -> GuitarNote? {
        guard (1...2).contains(text.count), let letter = text.first else { return nil }
        let bases: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard let upper = letter.uppercased().first, let base = bases[upper] else { return nil }
        var offset = 0
        if text.count == 2 {
            switch text.last! {
            case "#", "♯": offset = 1
            case "b", "♭": offset = -1
            default: return nil
            }
        }
        return GuitarNote.fromMIDI(base + offset)
    }

    private static func quality(_ written: String) -> GuitarChordQuality? {
        let text = written.replacingOccurrences(of: "♯", with: "#")
            .replacingOccurrences(of: "♭", with: "b")
            .replacingOccurrences(of: "△", with: "maj")
            .replacingOccurrences(of: "Δ", with: "maj")
            .filter { !$0.isWhitespace }
        var depth = 0
        var suffix = ""
        for character in text {
            if character == "(" { depth += 1 }
            else if character == ")" {
                depth -= 1
                guard depth >= 0 else { return nil }
            } else { suffix.append(character) }
        }
        guard depth == 0 else { return nil }
        suffix = ["M": "", "M7": "maj7", "M9": "maj9", "mM7": "mmaj7"][suffix] ?? suffix.lowercased()
        let aliases: [String: GuitarChordQuality] = [
            "maj": .major, "min": .minor,
            "sus": .sus4, "+": .augmented, "m7b5": .halfDiminished7, "m7-5": .halfDiminished7, "ø7": .halfDiminished7,
            "°7": .diminished7, "7sus": .dominant7Sus4, "7b9": .dominant7Flat9,
            "7#9": .dominant7Sharp9, "7sus4b9": .dominant7Sus4Flat9,
            "7susb9": .dominant7Sus4Flat9, "mmaj7": .minorMajor7,
            "7b5": .dominant7Flat5, "7#5": .dominant7Sharp5, "7b13": .dominant7Flat13,
            "7#11": .dominant7Sharp11, "maj7#11": .major7Sharp11, "9sus": .dominant9Sus4
        ]
        return aliases[suffix] ?? GuitarChordQuality(rawValue: suffix)
    }
}

/// Lexical spelling is intentionally independent of the supported voicing list:
/// capo conversion may preserve an unsupported alteration without degrading it.
private struct GuitarChordLexeme {
    let rootSpelling: String
    let qualitySpelling: String
    let bassSpelling: String?

    init?(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = text.first, "ABCDEFGabcdefg".contains(first) else { return nil }
        var end = text.index(after: text.startIndex)
        if end < text.endIndex, "#b♯♭".contains(text[end]) { end = text.index(after: end) }
        let rootText = String(text[..<end])
        guard ParsedGuitarChordSymbol.note(rootText) != nil else { return nil }
        var suffix = String(text[end...]).trimmingCharacters(in: .whitespaces)
        var bassText: String?
        if let slash = suffix.lastIndex(of: "/") {
            let tail = String(suffix[suffix.index(after: slash)...]).trimmingCharacters(in: .whitespaces)
            if ParsedGuitarChordSymbol.note(tail) != nil {
                bassText = tail
                suffix = String(suffix[..<slash]).trimmingCharacters(in: .whitespaces)
            }
        }
        // Numeric slash is accepted only as the specific 6/9 quality.
        let compact = suffix.filter { !$0.isWhitespace }
        if compact.contains("/"), !["6/9", "m6/9"].contains(compact) { return nil }
        guard compact.range(of: #"^(?:maj|min|dim|aug|sus|add|m|M|[0-9#b♯♭+ø°△Δ()/,-])*$"#,
                            options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
        var depth = 0
        for character in compact {
            if character == "(" { depth += 1 }
            if character == ")" { depth -= 1 }
            if depth < 0 { return nil }
        }
        guard depth == 0 else { return nil }
        rootSpelling = rootText
        qualitySpelling = suffix
        bassSpelling = bassText
    }
}

public enum ChordSymbolTransposition {
    /// Preserves quality spelling verbatim, including unsupported alterations.
    /// Malformed symbols return nil; voicing support is checked separately.
    /// Flats and Unicode accidentals retain their spelling style when transposed.
    public static func transpose(_ symbol: String, semitones: Int) -> String? {
        guard let parsed = GuitarChordLexeme(symbol), let root = ParsedGuitarChordSymbol.note(parsed.rootSpelling) else { return nil }
        func shifted(_ note: GuitarNote, spelling: String) -> String {
            if semitones % 12 == 0 { return spelling }
            let preference: AccidentalPreference = spelling.contains("b") || spelling.contains("♭") ? .flats : .sharps
            var result = GuitarNote.fromMIDI(note.rawValue + semitones % 12).displayName(preference)
            if spelling.contains("♭") { result = result.replacingOccurrences(of: "b", with: "♭") }
            if spelling.contains("♯") { result = result.replacingOccurrences(of: "#", with: "♯") }
            return result
        }
        var result = shifted(root, spelling: parsed.rootSpelling) + parsed.qualitySpelling
        if let spelling = parsed.bassSpelling, let bass = ParsedGuitarChordSymbol.note(spelling) {
            result += "/" + shifted(bass, spelling: spelling)
        }
        return result
    }
}
