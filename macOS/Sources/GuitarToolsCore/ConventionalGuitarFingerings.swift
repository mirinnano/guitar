import Foundation

/// A deliberately small teaching catalog, not a synonym for mathematically
/// playable. Frets, individual fingers and the complete barre spans are curated
/// together. Every candidate still passes the resolver's pitch/bass/hand checks.
///
/// References for the familiar open and E/A-derived families and inversions:
/// https://www.guitar-chord.org/barre-chords.html
/// https://www.guitar-chord.org/maj7.html
/// https://www.guitar-chord.org/barre-chords-sus.html
/// https://www.guitar-chord.org/c-inversions.html
/// https://www.guitar-chord.org/g-inversions.html
/// https://www.guitar-chord.org/am-inversions.html
/// These conventions still require musical validation. The common open C7
/// x32310 uses the documented optional perfect fifth of plain dominant7; its
/// third and b7 stay mandatory. Unusual stretched E-shape sus2 grips are left to
/// the unclassified generator.
/// This catalog never calls resolve/variants or CommonGuitarChords.all.
enum ConventionalGuitarFingerings {
    private struct Key: Hashable {
        let chord: GuitarChord
        let bass: GuitarNote
    }

    private struct Fingering {
        let frets: [Int]
        let fingers: [Int?]
        let barres: [GuitarBarre]

        init(_ frets: [Int], _ fingers: [Int?], _ barres: [GuitarBarre] = []) {
            self.frets = frets
            self.fingers = fingers
            self.barres = barres
        }

        func shape(chord: GuitarChord) -> GuitarChordShape {
            GuitarChordShape(chord: chord, frets: frets, fingers: fingers, barres: barres,
                             baseFret: frets.contains(0) ? 1 : frets.filter { $0 > 0 }.min() ?? 1)
        }
    }

    private struct Template {
        let quality: GuitarChordQuality
        let root: GuitarNote
        let fingering: Fingering

        func shapes(chord: GuitarChord) -> [GuitarChordShape] {
            let position = (chord.root.rawValue - root.rawValue + 12) % 12
            // The zero position is an open chord, with its own finger assignment,
            // not a barre at the nut. Its octave remains a useful alternative.
            let first = position == 0 ? 12 : position
            return stride(from: first, through: 15, by: 12).compactMap { fret in
                let frets = fingering.frets.map { $0 < 0 ? -1 : $0 + fret }
                guard frets.allSatisfy({ $0 <= 15 }) else { return nil }
                let barres = fingering.barres.map {
                    GuitarBarre(fret: $0.fret + fret, fromString: $0.fromString,
                                toString: $0.toString, finger: $0.finger)
                }
                return GuitarChordShape(chord: chord, frets: frets, fingers: fingering.fingers,
                                        barres: barres, baseFret: fret)
            }
        }
    }

    // Preserve the established open defaults and their individual assignments.
    // C7 is the familiar fifth-omitting teaching form, not an incomplete triad.
    private static let openDefaults: [String: Fingering] = [
        "C": .init([-1,3,2,0,1,0], [nil,3,2,nil,1,nil]),
        "D": .init([-1,-1,0,2,3,2], [nil,nil,nil,1,3,2]),
        "E": .init([0,2,2,1,0,0], [nil,2,3,1,nil,nil]),
        "G": .init([3,2,0,0,0,3], [2,1,nil,nil,nil,3]),
        "A": .init([-1,0,2,2,2,0], [nil,nil,1,2,3,nil]),
        "Am": .init([-1,0,2,2,1,0], [nil,nil,2,3,1,nil]),
        "Dm": .init([-1,-1,0,2,3,1], [nil,nil,nil,2,3,1]),
        "Em": .init([0,2,2,0,0,0], [nil,2,3,nil,nil,nil]),
        "C7": .init([-1,3,2,3,1,0], [nil,3,2,4,1,nil]),
        "D7": .init([-1,-1,0,2,1,2], [nil,nil,nil,2,1,3]),
        "E7": .init([0,2,0,1,0,0], [nil,2,nil,1,nil,nil]),
        "G7": .init([3,2,0,0,0,1], [3,2,nil,nil,nil,1]),
        "A7": .init([-1,0,2,0,2,0], [nil,nil,1,nil,2,nil]),
        "B7": .init([-1,2,1,2,0,2], [nil,2,1,3,nil,4]),
        "Cmaj7": .init([-1,3,2,0,0,0], [nil,3,2,nil,nil,nil]),
        "Dmaj7": .init([-1,-1,0,2,2,2], [nil,nil,nil,1,1,1], [
            GuitarBarre(fret: 2, fromString: 3, toString: 1, finger: 1)
        ]),
        "Emaj7": .init([0,2,1,1,0,0], [nil,3,1,2,nil,nil]),
        "Fmaj7": .init([-1,-1,3,2,1,0], [nil,nil,3,2,1,nil]),
        "Gmaj7": .init([3,2,0,0,0,2], [3,2,nil,nil,nil,1]),
        "Amaj7": .init([-1,0,2,1,2,0], [nil,nil,2,1,3,nil]),
        "Am7": .init([-1,0,2,0,1,0], [nil,nil,2,nil,1,nil]),
        "Dm7": .init([-1,-1,0,2,1,1], [nil,nil,nil,2,1,1], [
            GuitarBarre(fret: 1, fromString: 2, toString: 1, finger: 1)
        ]),
        "Em7": .init([0,2,0,0,0,0], [nil,2,nil,nil,nil,nil]),
        "Dsus2": .init([-1,-1,0,2,3,0], [nil,nil,nil,1,2,nil]),
        "Asus2": .init([-1,0,2,2,0,0], [nil,nil,1,2,nil,nil]),
        "Dsus4": .init([-1,-1,0,2,3,3], [nil,nil,nil,1,2,3]),
        "Esus4": .init([0,2,2,2,0,0], [nil,2,3,4,nil,nil]),
        "Asus4": .init([-1,0,2,2,3,0], [nil,nil,1,2,3,nil]),
        "D7sus4": .init([-1,-1,0,2,1,3], [nil,nil,nil,2,1,3]),
        "E7sus4": .init([0,2,0,2,0,0], [nil,2,nil,3,nil,nil]),
        "A7sus4": .init([-1,0,2,0,3,0], [nil,nil,2,nil,3,nil]),
        "Cadd9": .init([-1,3,2,0,3,0], [nil,2,1,nil,3,nil])
    ]

    private static let openAlternatives: [String: [Fingering]] = [
        "C": [.init([-1,3,2,0,1,3], [nil,3,2,nil,1,4])],
        "G": [.init([3,2,0,0,3,3], [2,1,nil,nil,3,4])],
        "A": [.init([-1,0,2,2,2,0], [nil,nil,1,1,1,nil], [
            GuitarBarre(fret: 2, fromString: 4, toString: 2, finger: 1)
        ])],
        // The partial F is an alternative, never a replacement for 133211.
        "F": [.init([-1,-1,3,2,1,1], [nil,nil,3,2,1,1], [
            GuitarBarre(fret: 1, fromString: 2, toString: 1, finger: 1)
        ])],
        "Am7": [.init([-1,0,2,0,1,3], [nil,nil,2,nil,1,3])],
        "Bm7": [.init([-1,2,0,2,0,2], [nil,1,nil,2,nil,3])],
        "Em7": [.init([0,2,2,0,3,3], [nil,1,2,nil,3,4])],
        "Cadd9": [.init([-1,3,2,0,3,3], [nil,2,1,nil,3,4])]
    ]

    private static let slashFingerings: [Key: [Fingering]] = [
        Key(chord: .init(root: .c, quality: .major), bass: .e): [
            .init([0,3,2,0,1,0], [nil,3,2,nil,1,nil]),
            .init([-1,-1,2,0,1,0], [nil,nil,2,nil,1,nil])
        ],
        Key(chord: .init(root: .c, quality: .major), bass: .g): [
            // Separate ring/pinky on the two bass notes; no ring-finger barre.
            .init([3,3,2,0,1,0], [3,4,2,nil,1,nil]),
            .init([3,-1,2,0,1,0], [3,nil,2,nil,1,nil])
        ],
        Key(chord: .init(root: .g, quality: .major), bass: .b): [
            // Both are common; x20033 retains the familiar four-finger G top.
            .init([-1,2,0,0,3,3], [nil,1,nil,nil,3,4]),
            .init([-1,2,0,0,0,3], [nil,1,nil,nil,nil,3])
        ],
        Key(chord: .init(root: .g, quality: .major), bass: .d): [
            .init([-1,-1,0,0,0,3], [nil,nil,nil,nil,nil,3])
        ],
        Key(chord: .init(root: .a, quality: .minor), bass: .c): [
            // Keep the three Am fingers; add the pinky for the C bass.
            .init([-1,3,2,2,1,0], [nil,4,2,3,1,nil])
        ],
        Key(chord: .init(root: .a, quality: .minor), bass: .e): [
            .init([0,0,2,2,1,0], [nil,nil,2,3,1,nil])
        ],
        Key(chord: .init(root: .a, quality: .minor), bass: .g): [
            .init([3,0,2,2,1,0], [4,nil,2,3,1,nil])
        ],
        Key(chord: .init(root: .a, quality: .major), bass: .cSharp): [
            .init([-1,4,2,2,2,0], [nil,4,1,2,3,nil])
        ],
        Key(chord: .init(root: .a, quality: .major), bass: .e): [
            .init([0,0,2,2,2,0], [nil,nil,1,2,3,nil])
        ],
        Key(chord: .init(root: .d, quality: .major), bass: .a): [
            .init([-1,0,0,2,3,2], [nil,nil,nil,1,3,2])
        ],
        Key(chord: .init(root: .d, quality: .minor), bass: .a): [
            .init([-1,0,0,2,3,1], [nil,nil,nil,2,3,1])
        ],
        Key(chord: .init(root: .e, quality: .major), bass: .b): [
            .init([-1,2,2,1,0,0], [nil,2,3,1,nil,nil])
        ],
        Key(chord: .init(root: .e, quality: .minor), bass: .b): [
            .init([-1,2,2,0,0,0], [nil,2,3,nil,nil,nil])
        ],
        Key(chord: .init(root: .c, quality: .major7), bass: .e): [
            .init([0,3,2,0,0,0], [nil,3,2,nil,nil,nil])
        ],
        Key(chord: .init(root: .c, quality: .major7), bass: .g): [
            .init([3,3,2,0,0,0], [3,4,2,nil,nil,nil])
        ]
    ]

    // Barre frets here are offsets too. Separate fingers on E/Am-form fifth and
    // root notes are intentional: a minimum-finger grouping is not the familiar
    // F/Bm teaching assignment. A-major uses the standard four-finger option;
    // the equally common ring-barre option mutes the top E and is an alternative.
    private static let eBarre = GuitarBarre(fret: 0, fromString: 6, toString: 1, finger: 1)
    private static let aBarre = GuitarBarre(fret: 0, fromString: 5, toString: 1, finger: 1)
    private static let templates: [Template] = [
        .init(quality: .major, root: .e,
              fingering: .init([0,2,2,1,0,0], [1,3,4,2,1,1], [eBarre])),
        .init(quality: .minor, root: .e,
              fingering: .init([0,2,2,0,0,0], [1,3,4,1,1,1], [eBarre])),
        .init(quality: .dominant7, root: .e,
              fingering: .init([0,2,0,1,0,0], [1,3,1,2,1,1], [eBarre])),
        .init(quality: .minor7, root: .e,
              fingering: .init([0,2,0,0,0,0], [1,3,1,1,1,1], [eBarre])),
        .init(quality: .major7, root: .e,
              fingering: .init([0,2,1,1,0,0], [1,4,2,3,1,1], [eBarre])),
        .init(quality: .sus4, root: .e,
              fingering: .init([0,2,2,2,0,0], [1,3,3,3,1,1], [eBarre,
                  GuitarBarre(fret: 2, fromString: 5, toString: 3, finger: 3)
              ])),
        .init(quality: .dominant7Sus4, root: .e,
              fingering: .init([0,2,0,2,0,0], [1,3,1,4,1,1], [eBarre])),
        .init(quality: .major, root: .a,
              fingering: .init([-1,0,2,2,2,0], [nil,1,2,3,4,1], [aBarre])),
        .init(quality: .major, root: .a,
              fingering: .init([-1,0,2,2,2,-1], [nil,1,3,3,3,nil], [
                  GuitarBarre(fret: 2, fromString: 4, toString: 2, finger: 3)
              ])),
        .init(quality: .minor, root: .a,
              fingering: .init([-1,0,2,2,1,0], [nil,1,3,4,2,1], [aBarre])),
        .init(quality: .dominant7, root: .a,
              fingering: .init([-1,0,2,0,2,0], [nil,1,3,1,4,1], [aBarre])),
        .init(quality: .minor7, root: .a,
              fingering: .init([-1,0,2,0,1,0], [nil,1,3,1,2,1], [aBarre])),
        .init(quality: .major7, root: .a,
              fingering: .init([-1,0,2,1,2,0], [nil,1,3,2,4,1], [aBarre])),
        .init(quality: .sus2, root: .a,
              fingering: .init([-1,0,2,2,0,0], [nil,1,3,4,1,1], [aBarre])),
        .init(quality: .sus4, root: .a,
              fingering: .init([-1,0,2,2,3,0], [nil,1,2,3,4,1], [aBarre])),
        .init(quality: .dominant7Sus4, root: .a,
              fingering: .init([-1,0,2,0,3,0], [nil,1,3,1,4,1], [aBarre]))
    ]

    /// Raw lookup is kept separate from verification for independent regression
    /// tests. Only shapes(), never these candidates, is used to resolve a chord.
    static func candidates(chord: GuitarChord, bass: GuitarNote) -> [GuitarChordShape] {
        guard bass == chord.root else {
            return (slashFingerings[Key(chord: chord, bass: bass)] ?? []).map { $0.shape(chord: chord) }
        }
        let movable = templates.filter { $0.quality == chord.quality }.flatMap { $0.shapes(chord: chord) }
        // Prefer the lower familiar E/A grip. Keep table order for ties (the
        // fully sounded A-major option before its muted-top ring-barre option).
        let ordered = movable.enumerated().sorted {
            $0.element.baseFret == $1.element.baseFret
                ? $0.offset < $1.offset : $0.element.baseFret < $1.element.baseFret
        }.map { $0.element }
        let alternatives = (openAlternatives[chord.name] ?? []).map { $0.shape(chord: chord) }
        if let open = openDefaults[chord.name] {
            return [open.shape(chord: chord)] + alternatives + ordered
        }
        // Full F/Bm etc. remain the default. Familiar partial/open alternatives
        // follow that default before less approachable higher-neck barres.
        return Array(ordered.prefix(1)) + alternatives + Array(ordered.dropFirst())
    }

    static func shapes(chord: GuitarChord, bass: GuitarNote) -> [GuitarChordShape] {
        candidates(chord: chord, bass: bass).compactMap {
            NoCapoGuitarVoicings.checkedCandidate($0, bass: bass)
        }
    }

    static func contains(_ shape: GuitarChordShape) -> Bool {
        guard shape.frets.count == 6,
              let lowest = zip([40,45,50,55,59,64], shape.frets)
                .compactMap({ midi, fret in fret < 0 ? nil : midi + fret }).min() else { return false }
        let bass = GuitarNote.fromMIDI(lowest)
        return shapes(chord: shape.chord, bass: bass).contains {
            $0.frets == shape.frets && $0.fingers == shape.fingers &&
            Set($0.barres) == Set(shape.barres) && $0.barres.count == shape.barres.count &&
            $0.baseFret == shape.baseFret
        }
    }
}
