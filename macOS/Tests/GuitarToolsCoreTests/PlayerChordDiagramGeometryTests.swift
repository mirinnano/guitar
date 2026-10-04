import XCTest
@testable import GuitarToolsCore

final class PlayerChordDiagramGeometryTests: XCTestCase {
    private typealias Geometry = PlayerChordDiagramGeometry

    func testRowsPutThinFirstStringAtTopAndThickSixthStringNearestPlayer() {
        XCTAssertEqual(Geometry.stringCount, 6)
        XCTAssertEqual((1...6).compactMap { Geometry.row(forStringNumber: $0) }, [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(Geometry.row(forStringNumber: 1), 0)
        XCTAssertEqual(Geometry.row(forStringNumber: 6), 5)
    }

    func testArrayIndicesKeepOriginalSixToOneOrder() throws {
        XCTAssertEqual((1...6).compactMap { Geometry.arrayIndex(forStringNumber: $0) }, [5, 4, 3, 2, 1, 0])
        for stringNumber in 1...6 {
            let row = try XCTUnwrap(Geometry.row(forStringNumber: stringNumber))
            let index = try XCTUnwrap(Geometry.arrayIndex(forStringNumber: stringNumber))
            XCTAssertEqual(row + index, 5)
        }
    }

    func testInvalidStringNumbersHaveNeitherRowsNorArrayIndices() {
        for stringNumber in [Int.min, -1, 0, 7, Int.max] {
            XCTAssertNil(Geometry.row(forStringNumber: stringNumber))
            XCTAssertNil(Geometry.arrayIndex(forStringNumber: stringNumber))
        }
    }

    func testNutWindowShowsFiveActualFretsIncreasingRight() {
        XCTAssertEqual(Geometry.fretCellCount, 5)
        XCTAssertEqual(Geometry.visibleFrets(baseFret: 1), [1, 2, 3, 4, 5])
        XCTAssertEqual((1...5).compactMap { Geometry.column(forFret: $0, baseFret: 1) }, [0, 1, 2, 3, 4])
        for fret in [Int.min, -1, 0, 6, Int.max] {
            XCTAssertNil(Geometry.column(forFret: fret, baseFret: 1))
        }
    }

    func testHigherWindowsUseTheirStartingFretIncludingTwoDigitLabels() {
        for baseFret in [2, 5, 7, 10, 12, 15, 24] {
            let expected = (0..<5).map { baseFret + $0 }
            XCTAssertEqual(Geometry.visibleFrets(baseFret: baseFret), expected)
            for (column, fret) in expected.enumerated() {
                XCTAssertEqual(Geometry.column(forFret: fret, baseFret: baseFret), column)
            }
            XCTAssertNil(Geometry.column(forFret: baseFret - 1, baseFret: baseFret))
            XCTAssertNil(Geometry.column(forFret: baseFret + 5, baseFret: baseFret))
            XCTAssertNil(Geometry.column(forFret: 0, baseFret: baseFret))
            XCTAssertNil(Geometry.column(forFret: -1, baseFret: baseFret))
        }
    }

    func testInvalidBaseFretsHaveNoWindowOrColumns() {
        for baseFret in [Int.min, -1, 0, Int.max - 3, Int.max] {
            XCTAssertEqual(Geometry.visibleFrets(baseFret: baseFret), [])
            for fret in [Int.min, -1, 0, 1, 10, Int.max] {
                XCTAssertNil(Geometry.column(forFret: fret, baseFret: baseFret))
            }
        }
    }

    func testLargestRepresentableWindowDoesNotOverflow() {
        let baseFret = Int.max - 4
        XCTAssertEqual(Geometry.visibleFrets(baseFret: baseFret),
                       [Int.max - 4, Int.max - 3, Int.max - 2, Int.max - 1, Int.max])
        XCTAssertEqual(Geometry.column(forFret: Int.max, baseFret: baseFret), 4)
        XCTAssertEqual(Geometry.column(forFret: baseFret, baseFret: baseFret), 0)
        XCTAssertNil(Geometry.column(forFret: Int.min, baseFret: baseFret))
    }

    func testCFingersAndOpenMuteMarksKeepTheirOriginalArrayAssociations() throws {
        let shape = try XCTUnwrap(CommonGuitarChords.shape(named: "C"))
        XCTAssertEqual(shape.frets, [-1, 3, 2, 0, 1, 0])
        XCTAssertEqual(shape.fingers, [nil, 3, 2, nil, 1, nil])
        let expected: [(string: Int, row: Int, fret: Int, finger: Int?, column: Int?)] = [
            (1, 0, 0, nil, nil),  // Thin high e: open, top row.
            (2, 1, 1, 1, 0),     // Index finger.
            (3, 2, 0, nil, nil),
            (4, 3, 2, 2, 1),     // Middle finger.
            (5, 4, 3, 3, 2),     // Ring finger.
            (6, 5, -1, nil, nil) // Thick low E: muted, nearest player.
        ]
        for value in expected {
            let index = try XCTUnwrap(Geometry.arrayIndex(forStringNumber: value.string))
            XCTAssertEqual(Geometry.row(forStringNumber: value.string), value.row)
            XCTAssertEqual(shape.frets[index], value.fret)
            XCTAssertEqual(shape.fingers[index], value.finger)
            XCTAssertEqual(Geometry.column(forFret: shape.frets[index], baseFret: shape.baseFret), value.column)
        }
        // The geometry API never changes the stored metadata.
        XCTAssertEqual(shape.frets, [-1, 3, 2, 0, 1, 0])
        XCTAssertEqual(shape.fingers, [nil, 3, 2, nil, 1, nil])
    }

    func testBarreEndpointsMapFromStringNumbersNotArrayIndices() throws {
        let cases: [(barre: GuitarBarre, base: Int, fromRow: Int, toRow: Int, column: Int)] = [
            (GuitarBarre(fret: 1, fromString: 6, toString: 1, finger: 1), 1, 5, 0, 0),
            (GuitarBarre(fret: 2, fromString: 5, toString: 3, finger: 2), 1, 4, 2, 1),
            (GuitarBarre(fret: 10, fromString: 5, toString: 1, finger: 1), 10, 4, 0, 0),
            (GuitarBarre(fret: 12, fromString: 6, toString: 2, finger: 3), 10, 5, 1, 2)
        ]
        for value in cases {
            let fromRow = try XCTUnwrap(Geometry.row(forStringNumber: value.barre.fromString))
            let toRow = try XCTUnwrap(Geometry.row(forStringNumber: value.barre.toString))
            let column = try XCTUnwrap(Geometry.column(forFret: value.barre.fret, baseFret: value.base))
            XCTAssertEqual(fromRow, value.fromRow)
            XCTAssertEqual(toRow, value.toRow)
            XCTAssertEqual(column, value.column)
            XCTAssertGreaterThan(fromRow, toRow)
        }
        XCTAssertNil(Geometry.row(forStringNumber: 7))
        XCTAssertNil(Geometry.row(forStringNumber: 0))
        XCTAssertNil(Geometry.column(forFret: 9, baseFret: 10))
        XCTAssertNil(Geometry.column(forFret: 15, baseFret: 10))
    }
}
