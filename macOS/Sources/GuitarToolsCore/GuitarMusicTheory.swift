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

    public static func nearestMIDI(
        frequencyHz: Double,
        a4Hz: Double = 440
    ) -> Int {
        Int(
            (
                69 +
                12 *
                log2(
                    frequencyHz /
                    a4Hz
                )
            ).rounded()
        )
    }

    public static func frequency(
        forMIDI midi: Int,
        a4Hz: Double = 440
    ) -> Double {
        a4Hz *
        pow(
            2,
            Double(midi - 69) /
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
            frequencyHz > 0,
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

        let cents =
            1_200 *
            log2(
                frequencyHz /
                target
            )

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
            frequencyHz > 0,
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

        return GuitarTuningTarget(
            string: string,
            targetFrequencyHz:
                target,
            centsFromTarget:
                1_200 *
                log2(
                    frequencyHz /
                    target
                )
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

    private struct Template {
        let offsets: [Int]
        let fingers: [Int?]
        let fullBarre: Bool
    }

    private static let templates:
        [GuitarChordQuality:
            Template] = [
        .major:
            .init(
                offsets:
                    [0, 2, 2, 1, 0, 0],
                fingers:
                    [1, 3, 4, 2, 1, 1],
                fullBarre: true
            ),
        .minor:
            .init(
                offsets:
                    [0, 2, 2, 0, 0, 0],
                fingers:
                    [1, 3, 4, 1, 1, 1],
                fullBarre: true
            ),
        .power5:
            .init(
                offsets:
                    [0, 2, 2, -1, -1, -1],
                fingers:
                    [1, 3, 4, nil, nil, nil],
                fullBarre: false
            ),
        .major6:
            .init(
                offsets:
                    [0, 2, 2, 1, 2, 0],
                fingers:
                    [1, 2, 3, 1, 4, 1],
                fullBarre: true
            ),
        .minor6:
            .init(
                offsets:
                    [0, 2, 2, 0, 2, 0],
                fingers:
                    [1, 2, 3, 1, 4, 1],
                fullBarre: true
            ),
        .dominant7:
            .init(
                offsets:
                    [0, 2, 0, 1, 0, 0],
                fingers:
                    [1, 3, 1, 2, 1, 1],
                fullBarre: true
            ),
        .major7:
            .init(
                offsets:
                    [0, 2, 1, 1, 0, 0],
                fingers:
                    [1, 3, 2, 2, 1, 1],
                fullBarre: true
            ),
        .minor7:
            .init(
                offsets:
                    [0, 2, 0, 0, 0, 0],
                fingers:
                    [1, 3, 1, 1, 1, 1],
                fullBarre: true
            ),
        .dominant9:
            .init(
                offsets:
                    [0, 2, 0, 1, 0, 2],
                fingers:
                    [1, 3, 1, 2, 1, 4],
                fullBarre: true
            ),
        .major9:
            .init(
                offsets:
                    [0, 2, 1, 1, 0, 2],
                fingers:
                    [1, 3, 2, 2, 1, 4],
                fullBarre: true
            ),
        .minor9:
            .init(
                offsets:
                    [0, 2, 0, 0, 0, 2],
                fingers:
                    [1, 3, 1, 1, 1, 4],
                fullBarre: true
            ),
        .sus2:
            .init(
                offsets:
                    [0, 2, 4, 4, 0, 0],
                fingers:
                    [1, 2, 3, 4, 1, 1],
                fullBarre: true
            ),
        .sus4:
            .init(
                offsets:
                    [0, 2, 2, 2, 0, 0],
                fingers:
                    [1, 3, 3, 3, 1, 1],
                fullBarre: true
            ),
        .add9:
            .init(
                offsets:
                    [0, 2, 2, 1, 0, 2],
                fingers:
                    [1, 2, 3, 1, 1, 4],
                fullBarre: true
            ),
        .diminished:
            .init(
                offsets:
                    [0, 1, 2, 0, -1, -1],
                fingers:
                    [1, 2, 4, 3, nil, nil],
                fullBarre: false
            ),
        .augmented:
            .init(
                offsets:
                    [0, 3, 2, 1, 1, 0],
                fingers:
                    [1, 4, 3, 2, 2, 1],
                fullBarre: true
            )
    ]

    public static let all:
        [GuitarChordShape] =
        GuitarNote.allCases
            .flatMap {
                root in

                GuitarChordQuality
                    .allCases
                    .map {
                        quality in

                        preferredShape(
                            root: root,
                            quality:
                                quality
                        ) ??
                        movableShape(
                            root: root,
                            quality:
                                quality
                        )
                    }
            }

    public static func forRoot(
        _ root: GuitarNote
    ) -> [GuitarChordShape] {
        all.filter {
            $0.chord.root ==
            root
        }
    }

    public static func shape(
        named name: String
    ) -> GuitarChordShape? {
        guard let normalized =
            normalizeChordLookup(name)
        else {
            return nil
        }

        return all.first {
            $0.name ==
            normalized
        }
    }

    private static func movableShape(
        root: GuitarNote,
        quality:
            GuitarChordQuality
    ) -> GuitarChordShape {
        let template =
            templates[quality]!

        let rootFret =
            (
                root.rawValue -
                GuitarNote.e.rawValue +
                12
            ) % 12

        let frets =
            template.offsets.map {
                $0 < 0
                ? -1
                : rootFret + $0
            }

        let barres:
            [GuitarBarre] =
            rootFret > 0 &&
            template.fullBarre
            ? [
                GuitarBarre(
                    fret: rootFret,
                    fromString: 6,
                    toString: 1,
                    finger: 1
                )
            ]
            : []

        let fingers =
            rootFret == 0
            ? template.fingers
                .enumerated()
                .map {
                    index,
                    finger in

                    frets[index] == 0
                    ? nil
                    : finger
                }
            : template.fingers

        return GuitarChordShape(
            chord:
                GuitarChord(
                    root: root,
                    quality: quality
                ),
            frets: frets,
            fingers: fingers,
            barres: barres,
            baseFret:
                max(rootFret, 1)
        )
    }

    private static func preferredShape(
        root: GuitarNote,
        quality:
            GuitarChordQuality
    ) -> GuitarChordShape? {
        let key =
            root.displayName +
            quality.rawValue

        let values:
            [String:
                (
                    [Int],
                    [Int?]
                )] = [
            "C":
                (
                    [-1, 3, 2, 0, 1, 0],
                    [nil, 3, 2, nil, 1, nil]
                ),
            "D":
                (
                    [-1, -1, 0, 2, 3, 2],
                    [nil, nil, nil, 1, 3, 2]
                ),
            "E":
                (
                    [0, 2, 2, 1, 0, 0],
                    [nil, 2, 3, 1, nil, nil]
                ),
            "G":
                (
                    [3, 2, 0, 0, 0, 3],
                    [2, 1, nil, nil, nil, 3]
                ),
            "A":
                (
                    [-1, 0, 2, 2, 2, 0],
                    [nil, nil, 1, 2, 3, nil]
                ),
            "Am":
                (
                    [-1, 0, 2, 2, 1, 0],
                    [nil, nil, 2, 3, 1, nil]
                ),
            "Dm":
                (
                    [-1, -1, 0, 2, 3, 1],
                    [nil, nil, nil, 2, 3, 1]
                ),
            "Em":
                (
                    [0, 2, 2, 0, 0, 0],
                    [nil, 2, 3, nil, nil, nil]
                ),
            "C7":
                (
                    [-1, 3, 2, 3, 1, 0],
                    [nil, 3, 2, 4, 1, nil]
                ),
            "D7":
                (
                    [-1, -1, 0, 2, 1, 2],
                    [nil, nil, nil, 2, 1, 3]
                ),
            "E7":
                (
                    [0, 2, 0, 1, 0, 0],
                    [nil, 2, nil, 1, nil, nil]
                ),
            "G7":
                (
                    [3, 2, 0, 0, 0, 1],
                    [3, 2, nil, nil, nil, 1]
                ),
            "A7":
                (
                    [-1, 0, 2, 0, 2, 0],
                    [nil, nil, 1, nil, 2, nil]
                ),
            "B7":
                (
                    [-1, 2, 1, 2, 0, 2],
                    [nil, 2, 1, 3, nil, 4]
                ),
            "Cmaj7":
                (
                    [-1, 3, 2, 0, 0, 0],
                    [nil, 3, 2, nil, nil, nil]
                ),
            "Am7":
                (
                    [-1, 0, 2, 0, 1, 0],
                    [nil, nil, 2, nil, 1, nil]
                ),
            "Em7":
                (
                    [0, 2, 0, 0, 0, 0],
                    [nil, 2, nil, nil, nil, nil]
                ),
            "Dsus2":
                (
                    [-1, -1, 0, 2, 3, 0],
                    [nil, nil, nil, 1, 2, nil]
                ),
            "Asus2":
                (
                    [-1, 0, 2, 2, 0, 0],
                    [nil, nil, 1, 2, nil, nil]
                ),
            "Dsus4":
                (
                    [-1, -1, 0, 2, 3, 3],
                    [nil, nil, nil, 1, 2, 3]
                ),
            "Asus4":
                (
                    [-1, 0, 2, 2, 3, 0],
                    [nil, nil, 1, 2, 3, nil]
                ),
            "Cadd9":
                (
                    [-1, 3, 2, 0, 3, 0],
                    [nil, 2, 1, nil, 3, nil]
                )
        ]

        guard let value =
            values[key]
        else {
            return nil
        }

        return GuitarChordShape(
            chord:
                GuitarChord(
                    root: root,
                    quality: quality
                ),
            frets: value.0,
            fingers: value.1,
            barres: [],
            baseFret: 1
        )
    }
}

public func normalizeChordLookup(
    _ raw: String
) -> String? {
    var symbol =
        raw
            .trimmingCharacters(
                in: .whitespaces
            )
            .replacingOccurrences(
                of: "♯",
                with: "#"
            )
            .replacingOccurrences(
                of: "♭",
                with: "b"
            )

    if symbol.uppercased() ==
        "N.C." ||
        symbol.uppercased() ==
        "NC" {
        return nil
    }

    symbol =
        String(
            symbol.split(
                separator: "/"
            ).first ?? ""
        )
        .trimmingCharacters(
            in: .whitespaces
        )

    let pattern =
        #"^([A-Ga-g])([#b]?)(.*)$"#

    guard
        let regex =
            try? NSRegularExpression(
                pattern: pattern
            )
    else {
        return nil
    }

    let ns =
        symbol as NSString

    guard let match =
        regex.firstMatch(
            in: symbol,
            range: NSRange(
                location: 0,
                length: ns.length
            )
        )
    else {
        return nil
    }

    let letter =
        ns.substring(
            with:
                match.range(at: 1)
        )
        .uppercased()

    let accidental =
        ns.substring(
            with:
                match.range(at: 2)
        )

    var suffix =
        ns.substring(
            with:
                match.range(at: 3)
        )
        .trimmingCharacters(
            in: .whitespaces
        )
        .replacingOccurrences(
            of: "△",
            with: "maj"
        )
        .replacingOccurrences(
            of: "M",
            with: "maj"
        )
        .replacingOccurrences(
            of: "(",
            with: ""
        )
        .replacingOccurrences(
            of: ")",
            with: ""
        )
        .replacingOccurrences(
            of: " ",
            with: ""
        )

    let base:
        Int

    switch letter {
    case "C": base = 0
    case "D": base = 2
    case "E": base = 4
    case "F": base = 5
    case "G": base = 7
    case "A": base = 9
    case "B": base = 11
    default:
        return nil
    }

    let offset =
        accidental == "#"
        ? 1
        : accidental == "b"
        ? -1
        : 0

    let root =
        GuitarNote(
            rawValue:
                (
                    base +
                    offset +
                    12
                ) % 12
        )!
        .displayName

    suffix =
        suffix.lowercased()

    let allowed:
        Set<String> = [
            "",
            "m",
            "5",
            "6",
            "m6",
            "7",
            "maj7",
            "m7",
            "9",
            "maj9",
            "m9",
            "sus2",
            "sus4",
            "add9",
            "dim",
            "aug"
        ]

    if suffix == "sus" {
        suffix = "sus4"
    }

    if suffix == "+" {
        suffix = "aug"
    }

    guard
        allowed.contains(
            suffix
        )
    else {
        return nil
    }

    return root + suffix
}
