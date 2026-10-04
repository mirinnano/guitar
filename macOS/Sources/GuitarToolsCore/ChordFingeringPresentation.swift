import Foundation

/// Keeps the written concert-pitch chord separate from its canonical shape name.
public struct ChordFingeringPresentation: Sendable, Equatable {
    public enum Availability: Sendable, Equatable {
        case supported
        case noChord
        case unavailable
    }

    public let symbol: String
    public let availability: Availability
    public let shape: GuitarChordShape?
    /// Written spelling of the actual, verified lowest sounding slash bass.
    /// Numeric 6/9 qualities and unavailable shapes do not have a slash bass.
    public let slashBass: String?
    /// Musically optional written chord tones absent from this six-string shape.
    /// Root, characteristic tones, alterations and requested bass are never omitted.
    public let omittedNotes: [GuitarNote]

    public var isSimplified: Bool { !omittedNotes.isEmpty }

    public init(symbol: String, voicingID: String? = nil) {
        let writtenSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        self.symbol = writtenSymbol
        if ["NC", "N.C."].contains(writtenSymbol.uppercased()) {
            availability = .noChord
            shape = nil
            slashBass = nil
            omittedNotes = []
            return
        }
        guard let parsed = GuitarChordData.parsedSymbol(writtenSymbol),
              let resolved = NoCapoGuitarVoicings.resolve(chord: parsed.chord, bass: parsed.bass) else {
            availability = .unavailable
            shape = nil
            slashBass = nil
            omittedNotes = []
            return
        }
        // Default rendering keeps the old fast resolver path. Only a requested
        // selection consults the lazy variant cache; foreign/stale IDs cannot
        // inject an unchecked shape or change the requested lowest bass.
        let selected: GuitarChordShape
        if let voicingID {
            let key = GuitarChordData.key(parsed)
            selected = NoCapoGuitarVoicings.variants(chord: parsed.chord, bass: parsed.bass)
                .first { GuitarChordVoicing(shape: $0, selectionKey: key).id == voicingID } ?? resolved
        } else {
            selected = resolved
        }
        shape = selected
        availability = .supported
        slashBass = parsed.bassSpelling
        let sounded = Set(zip(GuitarTuning.standard.strings, selected.frets).compactMap { string, fret in
            fret < 0 ? nil : GuitarNote.fromMIDI(string.midi + fret)
        })
        omittedNotes = Set(parsed.chord.notes).subtracting(sounded).sorted { $0.rawValue < $1.rawValue }
    }
}
