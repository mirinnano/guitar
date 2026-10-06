import Foundation

public enum AccidentalPreference:
    Sendable,
    Hashable {
    case sharps
    case flats
}

public enum GuitarNote:
    Int,
    CaseIterable,
    Identifiable,
    Sendable,
    Hashable {

    case c = 0
    case cSharp
    case d
    case dSharp
    case e
    case f
    case fSharp
    case g
    case gSharp
    case a
    case aSharp
    case b

    public var id: Int { rawValue }

    public var displayName: String {
        displayName(.sharps)
    }

    public func displayName(
        _ preference:
            AccidentalPreference
    ) -> String {
        switch (
            self,
            preference
        ) {
        case (.c, _): "C"
        case (.cSharp, .sharps): "C#"
        case (.cSharp, .flats): "Db"
        case (.d, _): "D"
        case (.dSharp, .sharps): "D#"
        case (.dSharp, .flats): "Eb"
        case (.e, _): "E"
        case (.f, _): "F"
        case (.fSharp, .sharps): "F#"
        case (.fSharp, .flats): "Gb"
        case (.g, _): "G"
        case (.gSharp, .sharps): "G#"
        case (.gSharp, .flats): "Ab"
        case (.a, _): "A"
        case (.aSharp, .sharps): "A#"
        case (.aSharp, .flats): "Bb"
        case (.b, _): "B"
        }
    }

    public static func fromMIDI(
        _ midi: Int
    ) -> GuitarNote {
        let index =
            ((midi % 12) + 12) % 12

        return GuitarNote(
            rawValue: index
        )!
    }

    public static func octave(
        forMIDI midi: Int
    ) -> Int {
        Int(
            floor(
                Double(midi) / 12
            )
        ) - 1
    }

    /// Invalid inputs return MIDI 0; optional pitch/target APIs reject them.
    public static func nearestMIDI(
        frequencyHz: Double,
        a4Hz: Double = 440
    ) -> Int {
        guard frequencyHz.isFinite, frequencyHz > 0,
              a4Hz.isFinite, a4Hz > 0 else { return 0 }
        // Subtract logarithms to avoid overflow/underflow in frequencyHz / a4Hz.
        let midi = (69 + 12 * (log2(frequencyHz) - log2(a4Hz))).rounded()
        guard midi.isFinite, midi >= Double(Int.min), midi < Double(Int.max) else { return 0 }
        return Int(midi)
    }

    public static func frequency(
        forMIDI midi: Int,
        a4Hz: Double = 440
    ) -> Double {
        a4Hz *
        pow(
            2,
            (Double(midi) - 69) /
            12
        )
    }
}

public struct GuitarPitchReading:
    Sendable,
    Equatable {

    public let frequencyHz:
        Double
    public let midi: Int
    public let note:
        GuitarNote
    public let octave: Int
    public let cents:
        Double

    public init(
        frequencyHz: Double,
        midi: Int,
        note: GuitarNote,
        octave: Int,
        cents: Double
    ) {
        self.frequencyHz =
            frequencyHz
        self.midi = midi
        self.note = note
        self.octave = octave
        self.cents = cents
    }

    public static func fromFrequency(
        _ frequencyHz: Double,
        a4Hz: Double = 440
    ) -> GuitarPitchReading? {
        guard
            frequencyHz.isFinite,
            frequencyHz > 0,
            a4Hz.isFinite,
            a4Hz > 0
        else {
            return nil
        }

        let midi =
            GuitarNote.nearestMIDI(
                frequencyHz:
                    frequencyHz,
                a4Hz: a4Hz
            )

        let target =
            GuitarNote.frequency(
                forMIDI: midi,
                a4Hz: a4Hz
            )

        guard target.isFinite, target > 0 else { return nil }
        let cents = 1_200 * (log2(frequencyHz) - log2(target))
        guard cents.isFinite else { return nil }

        return GuitarPitchReading(
            frequencyHz:
                frequencyHz,
            midi: midi,
            note:
                GuitarNote
                    .fromMIDI(midi),
            octave:
                GuitarNote
                    .octave(
                        forMIDI: midi
                    ),
            cents: cents
        )
    }
}

public struct GuitarStringTuning:
    Identifiable,
    Sendable,
    Equatable,
    Hashable {

    public let stringNumber: Int
    public let midi: Int
    public let label: String

    public var id: Int {
        stringNumber
    }

    public init(
        stringNumber: Int,
        midi: Int,
        label: String
    ) {
        self.stringNumber =
            stringNumber
        self.midi = midi
        self.label = label
    }
}

public struct GuitarTuningTarget:
    Sendable,
    Equatable {

    public let string:
        GuitarStringTuning
    public let targetFrequencyHz:
        Double
    public let centsFromTarget:
        Double
}

public struct GuitarTuning:
    Identifiable,
    Sendable,
    Equatable,
    Hashable {

    public let id: String
    public let name: String
    public let strings:
        [GuitarStringTuning]
    public let accidentalPreference:
        AccidentalPreference

    public init(
        id: String,
        name: String,
        strings:
            [GuitarStringTuning],
        accidentalPreference:
            AccidentalPreference =
            .sharps
    ) {
        precondition(
            strings.count == 6
        )

        self.id = id
        self.name = name
        self.strings = strings
        self.accidentalPreference =
            accidentalPreference
    }

    public func closestString(
        frequencyHz: Double,
        a4Hz: Double = 440
    ) -> GuitarTuningTarget? {
        strings
            .compactMap {
                target(
                    stringNumber:
                        $0.stringNumber,
                    frequencyHz:
                        frequencyHz,
                    a4Hz: a4Hz
                )
            }
            .min {
                abs(
                    $0.centsFromTarget
                ) <
                abs(
                    $1.centsFromTarget
                )
            }
    }

    public func target(
        stringNumber: Int,
        frequencyHz: Double,
        a4Hz: Double = 440
    ) -> GuitarTuningTarget? {
        guard
            frequencyHz.isFinite,
            frequencyHz > 0,
            a4Hz.isFinite,
            a4Hz > 0,
            let string =
                strings.first(
                    where: {
                        $0.stringNumber ==
                        stringNumber
                    }
                )
        else {
            return nil
        }

        let target =
            GuitarNote.frequency(
                forMIDI:
                    string.midi,
                a4Hz: a4Hz
            )

        guard target.isFinite, target > 0 else { return nil }
        let cents = 1_200 * (log2(frequencyHz) - log2(target))
        guard cents.isFinite else { return nil }

        return GuitarTuningTarget(
            string: string,
            targetFrequencyHz: target,
            centsFromTarget: cents
        )
    }

    public func withStringMIDI(
        stringNumber: Int,
        midi: Int
    ) -> GuitarTuning {
        let safe =
            min(
                max(midi, 24),
                84
            )

        let updated =
            strings.map {
                string in

                guard
                    string
                        .stringNumber ==
                    stringNumber
                else {
                    return string
                }

                let note =
                    GuitarNote
                        .fromMIDI(safe)

                return GuitarStringTuning(
                    stringNumber:
                        stringNumber,
                    midi: safe,
                    label:
                        note.displayName(
                            accidentalPreference
                        ) +
                        String(
                            GuitarNote
                                .octave(
                                    forMIDI:
                                        safe
                                )
                        )
                )
            }

        return GuitarTuning(
            id: "custom",
            name: "Custom",
            strings: updated,
            accidentalPreference:
                accidentalPreference
        )
    }

    public static let standard =
        GuitarTuning(
            id: "standard",
            name: "Standard",
            strings: [
                .init(
                    stringNumber: 6,
                    midi: 40,
                    label: "E2"
                ),
                .init(
                    stringNumber: 5,
                    midi: 45,
                    label: "A2"
                ),
                .init(
                    stringNumber: 4,
                    midi: 50,
                    label: "D3"
                ),
                .init(
                    stringNumber: 3,
                    midi: 55,
                    label: "G3"
                ),
                .init(
                    stringNumber: 2,
                    midi: 59,
                    label: "B3"
                ),
                .init(
                    stringNumber: 1,
                    midi: 64,
                    label: "E4"
                )
            ]
        )

    public static let presets:
        [GuitarTuning] = [
            standard,
            GuitarTuning(
                id: "drop_d",
                name: "Drop D",
                strings: [
                    .init(
                        stringNumber: 6,
                        midi: 38,
                        label: "D2"
                    ),
                    .init(
                        stringNumber: 5,
                        midi: 45,
                        label: "A2"
                    ),
                    .init(
                        stringNumber: 4,
                        midi: 50,
                        label: "D3"
                    ),
                    .init(
                        stringNumber: 3,
                        midi: 55,
                        label: "G3"
                    ),
                    .init(
                        stringNumber: 2,
                        midi: 59,
                        label: "B3"
                    ),
                    .init(
                        stringNumber: 1,
                        midi: 64,
                        label: "E4"
                    )
                ]
            ),
            GuitarTuning(
                id: "drop_c_sharp",
                name: "Drop C#",
                strings: [
                    .init(
                        stringNumber: 6,
                        midi: 37,
                        label: "C#2"
                    ),
                    .init(
                        stringNumber: 5,
                        midi: 44,
                        label: "G#2"
                    ),
                    .init(
                        stringNumber: 4,
                        midi: 49,
                        label: "C#3"
                    ),
                    .init(
                        stringNumber: 3,
                        midi: 54,
                        label: "F#3"
                    ),
                    .init(
                        stringNumber: 2,
                        midi: 58,
                        label: "A#3"
                    ),
                    .init(
                        stringNumber: 1,
                        midi: 63,
                        label: "D#4"
                    )
                ]
            ),
            GuitarTuning(
                id: "drop_c",
                name: "Drop C",
                strings: [
                    .init(
                        stringNumber: 6,
                        midi: 36,
                        label: "C2"
                    ),
                    .init(
                        stringNumber: 5,
                        midi: 43,
                        label: "G2"
                    ),
                    .init(
                        stringNumber: 4,
                        midi: 48,
                        label: "C3"
                    ),
                    .init(
                        stringNumber: 3,
                        midi: 53,
                        label: "F3"
                    ),
                    .init(
                        stringNumber: 2,
                        midi: 57,
                        label: "A3"
                    ),
                    .init(
                        stringNumber: 1,
                        midi: 62,
                        label: "D4"
                    )
                ]
            ),
            GuitarTuning(
                id: "eb_standard",
                name: "E♭ Standard",
                strings: [
                    .init(
                        stringNumber: 6,
                        midi: 39,
                        label: "E♭2"
                    ),
                    .init(
                        stringNumber: 5,
                        midi: 44,
                        label: "A♭2"
                    ),
                    .init(
                        stringNumber: 4,
                        midi: 49,
                        label: "D♭3"
                    ),
                    .init(
                        stringNumber: 3,
                        midi: 54,
                        label: "G♭3"
                    ),
                    .init(
                        stringNumber: 2,
                        midi: 58,
                        label: "B♭3"
                    ),
                    .init(
                        stringNumber: 1,
                        midi: 63,
                        label: "E♭4"
                    )
                ],
                accidentalPreference:
                    .flats
            ),
            GuitarTuning(
                id: "d_standard",
                name: "D Standard",
                strings: [
                    .init(
                        stringNumber: 6,
                        midi: 38,
                        label: "D2"
                    ),
                    .init(
                        stringNumber: 5,
                        midi: 43,
                        label: "G2"
                    ),
                    .init(
                        stringNumber: 4,
                        midi: 48,
                        label: "C3"
                    ),
                    .init(
                        stringNumber: 3,
                        midi: 53,
                        label: "F3"
                    ),
                    .init(
                        stringNumber: 2,
                        midi: 57,
                        label: "A3"
                    ),
                    .init(
                        stringNumber: 1,
                        midi: 62,
                        label: "D4"
                    )
                ]
            ),
            GuitarTuning(
                id: "open_g",
                name: "Open G",
                strings: [
                    .init(
                        stringNumber: 6,
                        midi: 38,
                        label: "D2"
                    ),
                    .init(
                        stringNumber: 5,
                        midi: 43,
                        label: "G2"
                    ),
                    .init(
                        stringNumber: 4,
                        midi: 50,
                        label: "D3"
                    ),
                    .init(
                        stringNumber: 3,
                        midi: 55,
                        label: "G3"
                    ),
                    .init(
                        stringNumber: 2,
                        midi: 59,
                        label: "B3"
                    ),
                    .init(
                        stringNumber: 1,
                        midi: 62,
                        label: "D4"
                    )
                ]
            ),
            GuitarTuning(
                id: "dadgad",
                name: "DADGAD",
                strings: [
                    .init(
                        stringNumber: 6,
                        midi: 38,
                        label: "D2"
                    ),
                    .init(
                        stringNumber: 5,
                        midi: 45,
                        label: "A2"
                    ),
                    .init(
                        stringNumber: 4,
                        midi: 50,
                        label: "D3"
                    ),
                    .init(
                        stringNumber: 3,
                        midi: 55,
                        label: "G3"
                    ),
                    .init(
                        stringNumber: 2,
                        midi: 57,
                        label: "A3"
                    ),
                    .init(
                        stringNumber: 1,
                        midi: 62,
                        label: "D4"
                    )
                ]
            )
        ]

    public static let customDefault =
        GuitarTuning(
            id: "custom",
            name: "Custom",
            strings:
                standard.strings
        )
}

public enum GuitarScaleType:
    String,
    CaseIterable,
    Identifiable,
    Sendable,
    Hashable {

    case major = "Major"
    case naturalMinor = "Minor"
    case majorPentatonic =
        "Major Pentatonic"
    case minorPentatonic =
        "Minor Pentatonic"
    case blues = "Blues"
    case dorian = "Dorian"
    case mixolydian =
        "Mixolydian"

    public var id: String {
        rawValue
    }

    public var intervals: [Int] {
        switch self {
        case .major:
            [0, 2, 4, 5, 7, 9, 11]
        case .naturalMinor:
            [0, 2, 3, 5, 7, 8, 10]
        case .majorPentatonic:
            [0, 2, 4, 7, 9]
        case .minorPentatonic:
            [0, 3, 5, 7, 10]
        case .blues:
            [0, 3, 5, 6, 7, 10]
        case .dorian:
            [0, 2, 3, 5, 7, 9, 10]
        case .mixolydian:
            [0, 2, 4, 5, 7, 9, 10]
        }
    }

    public func notes(
        root: GuitarNote
    ) -> Set<GuitarNote> {
        Set(
            intervals.map {
                GuitarNote(
                    rawValue:
                        (
                            root.rawValue +
                            $0
                        ) % 12
                )!
            }
        )
    }
}

public func intervalLabel(
    root: GuitarNote,
    note: GuitarNote
) -> String {
    let value =
        (
            note.rawValue -
            root.rawValue +
            12
        ) % 12

    return [
        "1",
        "♭2",
        "2",
        "♭3",
        "3",
        "4",
        "♭5",
        "5",
        "♭6",
        "6",
        "♭7",
        "7"
    ][value]
}

public struct FretPosition:
    Identifiable,
    Sendable,
    Equatable {

    public let stringNumber: Int
    public let fret: Int
    public let midi: Int
    public let note: GuitarNote
    public let octave: Int

    public var id: String {
        "\(stringNumber):\(fret)"
    }
}

public enum GuitarFretboard {

    public static let defaultMaxFret =
        24

    public static func positions(
        tuning:
            GuitarTuning = .standard,
        maxFret: Int =
            defaultMaxFret
    ) -> [FretPosition] {
        tuning.strings.flatMap {
            string in

            (0...maxFret).map {
                fret in

                let midi =
                    string.midi +
                    fret

                return FretPosition(
                    stringNumber:
                        string.stringNumber,
                    fret: fret,
                    midi: midi,
                    note:
                        GuitarNote
                            .fromMIDI(
                                midi
                            ),
                    octave:
                        GuitarNote
                            .octave(
                                forMIDI:
                                    midi
                            )
                )
            }
        }
    }
}

public enum GuitarChordQuality:
    String,
    CaseIterable,
    Identifiable,
    Sendable,
    Hashable {

    case major = ""
    case minor = "m"
    case power5 = "5"
    case major6 = "6"
    case minor6 = "m6"
    case dominant7 = "7"
    case major7 = "maj7"
    case minor7 = "m7"
    case dominant9 = "9"
    case major9 = "maj9"
    case minor9 = "m9"
    case sus2 = "sus2"
    case sus4 = "sus4"
    case add9 = "add9"
    case diminished = "dim"
    case augmented = "aug"
    case halfDiminished7 = "m7(b5)"
    case diminished7 = "dim7"
    case dominant7Sus4 = "7sus4"
    case dominant7Flat9 = "7(b9)"
    case dominant7Sharp9 = "7(#9)"
    case dominant7Sus4Flat9 = "7sus4(b9)"
    case minorMajor7 = "m(maj7)"
    case minorAdd9 = "madd9"
    case majorSixNine = "6/9"
    case minorSixNine = "m6/9"
    case add11 = "add11"
    case dominant11 = "11"
    case minor11 = "m11"
    case dominant13 = "13"
    case minor13 = "m13"
    case dominant7Flat5 = "7(b5)"
    case dominant7Sharp5 = "7(#5)"
    case dominant7Flat13 = "7(b13)"
    case dominant7Sharp11 = "7(#11)"
    case major7Sharp11 = "maj7(#11)"
    case dominant9Sus4 = "9sus4"

    public var id: String {
        rawValue.isEmpty
        ? "major"
        : rawValue
    }

    public var displayName: String {
        rawValue.isEmpty
        ? "Major"
        : rawValue
    }

    public var intervals: [Int] {
        switch self {
        case .major:
            [0, 4, 7]
        case .minor:
            [0, 3, 7]
        case .power5:
            [0, 7]
        case .major6:
            [0, 4, 7, 9]
        case .minor6:
            [0, 3, 7, 9]
        case .dominant7:
            [0, 4, 7, 10]
        case .major7:
            [0, 4, 7, 11]
        case .minor7:
            [0, 3, 7, 10]
        case .dominant9:
            [0, 4, 7, 10, 14]
        case .major9:
            [0, 4, 7, 11, 14]
        case .minor9:
            [0, 3, 7, 10, 14]
        case .sus2:
            [0, 2, 7]
        case .sus4:
            [0, 5, 7]
        case .add9:
            [0, 4, 7, 14]
        case .diminished:
            [0, 3, 6]
        case .augmented:
            [0, 4, 8]
        case .halfDiminished7:
            [0, 3, 6, 10]
        case .diminished7:
            [0, 3, 6, 9]
        case .dominant7Sus4:
            [0, 5, 7, 10]
        case .dominant7Flat9:
            [0, 4, 7, 10, 13]
        case .dominant7Sharp9:
            [0, 4, 7, 10, 15]
        case .dominant7Sus4Flat9:
            [0, 5, 7, 10, 13]
        case .minorMajor7:
            [0, 3, 7, 11]
        case .minorAdd9:
            [0, 3, 7, 14]
        case .majorSixNine: [0, 4, 7, 9, 14]
        case .minorSixNine: [0, 3, 7, 9, 14]
        case .add11: [0, 4, 7, 17]
        case .dominant11: [0, 4, 7, 10, 14, 17]
        case .minor11: [0, 3, 7, 10, 14, 17]
        case .dominant13: [0, 4, 7, 10, 14, 17, 21]
        case .minor13: [0, 3, 7, 10, 14, 17, 21]
        case .dominant7Flat5: [0, 4, 6, 10]
        case .dominant7Sharp5: [0, 4, 8, 10]
        case .dominant7Flat13: [0, 4, 7, 10, 20]
        case .dominant7Sharp11: [0, 4, 7, 10, 18]
        case .major7Sharp11: [0, 4, 7, 11, 18]
        case .dominant9Sus4: [0, 5, 7, 10, 14]
        }
    }
}

public struct GuitarChord:
    Sendable,
    Equatable,
    Hashable {

    public let root: GuitarNote
    public let quality:
        GuitarChordQuality

    public init(
        root: GuitarNote,
        quality: GuitarChordQuality
    ) {
        self.root = root
        self.quality = quality
    }

    public var name: String {
        root.displayName +
        quality.rawValue
    }

    public var notes:
        [GuitarNote] {
        Array(
            Set(
                quality.intervals.map {
                    GuitarNote
                        .fromMIDI(
                            root.rawValue +
                            $0
                        )
                }
            )
        )
        .sorted {
            $0.rawValue <
            $1.rawValue
        }
    }
}

public struct GuitarBarre:
    Sendable,
    Equatable,
    Hashable {

    public let fret: Int
    public let fromString: Int
    public let toString: Int
    public let finger: Int
}

public struct GuitarChordShape:
    Identifiable,
    Sendable,
    Equatable {

    public let chord: GuitarChord
    public let frets: [Int]
    public let fingers: [Int?]
    public let barres:
        [GuitarBarre]
    public let baseFret: Int

    public var id: String {
        chord.name
    }

    public var name: String {
        chord.name
    }
}

public enum CommonGuitarChords {

    public static let all: [GuitarChordShape] = GuitarNote.allCases.flatMap { root in
        GuitarChordQuality.allCases.compactMap { quality in
            NoCapoGuitarVoicings.resolve(chord: GuitarChord(root: root, quality: quality))
        }
    }

    public static func forRoot(_ root: GuitarNote) -> [GuitarChordShape] {
        all.filter { $0.chord.root == root }
    }

    public static func shape(named name: String) -> GuitarChordShape? {
        guard let symbol = ParsedGuitarChordSymbol(name) else { return nil }
        return NoCapoGuitarVoicings.resolve(chord: symbol.chord, bass: symbol.bass)
    }
}

/// Canonical root/quality key. Bass is parsed and validated, but is not part of
/// this legacy catalog key; shape(named:) resolves the complete symbol instead.
public func normalizeChordLookup(_ raw: String) -> String? {
    ParsedGuitarChordSymbol(raw)?.chord.name
}
