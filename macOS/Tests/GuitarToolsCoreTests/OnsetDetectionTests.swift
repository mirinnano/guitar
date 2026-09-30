import XCTest
@testable import GuitarToolsCore

final class OnsetDetectionTests:
    XCTestCase {

    func testDetectsSuddenAttack() {
        var detector =
            EnergyOnsetDetector(
                minimumLevelDBFS: -45,
                minimumRiseDB: 6,
                refractorySeconds: 0.1,
                windowSize: 128
            )

        let sampleRate =
            48_000.0

        let silence =
            Array(
                repeating: Float(0),
                count: 1_024
            )

        XCTAssertNil(
            detector.process(
                samples: silence,
                sampleRate: sampleRate,
                bufferStartTimeSeconds:
                    10
            )
        )

        let attack =
            Array(
                repeating: Float(0.5),
                count: 1_024
            )

        let onset =
            detector.process(
                samples: attack,
                sampleRate: sampleRate,
                bufferStartTimeSeconds:
                    10.1
            )

        XCTAssertNotNil(onset)
        XCTAssertGreaterThanOrEqual(
            onset?.timestampSeconds
                ?? 0,
            10.1
        )
    }

    func testRefractorySuppressesDuplicateAttack() {
        var detector =
            EnergyOnsetDetector(
                minimumLevelDBFS: -45,
                minimumRiseDB: 6,
                refractorySeconds: 0.2,
                windowSize: 128
            )

        let sampleRate =
            48_000.0

        _ = detector.process(
            samples:
                Array(
                    repeating: Float(0),
                    count: 512
                ),
            sampleRate: sampleRate,
            bufferStartTimeSeconds: 2
        )

        let first =
            detector.process(
                samples:
                    Array(
                        repeating: Float(0.6),
                        count: 512
                    ),
                sampleRate: sampleRate,
                bufferStartTimeSeconds:
                    2.05
            )

        XCTAssertNotNil(first)

        _ = detector.process(
            samples:
                Array(
                    repeating: Float(0),
                    count: 512
                ),
            sampleRate: sampleRate,
            bufferStartTimeSeconds:
                2.08
        )

        let duplicate =
            detector.process(
                samples:
                    Array(
                        repeating: Float(0.6),
                        count: 512
                    ),
                sampleRate: sampleRate,
                bufferStartTimeSeconds:
                    2.1
            )

        XCTAssertNil(duplicate)
    }
}
