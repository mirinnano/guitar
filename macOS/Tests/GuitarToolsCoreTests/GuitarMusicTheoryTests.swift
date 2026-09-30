import XCTest
@testable import GuitarToolsCore

final class GuitarMusicTheoryTests:
    XCTestCase {

    func testChordLibraryContainsAllAndroidQualitiesForAllRoots() {
        XCTAssertEqual(
            CommonGuitarChords
                .all
                .count,
            GuitarNote.allCases
                .count *
            GuitarChordQuality
                .allCases
                .count
        )
        XCTAssertEqual(
            CommonGuitarChords
                .all
                .count,
            192
        )
    }

    func testOpenCShapeMatchesAndroid() {
        let shape =
            CommonGuitarChords
                .shape(named: "C")

        XCTAssertEqual(
            shape?.frets,
            [-1, 3, 2, 0, 1, 0]
        )
    }

    func testChordNormalizationSupportsFlatsAndSlashBass() {
        XCTAssertEqual(
            normalizeChordLookup(
                "B♭maj7/D"
            ),
            "A#maj7"
        )

        XCTAssertEqual(
            normalizeChordLookup(
                "E(sus)"
            ),
            "Esus4"
        )
    }

    func testTuningsMatchAndroidPresets() {
        XCTAssertEqual(
            GuitarTuning.presets
                .map(\.id),
            [
                "standard",
                "drop_d",
                "drop_c_sharp",
                "drop_c",
                "eb_standard",
                "d_standard",
                "open_g",
                "dadgad"
            ]
        )
    }

    func testMinorPentatonicNotes() {
        let notes =
            GuitarScaleType
                .minorPentatonic
                .notes(root: .a)

        XCTAssertEqual(
            notes,
            Set([
                .a,
                .c,
                .d,
                .e,
                .g
            ])
        )
    }
}
