import XCTest
@testable import GuitarToolsCore

final class PitchAndTempoTests:
    XCTestCase {

    func testYinDetectsA440() {
        let sampleRate =
            48_000.0

        let samples =
            (0..<8_192)
                .map {
                    index in

                    Float(
                        sin(
                            2 *
                            .pi *
                            440 *
                            Double(index) /
                            sampleRate
                        ) *
                        0.6
                    )
                }

        let frequency =
            YinPitchDetector()
                .detect(
                    samples: samples,
                    sampleRate:
                        sampleRate
                )

        XCTAssertNotNil(
            frequency
        )

        XCTAssertEqual(
            frequency ?? 0,
            440,
            accuracy: 1.0
        )
    }

    func testTapTempoCalculates120() {
        var calculator =
            TapTempoCalculator()

        XCTAssertNil(
            calculator.tap(
                timestampSeconds:
                    0
            )
        )

        XCTAssertEqual(
            calculator.tap(
                timestampSeconds:
                    0.5
            ),
            120
        )

        XCTAssertEqual(
            calculator.tap(
                timestampSeconds:
                    1.0
            ),
            120
        )
    }
}
