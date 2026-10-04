import XCTest
@testable import GuitarToolsCore

final class ExtendedGuitarChordTests: XCTestCase {
    // Independent expectations: b9/#9 must not be replaced by a natural ninth;
    // diminished seventh is nine semitones, not the half-diminished b7.
    private let intervals: [GuitarChordQuality: [Int]] = [
        .halfDiminished7: [0, 3, 6, 10],
        .diminished7: [0, 3, 6, 9],
        .dominant7Sus4: [0, 5, 7, 10],
        .dominant7Flat9: [0, 4, 7, 10, 13],
        .dominant7Sharp9: [0, 4, 7, 10, 15],
        .dominant7Sus4Flat9: [0, 5, 7, 10, 13],
        .minorMajor7: [0, 3, 7, 11],
        .minorAdd9: [0, 3, 7, 14]
    ]

    func testExtendedAliasesPreserveExactQualities() throws {
        let aliases: [(String, GuitarChordQuality)] = [
            ("m7(b5)", .halfDiminished7),
            ("m7b5", .halfDiminished7),
            ("m7(♭5)", .halfDiminished7),
            ("ø7", .halfDiminished7),
            ("dim7", .diminished7),
            ("°7", .diminished7),
            ("7sus4", .dominant7Sus4),
            ("7(sus4)", .dominant7Sus4),
            ("7sus", .dominant7Sus4),
            ("7(b9)", .dominant7Flat9),
            ("7b9", .dominant7Flat9),
            ("7(♭9)", .dominant7Flat9),
            ("7(#9)", .dominant7Sharp9),
            ("7#9", .dominant7Sharp9),
            ("7(♯9)", .dominant7Sharp9),
            ("7sus4(b9)", .dominant7Sus4Flat9),
            ("7sus4b9", .dominant7Sus4Flat9),
            ("7(sus4♭9)", .dominant7Sus4Flat9),
            ("7sus(b9)", .dominant7Sus4Flat9),
            ("m(maj7)", .minorMajor7),
            ("mmaj7", .minorMajor7),
            ("mM7", .minorMajor7),
            ("m△7", .minorMajor7),
            ("madd9", .minorAdd9),
            ("m(add9)", .minorAdd9)
        ]
        for (suffix, quality) in aliases {
            for root in GuitarNote.allCases {
                let symbol = root.displayName + suffix
                XCTAssertEqual(normalizeChordLookup(symbol), root.displayName + quality.rawValue, symbol)
                let shape = try XCTUnwrap(CommonGuitarChords.shape(named: symbol), symbol)
                XCTAssertEqual(shape.chord.quality, quality, symbol)
                XCTAssertEqual(shape.chord.root, root, symbol)
            }
        }
        XCTAssertEqual(normalizeChordLookup(" B♭7(♯9)/D "), "A#7(#9)")
        XCTAssertEqual(normalizeChordLookup("F♯m7(♭5)"), "F#m7(b5)")
        XCTAssertEqual(normalizeChordLookup("CM7"), "Cmaj7")
        XCTAssertEqual(normalizeChordLookup("CM9"), "Cmaj9")
        XCTAssertEqual(normalizeChordLookup("Cm7"), "Cm7")
    }

    func testUnknownOrMalformedAlterationsDoNotFallBack() {
        for symbol in [
            "B7sus4(#9)", "B7sus4(b9#9)", "C7(b9#11)",
            "Cm7(#5)", "Cdim9", "C7(b9", "C7)b9(", "C7(b9))", "Cø9",
            "C/G/H", "C/", "C/Unknown", ""
        ] {
            XCTAssertNil(normalizeChordLookup(symbol), symbol)
            XCTAssertNil(CommonGuitarChords.shape(named: symbol), symbol)
        }
    }

    func testEveryExtendedQualityHasExactTonesAndPlayableGeometryForAllRoots() throws {
        for (quality, expectedIntervals) in intervals {
            XCTAssertEqual(quality.intervals, expectedIntervals)
            for root in GuitarNote.allCases {
                let shape = try XCTUnwrap(CommonGuitarChords.shape(named: root.displayName + quality.rawValue))
                let expected = Set(expectedIntervals.map { GuitarNote.fromMIDI(root.rawValue + $0) })
                XCTAssertEqual(Set(shape.chord.notes), expected, shape.name)
                let sounded = soundedNotes(shape)
                XCTAssertTrue(sounded.isSubset(of: expected), "Non-chord tone: \(shape.name)")
                XCTAssertTrue(sounded.contains(root), "Missing root: \(shape.name)")

                XCTAssertEqual(sounded, expected, "Missing required tone: \(shape.name)")
                assertPlayable(shape, maximumSpan: 4)
            }
        }
    }

    func testB7Sus4Flat9RetainsEveryWrittenToneIncludingPerfectFifth() throws {
        let value = ChordFingeringPresentation(symbol: "B7sus4(b9)")
        let shape = try XCTUnwrap(value.shape)
        XCTAssertEqual(soundedNotes(shape), Set([.b, .e, .fSharp, .a, .c]))
        XCTAssertTrue(value.omittedNotes.isEmpty)
        XCTAssertFalse(value.isSimplified)
        assertPlayable(shape, maximumSpan: 4)
    }

    func testAdd9UsesVerifiedLowShapesWithSafeFingers() throws {
        for root in GuitarNote.allCases {
            let shape = try XCTUnwrap(CommonGuitarChords.shape(named: root.displayName + "add9"))
            XCTAssertEqual(soundedNotes(shape), Set(shape.chord.notes), shape.name)
            assertPlayable(shape, maximumSpan: 4)
        }
    }

    private func soundedNotes(_ shape: GuitarChordShape) -> Set<GuitarNote> {
        Set(zip(GuitarTuning.standard.strings, shape.frets).compactMap { string, fret in
            fret < 0 ? nil : GuitarNote.fromMIDI(string.midi + fret)
        })
    }

    private func assertPlayable(
        _ shape: GuitarChordShape,
        maximumSpan: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(shape.frets.count, 6, shape.name, file: file, line: line)
        XCTAssertEqual(shape.fingers.count, 6, shape.name, file: file, line: line)
        let fretted = shape.frets.filter { $0 > 0 }
        XCTAssertLessThanOrEqual((fretted.max() ?? 0) - (fretted.min() ?? 0), maximumSpan, shape.name, file: file, line: line)
        XCTAssertLessThanOrEqual(shape.frets.max() ?? 0, 15, shape.name, file: file, line: line)
        // Open voicings display the nut even when the lowest fretted note is at 2.
        let expectedBase = shape.frets.contains(0) ? 1 : max(fretted.min() ?? 1, 1)
        XCTAssertEqual(shape.baseFret, expectedBase, shape.name, file: file, line: line)
        XCTAssertLessThanOrEqual(Set(shape.fingers.compactMap { $0 }).count, 4, shape.name, file: file, line: line)

        var fingerFrets: [Int: Int] = [:]
        var fingerStrings: [Int: [Int]] = [:]
        for (index, fret) in shape.frets.enumerated() {
            if fret <= 0 {
                XCTAssertNil(shape.fingers[index], shape.name, file: file, line: line)
                continue
            }
            guard let finger = shape.fingers[index] else {
                XCTFail("Missing finger: \(shape.name)", file: file, line: line)
                continue
            }
            XCTAssertTrue((1...4).contains(finger), shape.name, file: file, line: line)
            if let previousFret = fingerFrets[finger] {
                XCTAssertEqual(fret, previousFret, "Finger \(finger) at different frets: \(shape.name)", file: file, line: line)
            }
            fingerFrets[finger] = fret
            fingerStrings[finger, default: []].append(6 - index)
        }
        for (finger, strings) in fingerStrings where strings.count > 1 {
            XCTAssertTrue(shape.barres.contains { barre in
                barre.finger == finger && barre.fret == fingerFrets[finger] &&
                strings.allSatisfy { (barre.toString...barre.fromString).contains($0) }
            }, "Repeated finger needs a barre: \(shape.name)", file: file, line: line)
        }
        for barre in shape.barres {
            XCTAssertTrue((1...6).contains(barre.fromString), shape.name, file: file, line: line)
            XCTAssertTrue((1...6).contains(barre.toString), shape.name, file: file, line: line)
            XCTAssertGreaterThan(barre.fromString, barre.toString, shape.name, file: file, line: line)
            XCTAssertGreaterThan(barre.fret, 0, shape.name, file: file, line: line)
            XCTAssertEqual(fingerFrets[barre.finger], barre.fret, shape.name, file: file, line: line)
            for string in barre.toString...barre.fromString {
                let fret = shape.frets[6 - string]
                if fret >= 0 {
                    XCTAssertGreaterThanOrEqual(fret, barre.fret, "Barre covers lower/open string: \(shape.name)", file: file, line: line)
                }
            }
            // A higher-fretted endpoint can sit above a full index-finger barre.
            for string in [barre.fromString, barre.toString] where shape.frets[6 - string] == barre.fret {
                XCTAssertEqual(shape.fingers[6 - string], barre.finger, shape.name, file: file, line: line)
            }
        }
    }
}
