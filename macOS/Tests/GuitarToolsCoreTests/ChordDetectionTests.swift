import XCTest
@testable import GuitarToolsCore

final class ChordDetectionTests: XCTestCase {

    private let sampleRate = 48_000.0
    private let frameCount = 4_096

    func testDetectsCMajor() {
        let detector = SpectralChordDetector()

        let samples = composite(
            frequencies: [
                261.6256,
                329.6276,
                391.9954
            ]
        )

        let estimate =
            detector.analyze(
                samples: samples,
                sampleRate: sampleRate
            )

        XCTAssertEqual(
            estimate?.name,
            "C"
        )
    }

    func testDetectsAMinor() {
        let detector = SpectralChordDetector()

        let samples = composite(
            frequencies: [
                220.0,
                261.6256,
                329.6276
            ]
        )

        let estimate =
            detector.analyze(
                samples: samples,
                sampleRate: sampleRate
            )

        XCTAssertEqual(
            estimate?.name,
            "Am"
        )
    }

    func testSilenceReturnsNil() {
        let detector = SpectralChordDetector()

        let estimate =
            detector.analyze(
                samples:
                    Array(
                        repeating: 0,
                        count: frameCount
                    ),
                sampleRate: sampleRate
            )

        XCTAssertNil(estimate)
    }

    func testStabilizerRequiresRepeatedVotes() {
        var stabilizer =
            ChordStabilizer(
                windowSize: 4,
                votesRequired: 3
            )

        let estimate =
            ChordEstimate(
                root: .g,
                quality: .major,
                confidence: 0.8,
                chroma:
                    Array(
                        repeating: 0,
                        count: 12
                    ),
                levelDBFS: -12
            )

        XCTAssertNil(
            stabilizer.update(estimate)
        )
        XCTAssertNil(
            stabilizer.update(estimate)
        )
        XCTAssertEqual(
            stabilizer.update(estimate),
            "G"
        )
    }

    private func composite(
        frequencies: [Double]
    ) -> [Float] {
        (0..<frameCount).map { index in
            let time =
                Double(index) /
                sampleRate

            let value =
                frequencies
                    .reduce(0.0) {
                        result,
                        frequency in
                        result +
                            sin(
                                2.0 *
                                .pi *
                                frequency *
                                time
                            )
                    } /
                Double(
                    max(
                        frequencies.count,
                        1
                    )
                )

            return Float(
                value * 0.65
            )
        }
    }
}
