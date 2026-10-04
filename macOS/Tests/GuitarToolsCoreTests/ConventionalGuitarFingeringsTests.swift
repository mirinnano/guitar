import XCTest
@testable import GuitarToolsCore

final class ConventionalGuitarFingeringsTests: XCTestCase {
    private let tuning = [40,45,50,55,59,64]
    // Independent musical expectations, never copied from quality.intervals.
    private let intervals: [GuitarChordQuality: [Int]] = [
        .major: [0,4,7], .minor: [0,3,7], .dominant7: [0,4,7,10],
        .minor7: [0,3,7,10], .major7: [0,4,7,11], .sus2: [0,2,7],
        .sus4: [0,5,7], .dominant7Sus4: [0,5,7,10], .add9: [0,4,7,14]
    ]

    func testEstablishedOpenDefaultsKeepExactFretsAndIndividualFingers() throws {
        let cases: [(String, [Int], [Int?])] = [
            ("C", [-1,3,2,0,1,0], [nil,3,2,nil,1,nil]),
            ("D", [-1,-1,0,2,3,2], [nil,nil,nil,1,3,2]),
            ("E", [0,2,2,1,0,0], [nil,2,3,1,nil,nil]),
            ("G", [3,2,0,0,0,3], [2,1,nil,nil,nil,3]),
            ("A", [-1,0,2,2,2,0], [nil,nil,1,2,3,nil]),
            ("Am", [-1,0,2,2,1,0], [nil,nil,2,3,1,nil]),
            ("Dm", [-1,-1,0,2,3,1], [nil,nil,nil,2,3,1]),
            ("Em", [0,2,2,0,0,0], [nil,2,3,nil,nil,nil]),
            ("D7", [-1,-1,0,2,1,2], [nil,nil,nil,2,1,3]),
            ("E7", [0,2,0,1,0,0], [nil,2,nil,1,nil,nil]),
            ("G7", [3,2,0,0,0,1], [3,2,nil,nil,nil,1]),
            ("A7", [-1,0,2,0,2,0], [nil,nil,1,nil,2,nil]),
            ("B7", [-1,2,1,2,0,2], [nil,2,1,3,nil,4]),
            ("Cmaj7", [-1,3,2,0,0,0], [nil,3,2,nil,nil,nil]),
            ("Am7", [-1,0,2,0,1,0], [nil,nil,2,nil,1,nil]),
            ("Em7", [0,2,0,0,0,0], [nil,2,nil,nil,nil,nil]),
            ("Dsus2", [-1,-1,0,2,3,0], [nil,nil,nil,1,2,nil]),
            ("Asus2", [-1,0,2,2,0,0], [nil,nil,1,2,nil,nil]),
            ("Dsus4", [-1,-1,0,2,3,3], [nil,nil,nil,1,2,3]),
            ("Asus4", [-1,0,2,2,3,0], [nil,nil,1,2,3,nil]),
            ("Cadd9", [-1,3,2,0,3,0], [nil,2,1,nil,3,nil])
        ]
        for (symbol, frets, fingers) in cases {
            let voicing = try defaultVoicing(symbol)
            XCTAssertEqual(voicing.shape.frets, frets, symbol)
            XCTAssertEqual(voicing.shape.fingers, fingers, symbol)
            XCTAssertEqual(voicing.shape.barres, [], symbol)
            XCTAssertTrue(voicing.isConventional, symbol)
            assertExactTonesAndGeometry(voicing.shape, bass: voicing.shape.chord.root)
        }
    }

    func testNewConventionalDefaultsHaveExactBarreAndFingerGeometry() throws {
        let e1 = GuitarBarre(fret: 1, fromString: 6, toString: 1, finger: 1)
        let a2 = GuitarBarre(fret: 2, fromString: 5, toString: 1, finger: 1)
        let cases: [(String, [Int], [Int?], [GuitarBarre])] = [
            ("F", [1,3,3,2,1,1], [1,3,4,2,1,1], [e1]),
            ("Fm", [1,3,3,1,1,1], [1,3,4,1,1,1], [e1]),
            ("F7", [1,3,1,2,1,1], [1,3,1,2,1,1], [e1]),
            ("Fm7", [1,3,1,1,1,1], [1,3,1,1,1,1], [e1]),
            ("Bm", [-1,2,4,4,3,2], [nil,1,3,4,2,1], [a2]),
            ("Bm7", [-1,2,4,2,3,2], [nil,1,3,1,2,1], [a2]),
            ("B", [-1,2,4,4,4,2], [nil,1,2,3,4,1], [a2]),
            ("Bmaj7", [-1,2,4,3,4,2], [nil,1,3,2,4,1], [a2]),
            ("Bsus2", [-1,2,4,4,2,2], [nil,1,3,4,1,1], [a2]),
            ("Bsus4", [-1,2,4,4,5,2], [nil,1,2,3,4,1], [a2]),
            ("B7sus4", [-1,2,4,2,5,2], [nil,1,3,1,4,1], [a2]),
            ("F#maj7", [2,4,3,3,2,2], [1,4,2,3,1,1], [
                GuitarBarre(fret: 2, fromString: 6, toString: 1, finger: 1)
            ]),
            ("C7", [-1,3,2,3,1,0], [nil,3,2,4,1,nil], []),
            ("Fsus4", [1,3,3,3,1,1], [1,3,3,3,1,1], [e1,
                GuitarBarre(fret: 3, fromString: 5, toString: 3, finger: 3)
            ]),
            ("F7sus4", [1,3,1,3,1,1], [1,3,1,4,1,1], [e1]),
            ("Dmaj7", [-1,-1,0,2,2,2], [nil,nil,nil,1,1,1], [
                GuitarBarre(fret: 2, fromString: 3, toString: 1, finger: 1)
            ]),
            ("Dm7", [-1,-1,0,2,1,1], [nil,nil,nil,2,1,1], [
                GuitarBarre(fret: 1, fromString: 2, toString: 1, finger: 1)
            ]),
            ("Emaj7", [0,2,1,1,0,0], [nil,3,1,2,nil,nil], []),
            ("Fmaj7", [-1,-1,3,2,1,0], [nil,nil,3,2,1,nil], []),
            ("Gmaj7", [3,2,0,0,0,2], [3,2,nil,nil,nil,1], []),
            ("Amaj7", [-1,0,2,1,2,0], [nil,nil,2,1,3,nil], []),
            ("Esus4", [0,2,2,2,0,0], [nil,2,3,4,nil,nil], []),
            ("D7sus4", [-1,-1,0,2,1,3], [nil,nil,nil,2,1,3], []),
            ("E7sus4", [0,2,0,2,0,0], [nil,2,nil,3,nil,nil], []),
            ("A7sus4", [-1,0,2,0,3,0], [nil,nil,2,nil,3,nil], [])
        ]
        for (symbol, frets, fingers, barres) in cases {
            let voicing = try defaultVoicing(symbol)
            XCTAssertEqual(voicing.shape.frets, frets, symbol)
            XCTAssertEqual(voicing.shape.fingers, fingers, symbol)
            XCTAssertEqual(voicing.shape.barres, barres, symbol)
            XCTAssertTrue(voicing.isConventional, symbol)
            let omitted: [GuitarNote] = symbol == "C7" ? [.g] : []
            XCTAssertEqual(voicing.omittedNotes, omitted, symbol)
            assertExactTonesAndGeometry(voicing.shape, bass: voicing.shape.chord.root, omitted: omitted)
        }
    }

    func testCommonSlashDefaultsAreFullConventionalShapesNotSparseFragments() throws {
        let cases: [(String, GuitarNote, [Int], [Int?])] = [
            ("C/G", .g, [3,3,2,0,1,0], [3,4,2,nil,1,nil]),
            ("G/B", .b, [-1,2,0,0,3,3], [nil,1,nil,nil,3,4]),
            ("Am/C", .c, [-1,3,2,2,1,0], [nil,4,2,3,1,nil]),
            ("C/E", .e, [0,3,2,0,1,0], [nil,3,2,nil,1,nil]),
            ("Am/E", .e, [0,0,2,2,1,0], [nil,nil,2,3,1,nil]),
            ("Am/G", .g, [3,0,2,2,1,0], [4,nil,2,3,1,nil]),
            ("D/A", .a, [-1,0,0,2,3,2], [nil,nil,nil,1,3,2]),
            ("Dm/A", .a, [-1,0,0,2,3,1], [nil,nil,nil,2,3,1]),
            ("A/C#", .cSharp, [-1,4,2,2,2,0], [nil,4,1,2,3,nil]),
            ("A/E", .e, [0,0,2,2,2,0], [nil,nil,1,2,3,nil]),
            ("E/B", .b, [-1,2,2,1,0,0], [nil,2,3,1,nil,nil]),
            ("Em/B", .b, [-1,2,2,0,0,0], [nil,2,3,nil,nil,nil])
        ]
        for (symbol, bass, frets, fingers) in cases {
            let voicing = try defaultVoicing(symbol)
            XCTAssertEqual(voicing.shape.frets, frets, symbol)
            XCTAssertEqual(voicing.shape.fingers, fingers, symbol)
            XCTAssertEqual(voicing.shape.barres, [], symbol)
            XCTAssertTrue(voicing.isConventional, symbol)
            assertExactTonesAndGeometry(voicing.shape, bass: bass)
        }
        let sparse = GuitarChordShape(chord: .init(root: .c, quality: .major),
                                     frets: [-1,-1,-1,0,1,0], fingers: [nil,nil,nil,nil,1,nil],
                                     barres: [], baseFret: 1)
        assertExactTonesAndGeometry(sparse, bass: .g)
        XCTAssertFalse(GuitarChordVoicing(shape: sparse, selectionKey: "0|major|7").isConventional)
        XCTAssertNotEqual(try defaultVoicing("C/G").shape.frets, sparse.frets)
    }

    func testEveryRootOfEachMovableFamilyHasExactTonesFingersAndBarres() throws {
        // Independent fret offsets, conventional fingers and barre endpoints.
        // No six-string sus2 is claimed: the familiar sus2 family is A-derived.
        let families: [(GuitarChordQuality, Int, [Int], [Int?], [(Int, Int, Int, Int)])] = [
            (.major, 4, [0,2,2,1,0,0], [1,3,4,2,1,1], [(0,6,1,1)]),
            (.minor, 4, [0,2,2,0,0,0], [1,3,4,1,1,1], [(0,6,1,1)]),
            (.dominant7, 4, [0,2,0,1,0,0], [1,3,1,2,1,1], [(0,6,1,1)]),
            (.minor7, 4, [0,2,0,0,0,0], [1,3,1,1,1,1], [(0,6,1,1)]),
            (.major7, 4, [0,2,1,1,0,0], [1,4,2,3,1,1], [(0,6,1,1)]),
            (.sus4, 4, [0,2,2,2,0,0], [1,3,3,3,1,1], [(0,6,1,1),(2,5,3,3)]),
            (.dominant7Sus4, 4, [0,2,0,2,0,0], [1,3,1,4,1,1], [(0,6,1,1)]),
            (.major, 9, [-1,0,2,2,2,0], [nil,1,2,3,4,1], [(0,5,1,1)]),
            (.major, 9, [-1,0,2,2,2,-1], [nil,1,3,3,3,nil], [(2,4,2,3)]),
            (.minor, 9, [-1,0,2,2,1,0], [nil,1,3,4,2,1], [(0,5,1,1)]),
            (.dominant7, 9, [-1,0,2,0,2,0], [nil,1,3,1,4,1], [(0,5,1,1)]),
            (.minor7, 9, [-1,0,2,0,1,0], [nil,1,3,1,2,1], [(0,5,1,1)]),
            (.major7, 9, [-1,0,2,1,2,0], [nil,1,3,2,4,1], [(0,5,1,1)]),
            (.sus2, 9, [-1,0,2,2,0,0], [nil,1,3,4,1,1], [(0,5,1,1)]),
            (.sus4, 9, [-1,0,2,2,3,0], [nil,1,2,3,4,1], [(0,5,1,1)]),
            (.dominant7Sus4, 9, [-1,0,2,0,3,0], [nil,1,3,1,4,1], [(0,5,1,1)])
        ]
        for root in GuitarNote.allCases {
            for (quality, openRoot, offsets, fingers, barreOffsets) in families {
                let chord = GuitarChord(root: root, quality: quality)
                let pitchPosition = (root.rawValue - openRoot + 12) % 12
                let first = pitchPosition == 0 ? 12 : pitchPosition
                for position in stride(from: first, through: 15, by: 12) {
                    let frets = offsets.map { $0 < 0 ? -1 : position + $0 }
                    guard (frets.max() ?? 0) <= 15 else { continue }
                    let barres = barreOffsets.map {
                        GuitarBarre(fret: position + $0.0, fromString: $0.1, toString: $0.2, finger: $0.3)
                    }
                    let expected = GuitarChordShape(chord: chord, frets: frets, fingers: fingers,
                                                    barres: barres, baseFret: position)
                    XCTAssertTrue(ConventionalGuitarFingerings.candidates(chord: chord, bass: root).contains(expected), chord.name)
                    XCTAssertTrue(ConventionalGuitarFingerings.shapes(chord: chord, bass: root).contains(expected), chord.name)
                    assertExactTonesAndGeometry(expected, bass: root)
                    XCTAssertTrue(GuitarChordVoicing(shape: expected,
                                                    selectionKey: "\(root.rawValue)|\(quality.id)|\(root.rawValue)").isConventional)
                }
                // The default may be an open chord, but every one of these
                // standard qualities must resolve conventionally at every root.
                let resolved = try XCTUnwrap(NoCapoGuitarVoicings.resolve(chord: chord), chord.name)
                XCTAssertTrue(ConventionalGuitarFingerings.contains(resolved), chord.name)
                let omitted: [GuitarNote] = quality == .dominant7 && root == .c ? [.g] : []
                assertExactTonesAndGeometry(resolved, bass: root, omitted: omitted)
            }
        }
    }

    func testCuratedAlternativesPrecedeGeneratedVariantsAndDefaultIsFirst() throws {
        for symbol in ["C", "C7", "G", "F", "Bm", "C/G", "G/B", "Am/C", "C6/9"] {
            let data = try XCTUnwrap(GuitarChordData(symbol: symbol), symbol)
            XCTAssertLessThanOrEqual(data.voicings.count, 18, symbol)
            XCTAssertEqual(data.voicings.first?.shape, try defaultVoicing(symbol).shape, symbol)
            XCTAssertEqual(Set(data.voicings.map { $0.shape.frets }).count, data.voicings.count, symbol)
            var foundGenerated = false
            for voicing in data.voicings {
                if !voicing.isConventional { foundGenerated = true }
                else { XCTAssertFalse(foundGenerated, "Curated alternative after generator: \(symbol)") }
            }
        }
        let c = try XCTUnwrap(GuitarChordData(symbol: "C"))
        for (frets, fingers) in [
            ([-1,3,5,5,5,3], [nil,1,2,3,4,1] as [Int?]),
            ([8,10,10,9,8,8], [1,3,4,2,1,1] as [Int?]),
            ([-1,3,2,0,1,3], [nil,3,2,nil,1,4] as [Int?])
        ] {
            let option = try XCTUnwrap(c.voicings.first { $0.shape.frets == frets })
            XCTAssertEqual(option.shape.fingers, fingers)
            XCTAssertTrue(option.isConventional)
        }
        let f = try XCTUnwrap(GuitarChordData(symbol: "F"))
        XCTAssertTrue(try XCTUnwrap(f.voicings.first { $0.shape.frets == [-1,-1,3,2,1,1] }).isConventional)
        let gb = try XCTUnwrap(GuitarChordData(symbol: "G/B"))
        let alternate = try XCTUnwrap(gb.voicings.first { $0.shape.frets == [-1,2,0,0,0,3] })
        XCTAssertEqual(alternate.shape.fingers, [nil,1,nil,nil,nil,3])
        XCTAssertTrue(alternate.isConventional)
        for symbol in ["Cdim", "C13", "C6/9", "Cm6/9", "C/D"] {
            let generated = try XCTUnwrap(GuitarChordData(symbol: symbol), symbol)
            XCTAssertTrue(generated.voicings.allSatisfy { !$0.isConventional }, symbol)
        }
    }

    func testClassificationRequiresFullGeometryAndDoesNotAlterIdentity() throws {
        let c = try defaultVoicing("C")
        XCTAssertEqual(c.id, "v1|0|major|0|-1,3,2,0,1,0|-,3,2,-,1,-||1")
        let otherFingers = GuitarChordShape(chord: c.shape.chord, frets: c.shape.frets,
                                           fingers: [nil,4,3,nil,2,nil], barres: [], baseFret: 1)
        assertExactTonesAndGeometry(otherFingers, bass: .c)
        let unmatched = GuitarChordVoicing(shape: otherFingers, selectionKey: "0|major|0")
        XCTAssertFalse(unmatched.isConventional)
        XCTAssertEqual(unmatched.id, "v1|0|major|0|-1,3,2,0,1,0|-,4,3,-,2,-||1")

        // This mechanically valid ring mini-barre has the same F pitches, but is
        // not the supplied conventional four-finger F assignment.
        let f = try defaultVoicing("F")
        let grouped = GuitarChordShape(chord: f.shape.chord, frets: f.shape.frets,
                                       fingers: [1,3,3,2,1,1], barres: [
                                        GuitarBarre(fret: 1, fromString: 6, toString: 1, finger: 1),
                                        GuitarBarre(fret: 3, fromString: 5, toString: 4, finger: 3)
                                       ], baseFret: 1)
        assertExactTonesAndGeometry(grouped, bass: .f)
        XCTAssertFalse(GuitarChordVoicing(shape: grouped, selectionKey: "5|major|5").isConventional)
        XCTAssertNotEqual(GuitarChordVoicing(shape: grouped, selectionKey: "5|major|5").id, f.id)
        let missingBarre = GuitarChordShape(chord: f.shape.chord, frets: f.shape.frets,
                                           fingers: f.shape.fingers, barres: [], baseFret: 1)
        XCTAssertFalse(GuitarChordVoicing(shape: missingBarre, selectionKey: "5|major|5").isConventional)
        let wrongBase = GuitarChordShape(chord: c.shape.chord, frets: c.shape.frets,
                                        fingers: c.shape.fingers, barres: [], baseFret: 2)
        XCTAssertFalse(GuitarChordVoicing(shape: wrongBase, selectionKey: "0|major|0").isConventional)
    }

    func testOpenC7IsConventionalWithHonestFifthOmissionAndFullWrittenTheory() throws {
        let data = try XCTUnwrap(GuitarChordData(symbol: "C7"))
        let open = try XCTUnwrap(data.voicings.first)
        XCTAssertEqual(open.shape.frets, [-1,3,2,3,1,0])
        XCTAssertEqual(open.shape.fingers, [nil,3,2,4,1,nil])
        XCTAssertEqual(open.shape.barres, [])
        XCTAssertTrue(open.isConventional)
        XCTAssertEqual(open.id, "v1|0|7|0|-1,3,2,3,1,0|-,3,2,4,1,-||1")
        XCTAssertEqual(open.omittedNotes, [.g])
        XCTAssertEqual(data.intervalLabels, ["1","3","5","b7"])
        XCTAssertEqual(data.theoreticalNotes, [.c,.e,.g,.aSharp])
        XCTAssertTrue(data.explanation.contains("完全5度"))
        XCTAssertTrue(data.explanation.contains("長3度と短7度"))
        let presentation = ChordFingeringPresentation(symbol: "C7")
        XCTAssertEqual(presentation.omittedNotes, [.g])
        XCTAssertTrue(presentation.isSimplified)
        XCTAssertEqual(try XCTUnwrap(GuitarChordData(symbol: "C7/C")).voicings, data.voicings)
        let complete = try XCTUnwrap(data.voicings.first { $0.shape.frets == [-1,3,5,3,5,3] })
        XCTAssertEqual(complete.shape.fingers, [nil,1,3,1,4,1])
        XCTAssertTrue(complete.isConventional)
        XCTAssertEqual(complete.omittedNotes, [])
        assertExactTonesAndGeometry(complete.shape, bass: .c)

        // No uncurated slash default is replaced by a fifth-omitting fragment.
        for (symbol, bass) in [("C7/E", GuitarNote.e), ("C7/G", .g), ("C7/Bb", .aSharp)] {
            let inversion = try defaultVoicing(symbol)
            XCTAssertEqual(inversion.omittedNotes, [], symbol)
            assertExactTonesAndGeometry(inversion.shape, bass: bass)
            var foundOmitted = false
            for option in try XCTUnwrap(GuitarChordData(symbol: symbol)).voicings {
                if option.omittedNotes.isEmpty {
                    XCTAssertFalse(foundOmitted, "Complete inversion after optional omission: \(symbol)")
                } else {
                    XCTAssertEqual(option.omittedNotes, [.g], symbol)
                    XCTAssertNotEqual(bass, .g, symbol)
                    foundOmitted = true
                }
                assertExactTonesAndGeometry(option.shape, bass: bass, omitted: option.omittedNotes)
            }
        }
        // The fifth is never optional when it is explicitly the lowest bass.
        for option in try XCTUnwrap(GuitarChordData(symbol: "C7/G")).voicings {
            XCTAssertEqual(option.omittedNotes, [])
            assertExactTonesAndGeometry(option.shape, bass: .g)
        }
    }

    func testCatalogCannotBypassToneBassOrOptionalFifthPolicy() throws {
        let c = try defaultVoicing("C").shape
        XCTAssertNil(NoCapoGuitarVoicings.checkedCandidate(c, bass: .g))
        let openC7 = try defaultVoicing("C7").shape
        XCTAssertNotNil(NoCapoGuitarVoicings.checkedCandidate(openC7, bass: .c))
        XCTAssertNil(NoCapoGuitarVoicings.checkedCandidate(openC7, bass: .g))
        let missingThird = GuitarChordShape(chord: .init(root: .c, quality: .dominant7),
                                           frets: [-1,3,-1,3,1,-1], fingers: [nil,3,nil,2,1,nil],
                                           barres: [], baseFret: 1)
        XCTAssertNil(NoCapoGuitarVoicings.checkedCandidate(missingThird, bass: .c))
        let missingSeventh = GuitarChordShape(chord: .init(root: .c, quality: .dominant7),
                                             frets: c.frets, fingers: c.fingers, barres: [], baseFret: 1)
        XCTAssertNil(NoCapoGuitarVoicings.checkedCandidate(missingSeventh, bass: .c))
        for quality in [GuitarChordQuality.dominant7Flat5, .dominant7Sharp5] {
            let missingAlteredFifth = GuitarChordShape(chord: .init(root: .c, quality: quality),
                                                      frets: openC7.frets, fingers: openC7.fingers,
                                                      barres: [], baseFret: 1)
            XCTAssertNil(NoCapoGuitarVoicings.checkedCandidate(missingAlteredFifth, bass: .c))
        }
        for root in GuitarNote.allCases {
            XCTAssertEqual(NoCapoGuitarVoicings.optionalNotes(.init(root: root, quality: .dominant7)),
                           Set([GuitarNote.fromMIDI(root.rawValue + 7)]))
            for quality in [GuitarChordQuality.major, .minor, .major7, .minor7,
                            .dominant7Sus4, .dominant7Flat5, .dominant7Sharp5] {
                XCTAssertEqual(NoCapoGuitarVoicings.optionalNotes(.init(root: root, quality: quality)), [])
            }
        }
        let permittedC9 = GuitarChordShape(chord: .init(root: .c, quality: .dominant9),
                                          frets: [-1,3,2,3,3,-1], fingers: [nil,2,1,3,3,nil],
                                          barres: [GuitarBarre(fret: 3, fromString: 3, toString: 2, finger: 3)],
                                          baseFret: 2)
        XCTAssertNotNil(NoCapoGuitarVoicings.checkedCandidate(permittedC9, bass: .c))
        // A permitted omission alone still does not make a shape curated.
        XCTAssertFalse(GuitarChordVoicing(shape: permittedC9, selectionKey: "0|9|0").isConventional)
    }

    func testWrittenSpellingSlashBassNumericSixNineAndUnsupportedSymbolsArePreserved() throws {
        let written = try XCTUnwrap(GuitarChordData(symbol: "  B♭m \n"))
        XCTAssertEqual(written.symbol, "B♭m")
        XCTAssertTrue(written.japaneseName.hasPrefix("B♭"))
        XCTAssertTrue(try XCTUnwrap(written.voicings.first).isConventional)
        XCTAssertEqual(written.voicings, try XCTUnwrap(GuitarChordData(symbol: "A#m")).voicings)
        for symbol in ["C/G", "G/B", "Am/C", "Cm6/9/G"] {
            let data = try XCTUnwrap(GuitarChordData(symbol: symbol))
            let parsed = try XCTUnwrap(ParsedGuitarChordSymbol(symbol))
            let bass = try XCTUnwrap(parsed.bass)
            XCTAssertEqual(data.symbol, symbol)
            XCTAssertEqual(ChordFingeringPresentation(symbol: symbol).slashBass, parsed.bassSpelling)
            for voicing in data.voicings {
                XCTAssertEqual(voicing.stringNotes.compactMap(\.midi).min().map(GuitarNote.fromMIDI), bass)
            }
        }
        let sixNine = try XCTUnwrap(GuitarChordData(symbol: "C6/9"))
        XCTAssertEqual(sixNine.intervalLabels, ["1","3","5","6","9"])
        XCTAssertEqual(sixNine.theoreticalNotes, [.c,.e,.g,.a,.d])
        XCTAssertNil(ChordFingeringPresentation(symbol: "C6/9").slashBass)
        XCTAssertNil(GuitarChordData(symbol: "NC"))
        XCTAssertEqual(ChordFingeringPresentation(symbol: "N.C.").availability, .noChord)
        for symbol in ["Cunknown", "C7(b9#11)", "C/G/H", "C6/8"] {
            XCTAssertNil(GuitarChordData(symbol: symbol), symbol)
            XCTAssertEqual(ChordFingeringPresentation(symbol: symbol).availability, .unavailable, symbol)
        }
    }

    private func defaultVoicing(_ symbol: String) throws -> GuitarChordVoicing {
        let parsed = try XCTUnwrap(ParsedGuitarChordSymbol(symbol), symbol)
        let shape = try XCTUnwrap(NoCapoGuitarVoicings.resolve(chord: parsed.chord, bass: parsed.bass), symbol)
        return GuitarChordVoicing(shape: shape, selectionKey: try XCTUnwrap(GuitarChordData.selectionKey(for: symbol)))
    }

    private func assertExactTonesAndGeometry(_ shape: GuitarChordShape, bass: GuitarNote,
                                            omitted: [GuitarNote] = [],
                                            file: StaticString = #filePath, line: UInt = #line) {
        let offsets = intervals[shape.chord.quality]!
        let midis = zip(tuning, shape.frets).compactMap { midi, fret in fret < 0 ? nil : midi + fret }
        let expected = Set(offsets.map { (shape.chord.root.rawValue + $0) % 12 })
            .subtracting(omitted.map(\.rawValue)).union([bass.rawValue])
        XCTAssertFalse(omitted.contains(bass), file: file, line: line)
        XCTAssertEqual(Set(midis.map { $0 % 12 }), expected, shape.name, file: file, line: line)
        XCTAssertEqual(midis.min().map { $0 % 12 }, bass.rawValue, shape.name, file: file, line: line)
        XCTAssertEqual(shape.frets.count, 6, file: file, line: line)
        XCTAssertEqual(shape.fingers.count, 6, file: file, line: line)
        XCTAssertTrue(shape.frets.allSatisfy { (-1...15).contains($0) }, file: file, line: line)
        let positive = shape.frets.filter { $0 > 0 }
        XCTAssertTrue(positive.allSatisfy { (1...5).contains($0 - shape.baseFret + 1) }, file: file, line: line)
        XCTAssertLessThanOrEqual((positive.max() ?? 0) - (positive.min() ?? 0), 4, file: file, line: line)
        if shape.frets.contains(0) { XCTAssertEqual(shape.baseFret, 1, file: file, line: line) }
        var indices: [Int: [Int]] = [:]
        for index in 0..<6 {
            if shape.frets[index] <= 0 { XCTAssertNil(shape.fingers[index], file: file, line: line) }
            else if let finger = shape.fingers[index] {
                XCTAssertTrue((1...4).contains(finger), file: file, line: line)
                indices[finger, default: []].append(index)
            } else { XCTFail("Missing finger: \(shape.name)", file: file, line: line) }
        }
        for (finger, positions) in indices {
            XCTAssertEqual(Set(positions.map { shape.frets[$0] }).count, 1, file: file, line: line)
            if positions.count > 1 {
                XCTAssertTrue(shape.barres.contains { barre in
                    barre.finger == finger && positions.allSatisfy { index in
                        (barre.toString...barre.fromString).contains(6 - index)
                    }
                }, file: file, line: line)
            }
        }
        for barre in shape.barres {
            XCTAssertTrue((1...6).contains(barre.toString), file: file, line: line)
            XCTAssertTrue((1...6).contains(barre.fromString), file: file, line: line)
            XCTAssertGreaterThan(barre.fromString, barre.toString, file: file, line: line)
            XCTAssertTrue(indices[barre.finger, default: []].contains {
                shape.frets[$0] == barre.fret && (barre.toString...barre.fromString).contains(6 - $0)
            }, file: file, line: line)
            for string in barre.toString...barre.fromString {
                let index = 6 - string
                if shape.frets[index] >= 0 {
                    XCTAssertGreaterThanOrEqual(shape.frets[index], barre.fret, file: file, line: line)
                }
                if shape.frets[index] == barre.fret {
                    XCTAssertEqual(shape.fingers[index], barre.finger, file: file, line: line)
                }
            }
        }
    }
}
