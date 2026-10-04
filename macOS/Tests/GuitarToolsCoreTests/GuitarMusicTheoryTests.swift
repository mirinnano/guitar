import XCTest
@testable import GuitarToolsCore

final class GuitarMusicTheoryTests:
    XCTestCase {

    func testChordLibraryContainsEveryQualityForAllRoots() {
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
            Set(CommonGuitarChords.all.map(\.id)).count,
            GuitarNote.allCases.count * GuitarChordQuality.allCases.count
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
        XCTAssertEqual(
            CommonGuitarChords
                .shape(
                    named: "B♭maj7/D"
                )?
                .name,
            "A#maj7"
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
