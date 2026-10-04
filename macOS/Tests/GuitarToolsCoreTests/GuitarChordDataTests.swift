import XCTest
@testable import GuitarToolsCore

final class GuitarChordDataTests: XCTestCase {
    private let tuning = [40, 45, 50, 55, 59, 64]
    private let degreeSemitones: [String: Int] = [
        "1": 0, "2": 2, "b3": 3, "3": 4, "4": 5, "b5": 6, "5": 7,
        "#5": 8, "6": 9, "bb7": 9, "b7": 10, "7": 11,
        "b9": 13, "9": 14, "#9": 15, "11": 17, "#11": 18, "b13": 20, "13": 21
    ]

    func testPracticalChordsHaveGenuineChoicesAndPreserveDefault() throws {
        for symbol in ["C", "Am", "F", "G", "D", "Bbmaj7/D", "C/D", "C6/9", "Cm6/9"] {
            let data = try XCTUnwrap(GuitarChordData(symbol: symbol), symbol)
            XCTAssertGreaterThanOrEqual(data.voicings.count, 3, symbol)
            XCTAssertEqual(data.voicings.first?.shape, ChordFingeringPresentation(symbol: symbol).shape)
            XCTAssertGreaterThan(Set(data.voicings.map { $0.shape.baseFret }).count, 1, symbol)
            XCTAssertEqual(Set(data.voicings.map { $0.shape.frets }).count, data.voicings.count, symbol)
            let bass = try XCTUnwrap(ParsedGuitarChordSymbol(symbol)).bass ?? data.voicings[0].shape.chord.root
            for voicing in data.voicings { assertVerified(voicing, bass: bass) }
        }
        // These are the checked canonical open assignments, not regenerated
        // minimum-finger approximations of the same fret array.
        let c = try XCTUnwrap(GuitarChordData(symbol: "C")).voicings[0].shape
        XCTAssertEqual(c.frets, [-1,3,2,0,1,0])
        XCTAssertEqual(c.fingers, [nil,3,2,nil,1,nil])
        let am = try XCTUnwrap(GuitarChordData(symbol: "Am")).voicings[0].shape
        XCTAssertEqual(am.frets, [-1,0,2,2,1,0])
        XCTAssertEqual(am.fingers, [nil,nil,2,3,1,nil])
        let d = try XCTUnwrap(GuitarChordData(symbol: "D")).voicings[0].shape
        XCTAssertEqual(d.fingers, [nil,nil,nil,1,3,2])
    }

    func testAll37QualitiesAnd12RootsHaveVerifiedBoundedAlternativesAndHonestTheory() throws {
        XCTAssertEqual(GuitarChordQuality.allCases.count, 37)
        for root in GuitarNote.allCases {
            for quality in GuitarChordQuality.allCases {
                let symbol = root.displayName + quality.rawValue
                let data = try XCTUnwrap(GuitarChordData(symbol: symbol), symbol)
                XCTAssertFalse(data.voicings.isEmpty, symbol)
                XCTAssertLessThanOrEqual(data.voicings.count, 18, symbol)
                XCTAssertEqual(data.voicings.first?.shape, NoCapoGuitarVoicings.resolve(chord: GuitarChord(root: root, quality: quality)))
                XCTAssertEqual(Set(data.voicings.map(\.id)).count, data.voicings.count, symbol)
                XCTAssertEqual(Set(data.voicings.map { $0.shape.frets }).count, data.voicings.count, symbol)
                XCTAssertEqual(data.intervalLabels.compactMap { degreeSemitones[$0] }, quality.intervals, symbol)
                XCTAssertEqual(data.theoreticalNotes, quality.intervals.map { GuitarNote.fromMIDI(root.rawValue + $0) }, symbol)
                XCTAssertFalse(data.japaneseName.isEmpty)
                XCTAssertFalse(data.explanation.isEmpty)
                for alias in data.aliases {
                    XCTAssertEqual(GuitarChordData.selectionKey(for: root.displayName + alias), data.selectionKey, alias)
                }
                for voicing in data.voicings { assertVerified(voicing, bass: root) }
            }
        }
        // Alternatives must never turn the static default catalog into a list
        // containing the same chord multiple times.
        XCTAssertEqual(CommonGuitarChords.all.count, 444)
        XCTAssertEqual(Set(CommonGuitarChords.all.map(\.id)).count, 444)
    }

    func testDegreeSpellingRetainsMusicalMeaningRatherThanPitchClassOnly() throws {
        XCTAssertEqual(try XCTUnwrap(GuitarChordData(symbol: "Cdim7")).intervalLabels, ["1","b3","b5","bb7"])
        XCTAssertEqual(try XCTUnwrap(GuitarChordData(symbol: "C7#9")).intervalLabels, ["1","3","5","b7","#9"])
        XCTAssertEqual(try XCTUnwrap(GuitarChordData(symbol: "C6/9")).intervalLabels, ["1","3","5","6","9"])
        XCTAssertEqual(try XCTUnwrap(GuitarChordData(symbol: "C9sus4")).intervalLabels, ["1","4","5","b7","9"])
        let rich = try XCTUnwrap(GuitarChordData(symbol: "C13"))
        XCTAssertEqual(rich.theoreticalNotes.count, 7)
        XCTAssertEqual(rich.intervalLabels, ["1","3","5","b7","9","11","13"])
        XCTAssertTrue(rich.voicings.allSatisfy { !$0.omittedNotes.isEmpty })
        let slash = try XCTUnwrap(GuitarChordData(symbol: "C/D"))
        XCTAssertEqual(slash.theoreticalNotes, [.c, .e, .g])
        XCTAssertTrue(slash.explanation.contains("最低音は D"))
    }

    func testEnharmonicQualityAliasesAndExplicitRootBassShareSelectionIdentity() throws {
        for group in [
            ["C#maj7", "DbM7", "D♭△7", "C♯maj7/C#"],
            ["Cm7(b5)", "Cm7b5", "Cm7-5", "Cø7"],
            ["C6/9", "C6/9/C"], ["C", "CM", "Cmaj", "C/C"],
            ["Bbmaj7/D", "A#M7/D", "B♭maj7/D"]
        ] {
            let reference = try XCTUnwrap(GuitarChordData(symbol: group[0]))
            for alias in group {
                let data = try XCTUnwrap(GuitarChordData(symbol: alias))
                XCTAssertEqual(data.symbol, alias)
                XCTAssertEqual(data.selectionKey, reference.selectionKey)
                XCTAssertEqual(data.voicings, reference.voicings)
            }
        }
        XCTAssertNotEqual(GuitarChordData.selectionKey(for: "C6/9"), GuitarChordData.selectionKey(for: "C6"))
        XCTAssertNotEqual(GuitarChordData.selectionKey(for: "C6/9"), GuitarChordData.selectionKey(for: "C9"))
        XCTAssertNotEqual(GuitarChordData.selectionKey(for: "C/D"), GuitarChordData.selectionKey(for: "C"))
        XCTAssertNotEqual(GuitarChordData.selectionKey(for: "CM"), GuitarChordData.selectionKey(for: "Cm"))
    }

    func testVoicingSelectionResolvesOnlyVerifiedOptionsAndFallsBackOnBadID() throws {
        for symbol in ["C", "Am", "F", "C/D", "Bbmaj7/D", "C6/9/G", "C13"] {
            let data = try XCTUnwrap(GuitarChordData(symbol: symbol))
            for voicing in data.voicings {
                let selected = ChordFingeringPresentation(symbol: symbol, voicingID: voicing.id)
                XCTAssertEqual(selected.shape, voicing.shape)
                XCTAssertEqual(selected.omittedNotes, voicing.omittedNotes)
                XCTAssertEqual(selected.slashBass, ChordFingeringPresentation(symbol: symbol).slashBass)
            }
            for badID in ["", "made-up", try XCTUnwrap(GuitarChordData(symbol: "D#7")).voicings[0].id] {
                XCTAssertEqual(ChordFingeringPresentation(symbol: symbol, voicingID: badID), ChordFingeringPresentation(symbol: symbol))
            }
        }
        let sharp = try XCTUnwrap(GuitarChordData(symbol: "C#"))
        let choice = try XCTUnwrap(sharp.voicings.last)
        XCTAssertEqual(ChordFingeringPresentation(symbol: "Db", voicingID: choice.id).shape, choice.shape)
        // Root-position choices cannot silently replace a slash-bass selection.
        let c = try XCTUnwrap(GuitarChordData(symbol: "C"))
        XCTAssertEqual(ChordFingeringPresentation(symbol: "C/E", voicingID: c.voicings[0].id), ChordFingeringPresentation(symbol: "C/E"))
    }

    func testUnknownAndMalformedSymbolsAreNil() {
        for symbol in ["", "NC", "N.C.", "H", "Cunknown", "C7(b9#11)", "C7(b9,#11)", "C/", "C/G/H", "C6/8", "C6/9/", "C7(b9", "C7)b9(", "C/Unknown", "C()", "C7( )", "C7((b9))", "C(m)(7)"] {
            XCTAssertNil(GuitarChordData(symbol: symbol), symbol)
            XCTAssertNil(GuitarChordData.selectionKey(for: symbol), symbol)
        }
        XCTAssertEqual(GuitarChordData(symbol: "  B♭maj7/D \n")?.symbol, "B♭maj7/D")
    }

    func testGeometryIdentityIncludesFingersAndBarresNotJustChordName() throws {
        let chord = GuitarChord(root: .a, quality: .major)
        let individual = GuitarChordShape(chord: chord, frets: [-1,0,2,2,2,0],
                                         fingers: [nil,nil,1,2,3,nil], barres: [], baseFret: 1)
        let barred = GuitarChordShape(chord: chord, frets: individual.frets,
                                     fingers: [nil,nil,1,1,1,nil],
                                     barres: [GuitarBarre(fret: 2, fromString: 4, toString: 2, finger: 1)], baseFret: 1)
        XCTAssertEqual(individual.id, barred.id)
        let key = try XCTUnwrap(GuitarChordData.selectionKey(for: "A"))
        XCTAssertNotEqual(GuitarChordVoicing(shape: individual, selectionKey: key).id,
                          GuitarChordVoicing(shape: barred, selectionKey: key).id)
    }

    func testRepeatedSelectionsAreCachedDeterministicAndBounded() throws {
        let data = try XCTUnwrap(GuitarChordData(symbol: "F#7sus4(b9)/C#"))
        let chosen = try XCTUnwrap(data.voicings.last)
        let start = Date()
        for _ in 0..<1_000 {
            XCTAssertEqual(ChordFingeringPresentation(symbol: data.symbol, voicingID: chosen.id).shape, chosen.shape)
            XCTAssertEqual(GuitarChordData.selectionKey(for: "Gb7sus4b9/Db"), data.selectionKey)
        }
        // Deliberately generous for debug CI; repeated renders must not repeat
        // bounded fret searches. This is not a microbenchmark of first search.
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
        XCTAssertEqual(GuitarChordData(symbol: data.symbol)?.voicings, data.voicings)
    }

    private func assertVerified(_ voicing: GuitarChordVoicing, bass: GuitarNote,
                                file: StaticString = #filePath, line: UInt = #line) {
        let shape = voicing.shape
        let midis = zip(tuning, shape.frets).compactMap { midi, fret in fret < 0 ? nil : midi + fret }
        let sounded = Set(midis.map(GuitarNote.fromMIDI))
        let written = Set(shape.chord.notes)
        XCTAssertEqual(midis.min().map(GuitarNote.fromMIDI), bass, file: file, line: line)
        XCTAssertTrue(sounded.isSubset(of: written.union([bass])), file: file, line: line)
        let omissions = written.subtracting(sounded)
        var permitted: Set<GuitarNote> = []
        if shape.chord.quality == .dominant7 ||
            (shape.chord.quality.intervals.count >= 5 && shape.chord.quality.intervals.contains(7)) {
            permitted.insert(GuitarNote.fromMIDI(shape.chord.root.rawValue + 7))
        }
        if shape.chord.quality == .dominant13 { permitted.insert(GuitarNote.fromMIDI(shape.chord.root.rawValue + 17)) }
        permitted.remove(bass)
        XCTAssertTrue(omissions.isSubset(of: permitted), file: file, line: line)
        XCTAssertEqual(Set(voicing.omittedNotes), omissions, file: file, line: line)
        XCTAssertTrue(sounded.contains(shape.chord.root), file: file, line: line)
        XCTAssertEqual(voicing.openStringCount, shape.frets.filter { $0 == 0 }.count, file: file, line: line)
        XCTAssertEqual(voicing.barreCount, shape.barres.count, file: file, line: line)
        XCTAssertEqual(voicing.lowestFret, shape.frets.filter { $0 > 0 }.min() ?? 0, file: file, line: line)
        XCTAssertEqual(voicing.maxFret, shape.frets.filter { $0 >= 0 }.max() ?? 0, file: file, line: line)
        XCTAssertEqual(voicing.stringNotes.count, 6, file: file, line: line)
        for index in 0..<6 {
            let tone = voicing.stringNotes[index]
            XCTAssertEqual(tone.stringNumber, 6 - index, file: file, line: line)
            XCTAssertEqual(tone.fret, shape.frets[index], file: file, line: line)
            XCTAssertEqual(tone.midi, shape.frets[index] < 0 ? nil : tuning[index] + shape.frets[index], file: file, line: line)
            XCTAssertEqual(tone.note, tone.midi.map(GuitarNote.fromMIDI), file: file, line: line)
        }
        XCTAssertTrue(shape.frets.allSatisfy { (-1...15).contains($0) }, file: file, line: line)
        let positive = shape.frets.filter { $0 > 0 }
        XCTAssertLessThanOrEqual((positive.max() ?? 0) - (positive.min() ?? 0), 4, file: file, line: line)
        XCTAssertTrue(positive.allSatisfy { (1...5).contains($0 - shape.baseFret + 1) }, file: file, line: line)
        if shape.frets.contains(0) { XCTAssertEqual(shape.baseFret, 1, file: file, line: line) }
        XCTAssertTrue(NoCapoGuitarVoicings.hasValidFingering(frets: shape.frets, fingers: shape.fingers, barres: shape.barres), file: file, line: line)
        XCTAssertLessThanOrEqual(Set(shape.fingers.compactMap { $0 }).count, 4, file: file, line: line)
        var fingerIndices: [Int: [Int]] = [:]
        for index in 0..<6 {
            if shape.frets[index] <= 0 {
                XCTAssertNil(shape.fingers[index], file: file, line: line)
            } else if let finger = shape.fingers[index] {
                XCTAssertTrue((1...4).contains(finger), file: file, line: line)
                fingerIndices[finger, default: []].append(index)
            } else {
                XCTFail("Unfingered sounding string", file: file, line: line)
            }
        }
        for (finger, indices) in fingerIndices {
            XCTAssertEqual(Set(indices.map { shape.frets[$0] }).count, 1, file: file, line: line)
            if indices.count > 1 {
                XCTAssertTrue(shape.barres.contains { barre in
                    barre.finger == finger && barre.fret == shape.frets[indices[0]] &&
                        indices.allSatisfy { (barre.toString...barre.fromString).contains(6 - $0) }
                }, file: file, line: line)
            }
        }
        for barre in shape.barres {
            for string in barre.toString...barre.fromString where shape.frets[6 - string] >= 0 {
                XCTAssertGreaterThanOrEqual(shape.frets[6 - string], barre.fret, file: file, line: line)
            }
        }
    }
}
