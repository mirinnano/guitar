import XCTest
@testable import GuitarToolsCore

final class NoCapoGuitarVoicingsTests: XCTestCase {
    // Independent musical expectations, not derived from the library under test.
    private let intervals: [GuitarChordQuality: [Int]] = [
        .major: [0,4,7], .minor: [0,3,7], .power5: [0,7],
        .major6: [0,4,7,9], .minor6: [0,3,7,9],
        .dominant7: [0,4,7,10], .major7: [0,4,7,11], .minor7: [0,3,7,10],
        .dominant9: [0,4,7,10,14], .major9: [0,4,7,11,14], .minor9: [0,3,7,10,14],
        .sus2: [0,2,7], .sus4: [0,5,7], .add9: [0,4,7,14],
        .diminished: [0,3,6], .augmented: [0,4,8],
        .halfDiminished7: [0,3,6,10], .diminished7: [0,3,6,9],
        .dominant7Sus4: [0,5,7,10], .dominant7Flat9: [0,4,7,10,13],
        .dominant7Sharp9: [0,4,7,10,15], .dominant7Sus4Flat9: [0,5,7,10,13],
        .minorMajor7: [0,3,7,11], .minorAdd9: [0,3,7,14],
        .majorSixNine: [0,4,7,9,14], .minorSixNine: [0,3,7,9,14],
        .add11: [0,4,7,17], .dominant11: [0,4,7,10,14,17], .minor11: [0,3,7,10,14,17],
        .dominant13: [0,4,7,10,14,17,21], .minor13: [0,3,7,10,14,17,21],
        .dominant7Flat5: [0,4,6,10], .dominant7Sharp5: [0,4,8,10],
        .dominant7Flat13: [0,4,7,10,20], .dominant7Sharp11: [0,4,7,10,18],
        .major7Sharp11: [0,4,7,11,18], .dominant9Sus4: [0,5,7,10,14]
    ]

    func testEveryQualityAndRootIsVerifiedAndCatalogUsesSameShape() throws {
        XCTAssertEqual(Set(intervals.keys), Set(GuitarChordQuality.allCases))
        for root in GuitarNote.allCases {
            for quality in GuitarChordQuality.allCases {
                let written = root.displayName + quality.rawValue
                XCTAssertEqual(quality.intervals, intervals[quality], written)
                let presentation = ChordFingeringPresentation(symbol: written)
                let shape = try XCTUnwrap(presentation.shape, written)
                let expected = Set(intervals[quality]!.map { GuitarNote.fromMIDI(root.rawValue + $0) })
                XCTAssertEqual(Set(shape.chord.notes), expected, written)
                let sounded = Set(midis(shape).map(GuitarNote.fromMIDI))
                XCTAssertTrue(sounded.isSubset(of: expected), written)
                XCTAssertEqual(expected.subtracting(sounded), Set(presentation.omittedNotes), written)
                XCTAssertEqual(presentation.isSimplified, !presentation.omittedNotes.isEmpty)
                var permitted: Set<GuitarNote> = []
                if quality == .dominant7 || (intervals[quality]!.count >= 5 && intervals[quality]!.contains(7)) {
                    permitted.insert(GuitarNote.fromMIDI(root.rawValue + 7))
                }
                if quality == .dominant13 { permitted.insert(GuitarNote.fromMIDI(root.rawValue + 5)) }
                XCTAssertTrue(Set(presentation.omittedNotes).isSubset(of: permitted), written)
                XCTAssertTrue(sounded.contains(root), written)
                XCTAssertEqual(GuitarNote.fromMIDI(try XCTUnwrap(midis(shape).min())), root, written)
                XCTAssertEqual(CommonGuitarChords.all.first { $0.chord == shape.chord }, shape, written)
                assertGeometry(shape)
            }
        }
    }

    func testCommonInversionsForEveryRoot() throws {
        for root in GuitarNote.allCases {
            for quality in [GuitarChordQuality.major, .minor, .major7, .minor7, .dominant7] {
                for offset in intervals[quality]! {
                    let bass = GuitarNote.fromMIDI(root.rawValue + offset)
                    let symbol = root.displayName + quality.rawValue + "/" + bass.displayName
                    let presentation = ChordFingeringPresentation(symbol: symbol)
                    let shape = try XCTUnwrap(presentation.shape, symbol)
                    XCTAssertEqual(GuitarNote.fromMIDI(try XCTUnwrap(midis(shape).min())), bass, symbol)
                    // Explicit root bass C7/C is the same familiar open C7,
                    // intentionally omitting G. Uncurated inversions stay exact.
                    let omitted: Set<GuitarNote> = root == .c && quality == .dominant7 && bass == root ? [.g] : []
                    XCTAssertEqual(Set(midis(shape).map(GuitarNote.fromMIDI)), Set(shape.chord.notes).subtracting(omitted), symbol)
                    XCTAssertEqual(Set(presentation.omittedNotes), omitted, symbol)
                    XCTAssertEqual(presentation.isSimplified, !omitted.isEmpty, symbol)
                    XCTAssertEqual(presentation.slashBass, bass.displayName, symbol)
                    assertGeometry(shape)
                }
            }
        }
    }

    func testRequestedSlashRegressionsAndNonTriadBass() throws {
        let examples: [(String, GuitarNote, Set<GuitarNote>)] = [
            ("C/E", .e, [.c,.e,.g]), ("G/B", .b, [.g,.b,.d]),
            ("Bbmaj7/D", .d, [.aSharp,.d,.f,.a]), ("G#m/B", .b, [.gSharp,.b,.dSharp]),
            ("Db/F", .f, [.cSharp,.f,.gSharp]), ("C/D", .d, [.c,.e,.g,.d])
        ]
        for (symbol, bass, expected) in examples {
            let presentation = ChordFingeringPresentation(symbol: symbol)
            let shape = try XCTUnwrap(presentation.shape, symbol)
            XCTAssertEqual(GuitarNote.fromMIDI(try XCTUnwrap(midis(shape).min())), bass, symbol)
            XCTAssertEqual(Set(midis(shape).map(GuitarNote.fromMIDI)), expected, symbol)
            XCTAssertEqual(presentation.omittedNotes, [], symbol)
            XCTAssertFalse(presentation.isSimplified, symbol)
            assertGeometry(shape)
        }
        XCTAssertEqual(CommonGuitarChords.shape(named: "C/E")?.frets, [0,3,2,0,1,0])
        XCTAssertEqual(CommonGuitarChords.shape(named: "Db/F")?.frets, [-1,-1,3,1,2,1])
        XCTAssertEqual(CommonGuitarChords.shape(named: "G/B")?.frets, [-1,2,0,0,3,3])
        XCTAssertEqual(CommonGuitarChords.shape(named: "C/D")?.frets, [-1,-1,0,0,1,0])
        XCTAssertEqual(CommonGuitarChords.shape(named: "C")?.frets, [-1,3,2,0,1,0])
    }

    func testTranspositionPreservesQualityAndDistinguishesNumericSlash() {
        let cases: [(String, Int, String)] = [
            ("B♭maj7/D", 2, "Cmaj7/E"), ("C6/9", 2, "D6/9"),
            ("Cm6/9/G", 2, "Dm6/9/A"), ("C7(♭9)/E", 1, "C#7(♭9)/F"),
            ("F♯mM7/C♯", -2, "EmM7/B"), ("Db/F", 0, "Db/F"),
            ("C7(b9#11)/E", 2, "D7(b9#11)/F#"),
            ("C7(b9,#11)", 2, "D7(b9,#11)")
        ]
        for (symbol, amount, expected) in cases {
            XCTAssertEqual(ChordSymbolTransposition.transpose(symbol, semitones: amount), expected, symbol)
        }
        XCTAssertNil(CommonGuitarChords.shape(named: "D7(b9#11)/F#"))
        for symbol in ["C/", "C/G/H", "C6/8", "C6/9/", "C7(b9", "C7)b9(", "C/Unknown", "NC", ""] {
            XCTAssertNil(ChordSymbolTransposition.transpose(symbol, semitones: 2), symbol)
            XCTAssertNil(CommonGuitarChords.shape(named: symbol), symbol)
        }
    }

    func testMajorMinorAndHalfDiminishedSourceAliases() throws {
        let cases: [(String, GuitarChordQuality)] = [
            ("CM", .major), ("Cm", .minor), ("Cmaj", .major), ("Cmin", .minor),
            ("CMaj", .major), ("CMIN", .minor), ("Cm7-5", .halfDiminished7)
        ]
        for (symbol, quality) in cases {
            let shape = try XCTUnwrap(CommonGuitarChords.shape(named: symbol), symbol)
            XCTAssertEqual(shape.chord.quality, quality, symbol)
            XCTAssertEqual(Set(midis(shape).map(GuitarNote.fromMIDI)), Set(shape.chord.notes), symbol)
            XCTAssertEqual(ChordSymbolTransposition.transpose(symbol, semitones: 2), "D" + symbol.dropFirst(), symbol)
            assertGeometry(shape)
        }
        XCTAssertNotEqual(CommonGuitarChords.shape(named: "CM")?.chord.notes,
                          CommonGuitarChords.shape(named: "Cm")?.chord.notes)
    }

    func testConventionalOpenCandidateFingersArePreserved() throws {
        let cases: [(String, [Int], [Int?])] = [
            ("C", [-1,3,2,0,1,0], [nil,3,2,nil,1,nil]),
            ("Am", [-1,0,2,2,1,0], [nil,nil,2,3,1,nil]),
            ("E", [0,2,2,1,0,0], [nil,2,3,1,nil,nil]),
            ("Em", [0,2,2,0,0,0], [nil,2,3,nil,nil,nil]),
            ("A", [-1,0,2,2,2,0], [nil,nil,1,2,3,nil]),
            ("D", [-1,-1,0,2,3,2], [nil,nil,nil,1,3,2]),
            ("C/E", [0,3,2,0,1,0], [nil,3,2,nil,1,nil]),
            ("Am/E", [0,0,2,2,1,0], [nil,nil,2,3,1,nil]),
            ("D/A", [-1,0,0,2,3,2], [nil,nil,nil,1,3,2])
        ]
        for (symbol, frets, fingers) in cases {
            let shape = try XCTUnwrap(CommonGuitarChords.shape(named: symbol), symbol)
            XCTAssertEqual(shape.frets, frets, symbol)
            XCTAssertEqual(shape.fingers, fingers, symbol)
            XCTAssertEqual(shape.barres, [], symbol)
            XCTAssertTrue(NoCapoGuitarVoicings.hasValidFingering(
                frets: shape.frets, fingers: shape.fingers, barres: shape.barres), symbol)
            assertGeometry(shape)
        }
    }

    func testCandidateMetadataValidationRejectsUnsafeAssignments() {
        let frets = [-1,2,2,2,1,0]
        let fingers: [Int?] = [nil,2,2,2,1,nil]
        let safe = GuitarBarre(fret: 2, fromString: 5, toString: 3, finger: 2)
        XCTAssertTrue(NoCapoGuitarVoicings.hasValidFingering(frets: frets, fingers: fingers, barres: [safe]))
        XCTAssertFalse(NoCapoGuitarVoicings.hasValidFingering(frets: frets, fingers: fingers, barres: []))
        // A barre may pass under higher-fretted endpoints, even with one note
        // actually sounding at its fret; this is not a lower/open-string fault.
        XCTAssertTrue(NoCapoGuitarVoicings.hasValidFingering(
            frets: [-1,2,4,4,4,4], fingers: [nil,1,2,2,2,2], barres: [
                GuitarBarre(fret: 2, fromString: 5, toString: 1, finger: 1),
                GuitarBarre(fret: 4, fromString: 4, toString: 1, finger: 2)
            ]))
        for toString in [1,2] { // Extending the barre covers an open or lower-fretted note.
            let unsafe = GuitarBarre(fret: 2, fromString: 5, toString: toString, finger: 2)
            XCTAssertFalse(NoCapoGuitarVoicings.hasValidFingering(frets: frets, fingers: fingers, barres: [unsafe]))
        }
        let invalidFingers: [[Int?]] = [
            [nil,2,2,2,2,nil], // Same finger at different frets.
            [nil,2,2,2,1,3],   // Finger assigned to an open string.
            [1,2,2,2,1,nil],   // Finger assigned to a muted string.
            [nil,2,nil,2,1,nil], // Missing fretted-string assignment.
            [nil,5,5,5,1,nil], [nil,0,0,0,1,nil], // Outside 1...4.
            [nil,2,2] // Wrong array length.
        ]
        for invalid in invalidFingers {
            XCTAssertFalse(NoCapoGuitarVoicings.hasValidFingering(frets: frets, fingers: invalid, barres: [safe]))
        }
        for invalid in [
            GuitarBarre(fret: 2, fromString: 7, toString: 3, finger: 2),
            GuitarBarre(fret: 2, fromString: 3, toString: 5, finger: 2),
            GuitarBarre(fret: 1, fromString: 5, toString: 3, finger: 2),
            GuitarBarre(fret: 2, fromString: 5, toString: 3, finger: 4)
        ] {
            XCTAssertFalse(NoCapoGuitarVoicings.hasValidFingering(frets: frets, fingers: fingers, barres: [invalid]))
        }
    }

    func testCachedResolutionIsDeterministicIncludingFailures() {
        for symbol in ["C6/9/G", "C13", "C7(b9#11)", "C/Unknown"] {
            let first = ChordFingeringPresentation(symbol: symbol)
            for _ in 0..<100 { XCTAssertEqual(ChordFingeringPresentation(symbol: symbol), first) }
        }
    }

    private func midis(_ shape: GuitarChordShape) -> [Int] {
        zip([40,45,50,55,59,64], shape.frets).compactMap { midi, fret in fret < 0 ? nil : midi + fret }
    }

    private func assertGeometry(_ shape: GuitarChordShape, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(shape.frets.count, 6, file: file, line: line)
        XCTAssertEqual(shape.fingers.count, 6, file: file, line: line)
        XCTAssertTrue(shape.frets.allSatisfy { (-1...15).contains($0) }, shape.name, file: file, line: line)
        let positive = shape.frets.filter { $0 > 0 }
        XCTAssertLessThanOrEqual((positive.max() ?? 0) - (positive.min() ?? 0), 4, shape.name, file: file, line: line)
        for fret in positive {
            XCTAssertTrue((1...5).contains(fret - shape.baseFret + 1), "Hidden note: \(shape.name)", file: file, line: line)
        }
        if shape.frets.contains(0) { XCTAssertEqual(shape.baseFret, 1, shape.name, file: file, line: line) }
        var fingerNotes: [Int: [Int]] = [:]
        for index in 0..<6 {
            if shape.frets[index] <= 0 { XCTAssertNil(shape.fingers[index], shape.name, file: file, line: line) }
            else if let finger = shape.fingers[index] {
                XCTAssertTrue((1...4).contains(finger), shape.name, file: file, line: line)
                fingerNotes[finger, default: []].append(index)
            } else { XCTFail("Unfingered \(shape.name)", file: file, line: line) }
        }
        XCTAssertLessThanOrEqual(fingerNotes.count, 4, shape.name, file: file, line: line)
        for (finger, indices) in fingerNotes {
            XCTAssertEqual(Set(indices.map { shape.frets[$0] }).count, 1, "Finger crosses frets: \(shape.name)", file: file, line: line)
            if indices.count > 1 {
                XCTAssertTrue(shape.barres.contains { barre in
                    barre.finger == finger && barre.fret == shape.frets[indices[0]] &&
                    indices.allSatisfy { (barre.toString...barre.fromString).contains(6 - $0) }
                }, shape.name, file: file, line: line)
            }
        }
        for barre in shape.barres {
            XCTAssertTrue((1...6).contains(barre.toString), file: file, line: line)
            XCTAssertTrue((1...6).contains(barre.fromString), file: file, line: line)
            XCTAssertGreaterThan(barre.fromString, barre.toString, file: file, line: line)
            for string in barre.toString...barre.fromString where shape.frets[6-string] >= 0 {
                XCTAssertGreaterThanOrEqual(shape.frets[6-string], barre.fret, "Unsafe barre: \(shape.name)", file: file, line: line)
            }
        }
    }
}
