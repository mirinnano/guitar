import XCTest
@testable import GuitarToolsCore

final class ChordFingeringPresentationTests: XCTestCase {
    func testKeepsWrittenEnharmonicSpellingInsteadOfCanonicalShapeName() {
        for symbol in ["Db", "D♭", "B♭maj7", "C♯m"] {
            let value = ChordFingeringPresentation(symbol: symbol)
            XCTAssertEqual(value.symbol, symbol)
            XCTAssertEqual(value.availability, .supported)
            XCTAssertEqual(value.shape, CommonGuitarChords.shape(named: symbol))
            XCTAssertNil(value.slashBass)
            XCTAssertFalse(value.isSimplified)
        }
        XCTAssertEqual(ChordFingeringPresentation(symbol: "Db").shape?.name, "C#")
    }

    func testSlashChordRetainsSymbolAndSoundsExactBass() {
        let value = ChordFingeringPresentation(symbol: "  B♭maj7/D \n")
        XCTAssertEqual(value.symbol, "B♭maj7/D")
        XCTAssertEqual(value.availability, .supported)
        XCTAssertEqual(value.shape?.name, "A#maj7")
        XCTAssertEqual(value.slashBass, "D")
        XCTAssertFalse(value.isSimplified)
    }

    func testExactSlashBassIsNotSimplified() {
        for symbol in ["C/E", "C/C", "B♭maj7/D", "D/F#"] {
            let value = ChordFingeringPresentation(symbol: symbol)
            XCTAssertEqual(value.availability, .supported)
            XCTAssertNotNil(value.slashBass)
            XCTAssertFalse(value.isSimplified)
        }
    }

    func testNumericSixNineIsQualityNotSlashBass() {
        for symbol in ["C6/9", "Cm6/9"] {
            let value = ChordFingeringPresentation(symbol: symbol)
            XCTAssertEqual(value.availability, .supported)
            XCTAssertNil(value.slashBass)
            XCTAssertTrue(value.omittedNotes.isEmpty)
            XCTAssertFalse(value.isSimplified)
        }
        XCTAssertEqual(ChordFingeringPresentation(symbol: "C6/9/G").slashBass, "G")
    }

    func testDeclaredOptionalOmissionIsSimplified() {
        let rich = ChordFingeringPresentation(symbol: "C13")
        XCTAssertTrue(rich.isSimplified)
        XCTAssertFalse(rich.omittedNotes.isEmpty)
    }

    func testNoChordIsNotAnUnavailableDiagram() {
        for symbol in ["NC", "N.C.", "nc", " n.c.\n"] {
            let value = ChordFingeringPresentation(symbol: symbol)
            XCTAssertEqual(value.availability, .noChord)
            XCTAssertNil(value.shape)
            XCTAssertNil(value.slashBass)
            XCTAssertFalse(value.isSimplified)
        }
    }

    func testUnsupportedSymbolsNeverClaimAnExactOrSimplifiedShape() {
        for symbol in ["", "not a chord", "Cunknown", "Cunknown/E", "C/", "C/unknown"] {
            let value = ChordFingeringPresentation(symbol: symbol)
            XCTAssertEqual(value.symbol, symbol)
            XCTAssertEqual(value.availability, .unavailable)
            XCTAssertNil(value.shape)
            XCTAssertFalse(value.isSimplified)
        }
        XCTAssertNil(ChordFingeringPresentation(symbol: "Cunknown/E").slashBass)
    }
}
