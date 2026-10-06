import Foundation
import XCTest
@testable import GuitarToolsCore

final class YinPitchDetectorTests: XCTestCase {
    private let notes = [24, 35, 38, 40, 45, 50, 55, 59, 64, 84]
    private let analysisRates = [11_025.0, 12_000.0, 14_700.0, 16_000.0]

    func testNativeRatesDetectLowNotesAndAllStandardStrings() throws {
        for rate in [44_100.0, 48_000.0, 96_000.0] {
            for midi in [35, 38, 40, 45, 50, 55, 59, 64] {
                let frequency = GuitarNote.frequency(forMIDI: midi)
                try assertPitch(frequency, rate: rate, count: 4_096, harmonics: [0.6, 0.25, 0.15, 0.08], cents: 1)
            }
        }
    }

    func testBoundedAnalysisRatesCoverCustomLowCThroughHighC() throws {
        for rate in analysisRates {
            for midi in notes {
                for phase in [0.0, 0.7, 1.5] {
                    try assertPitch(GuitarNote.frequency(forMIDI: midi), rate: rate, count: 2_048, phase: phase, cents: 2)
                }
            }
        }
    }

    func testCustomC1NeedsBothRangeAndEnoughSamples() throws {
        let frequency = GuitarNote.frequency(forMIDI: 24)
        for rate in [44_100.0, 48_000.0] {
            let samples = signal(frequency, rate: rate, count: 4_096)
            XCTAssertNil(YinPitchDetector().detect(samples: samples, sampleRate: rate))
            try assertPitch(frequency, rate: rate, count: 4_096, cents: 1)
        }
        XCTAssertNil(YinPitchDetector(minimumFrequencyHz: 27.5).detect(
            samples: signal(frequency, rate: 96_000, count: 4_096), sampleRate: 96_000))
        try assertPitch(frequency, rate: 96_000, count: 8_192, cents: 1)
    }

    func testShortWindowsNeverReturnTheirLastLagAsAPitch() {
        let detector = YinPitchDetector(minimumFrequencyHz: 27.5)
        for rate in [44_100.0, 48_000.0, 96_000.0] {
            for count in [128, 256, 512, 1_024] {
                for midi in notes {
                    let frequency = GuitarNote.frequency(forMIDI: midi)
                    guard Double(count / 2) < rate / frequency else { continue }
                    for phase in [0.0, 1.5] {
                        XCTAssertNil(detector.detect(samples: signal(frequency, rate: rate, count: count, phase: phase), sampleRate: rate),
                                     "midi=\(midi) rate=\(rate) count=\(count) phase=\(phase)")
                    }
                }
            }
        }
        // Previous deterministic errors: E2 -> 93.75 Hz, Drop D -> 86.13281 Hz,
        // and E4 -> 375 Hz; these are N/2 boundaries, not complete valleys.
        XCTAssertNil(detector.detect(samples: signal(82.406889, rate: 48_000, count: 1_024), sampleRate: 48_000))
        XCTAssertNil(detector.detect(samples: signal(73.416192, rate: 44_100, count: 1_024), sampleRate: 44_100))
        XCTAssertNil(detector.detect(samples: signal(329.627557, rate: 48_000, count: 256), sampleRate: 48_000))
    }

    func testWeakFundamentalIsPreferredOnlyWithStrongIntegerPeriodEvidence() throws {
        for rate in analysisRates {
            for midi in [24, 35, 38, 40, 64] {
                try assertPitch(GuitarNote.frequency(forMIDI: midi), rate: rate, count: 2_048,
                                harmonics: [0.05, 0.6, 0, 0.2], cents: 2)
            }
        }
        // Previously 164.96818 Hz (+1201.62 cents) instead of E2.
        try assertPitch(GuitarNote.frequency(forMIDI: 40), rate: 48_000, count: 4_096,
                        harmonics: [0.05, 0.6, 0, 0.2], cents: 1)
    }

    func testDecayingWeakFundamentalWithDCDoesNotRemainAnOctaveHigh() throws {
        // Matching the late, gently decaying pluck window: amplitude mismatch
        // previously prevented the true C1 period from improving depth by 10x.
        for rate in analysisRates {
            for midi in [24, 40, 45, 64] {
                for phase in [0.0, 0.7] {
                    try assertPitch(GuitarNote.frequency(forMIDI: midi), rate: rate, count: 2_048,
                                    harmonics: [0.05, 0.6, 0, 0.2], phase: phase, noise: 0.003,
                                    decay: 0.35, dc: 0.2, startSeconds: 0.3, cents: 5)
                }
            }
            // Envelope compensation must not lower an already correct pure tone.
            for midi in [24, 40, 64, 84] {
                try assertPitch(GuitarNote.frequency(forMIDI: midi), rate: rate, count: 2_048,
                                decay: 0.35, startSeconds: 0.3, cents: 2)
            }
        }
    }

    func testMissingFundamentalWithOddHarmonicsRetainsItsPeriod() throws {
        for midi in [24, 40, 64] {
            try assertPitch(GuitarNote.frequency(forMIDI: midi), rate: 12_000, count: 2_048,
                            harmonics: [0, 0.6, 0.2, 0.1], cents: 2)
        }
    }

    func testPureHighNotesAreNotPromotedBecauseOfIntegerLagQuantization() throws {
        for rate in analysisRates {
            for frequency in [GuitarNote.frequency(forMIDI: 84), 1_190.0, 1_200.0] {
                for phase in [0.0, 0.7, 1.5, 2.5] {
                    try assertPitch(frequency, rate: rate, count: 2_048, phase: phase, cents: 2)
                }
            }
        }
    }

    func testNoiseDoesNotSelectTheFirstSmallRippleBeforeTheValley() throws {
        let frequency = GuitarNote.frequency(forMIDI: 40)
        for rate in [44_100.0, 48_000.0, 96_000.0] {
            for noise in [0.1, 0.3] {
                // Original errors at E2 were +9.20/+58.29 cents at 48k and
                // +36.86/+85.77 cents at 96k, using this exact seeded noise.
                try assertPitch(frequency, rate: rate, count: 4_096, noise: noise, cents: 5)
            }
        }
        for midi in [24, 40, 64] {
            try assertPitch(GuitarNote.frequency(forMIDI: midi), rate: 12_000, count: 2_048, noise: 0.1, cents: 5)
        }
    }

    func testNoisyFallbackDoesNotPreferALaterSubharmonic() {
        let frequency = GuitarNote.frequency(forMIDI: 64)
        let result = YinPitchDetector().detect(
            samples: signal(frequency, rate: 48_000, count: 4_096, noise: 0.5), sampleRate: 48_000)
        // Nil is preferable to confidently inventing a pitch in heavy noise.
        // The original global-min fallback returned 55.04587 Hz (-3098.56 cents).
        if let result { XCTAssertLessThan(abs(1_200 * log2(result / frequency)), 30) }
    }

    func testDecayAndDCOffset() throws {
        for rate in analysisRates {
            for midi in [24, 35, 38, 40, 64] {
                let frequency = GuitarNote.frequency(forMIDI: midi)
                try assertPitch(frequency, rate: rate, count: 2_048, harmonics: [0.6, 0.25, 0.15], decay: 0.1, cents: 5)
                try assertPitch(frequency, rate: rate, count: 2_048, dc: 0.5, cents: 2)
            }
        }
        try assertPitch(GuitarNote.frequency(forMIDI: 35), rate: 48_000, count: 4_096,
                        harmonics: [0.6, 0.25, 0.15], decay: 0.02, cents: 5)
        XCTAssertNil(YinPitchDetector(minimumFrequencyHz: 27.5).detect(
            samples: signal(GuitarNote.frequency(forMIDI: 24), rate: 12_000, count: 2_048,
                            harmonics: [0.6, 0.25, 0.15], decay: 0.02), sampleRate: 12_000))
    }

    func testInclusiveRangeBoundariesHaveInterpolationNeighbors() throws {
        for rate in analysisRates {
            for frequency in [27.5, 55.0, 1_200.0] {
                try assertPitch(frequency, rate: rate, count: 2_048, cents: 2)
            }
        }
        for midi in [40, 59, 64, 84] {
            let frequency = GuitarNote.frequency(forMIDI: midi)
            let samples = signal(frequency, rate: 48_000, count: 4_096)
            let result = YinPitchDetector(minimumFrequencyHz: frequency, maximumFrequencyHz: frequency * 2)
                .detect(samples: samples, sampleRate: 48_000)
            let actual = try XCTUnwrap(result)
            XCTAssertLessThan(abs(1_200 * log2(actual / frequency)), 2)
        }
        XCTAssertNil(YinPitchDetector().detect(samples: signal(54, rate: 48_000, count: 4_096), sampleRate: 48_000))
        XCTAssertNil(YinPitchDetector().detect(samples: signal(1_210, rate: 48_000, count: 4_096), sampleRate: 48_000))
    }

    func testSilenceConstantAndUnpitchedNoiseReturnNil() {
        let detector = YinPitchDetector(minimumFrequencyHz: 27.5)
        for value: Float in [0, 0.5, -0.5, Float.greatestFiniteMagnitude] {
            XCTAssertNil(detector.detect(samples: [Float](repeating: value, count: 2_048), sampleRate: 12_000))
        }
        for seed in UInt64(1)...20 {
            XCTAssertNil(detector.detect(samples: signal(440, rate: 12_000, count: 2_048,
                                                         harmonics: [], noise: 0.6, seed: seed), sampleRate: 12_000))
        }
        for count in [0, 1, 63] {
            XCTAssertNil(detector.detect(samples: [Float](repeating: 0, count: count), sampleRate: 12_000))
        }
    }

    func testInvalidParametersAndSamplesReturnNilWithoutIntegerTraps() {
        let samples = signal(82.406889, rate: 48_000, count: 1_024)
        let invalid = [0.0, -1, Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude, .leastNonzeroMagnitude]
        for value in invalid {
            XCTAssertNil(YinPitchDetector().detect(samples: samples, sampleRate: value))
            XCTAssertNil(YinPitchDetector(minimumFrequencyHz: value).detect(samples: samples, sampleRate: 48_000))
        }
        for value in [0.0, -1, Double.nan, .infinity, -.infinity, .leastNonzeroMagnitude, 40] {
            XCTAssertNil(YinPitchDetector(maximumFrequencyHz: value).detect(samples: samples, sampleRate: 48_000))
        }
        for value in [0.0, -1, 1, Double.nan, .infinity, -.infinity] {
            XCTAssertNil(YinPitchDetector(threshold: value).detect(samples: samples, sampleRate: 48_000))
        }
        for value: Float in [.nan, .infinity, -.infinity] {
            var contaminated = samples
            contaminated[512] = value
            XCTAssertNil(YinPitchDetector().detect(samples: contaminated, sampleRate: 48_000))
        }
        XCTAssertNil(YinPitchDetector(minimumFrequencyHz: 1_200, maximumFrequencyHz: 55).detect(samples: samples, sampleRate: 48_000))
    }

    func testPitchReadingAndTuningRejectInvalidNumericInputs() {
        for invalid in [0.0, -1, Double.nan, .infinity, -.infinity] {
            XCTAssertNil(GuitarPitchReading.fromFrequency(invalid))
            XCTAssertNil(GuitarPitchReading.fromFrequency(440, a4Hz: invalid))
            XCTAssertNil(GuitarTuning.standard.target(stringNumber: 6, frequencyHz: invalid))
            XCTAssertNil(GuitarTuning.standard.closestString(frequencyHz: 440, a4Hz: invalid))
            XCTAssertEqual(GuitarNote.nearestMIDI(frequencyHz: invalid), 0)
            XCTAssertEqual(GuitarNote.nearestMIDI(frequencyHz: 440, a4Hz: invalid), 0)
        }
        // Finite extremes must not overflow/underflow a ratio before Int conversion.
        let midi = GuitarNote.nearestMIDI(frequencyHz: .greatestFiniteMagnitude, a4Hz: .leastNonzeroMagnitude)
        XCTAssertGreaterThan(midi, 84)
        XCTAssertEqual(GuitarNote.frequency(forMIDI: Int.min), 0)
        XCTAssertNil(GuitarPitchReading.fromFrequency(.greatestFiniteMagnitude))
        XCTAssertNil(GuitarTuning.standard.target(stringNumber: 6, frequencyHz: 440, a4Hz: .leastNonzeroMagnitude))
        for midi in notes {
            let frequency = GuitarNote.frequency(forMIDI: midi, a4Hz: 432)
            let reading = GuitarPitchReading.fromFrequency(frequency, a4Hz: 432)
            XCTAssertEqual(reading?.midi, midi)
            XCTAssertEqual(reading?.cents ?? .infinity, 0, accuracy: 1e-8)
        }
    }

    private func assertPitch(
        _ frequency: Double, rate: Double, count: Int,
        harmonics: [Double] = [0.6], phase: Double = 0, noise: Double = 0,
        decay: Double = 0, dc: Double = 0, startSeconds: Double = 0, cents: Double,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let result = YinPitchDetector(minimumFrequencyHz: 27.5).detect(
            samples: signal(frequency, rate: rate, count: count, harmonics: harmonics,
                            phase: phase, noise: noise, decay: decay, dc: dc, startSeconds: startSeconds), sampleRate: rate)
        let context = "f=\(frequency) rate=\(rate) N=\(count) phase=\(phase) noise=\(noise) harmonics=\(harmonics)"
        let actual = try XCTUnwrap(result, context, file: file, line: line)
        XCTAssertLessThan(abs(1_200 * log2(actual / frequency)), cents, context, file: file, line: line)
    }

    private func signal(
        _ frequency: Double, rate: Double, count: Int,
        harmonics: [Double] = [0.6], phase: Double = 0, noise: Double = 0,
        decay: Double = 0, dc: Double = 0, startSeconds: Double = 0,
        seed: UInt64 = 0x123456789abcdef
    ) -> [Float] {
        var state = seed
        return (0..<count).map { index in
            let time = startSeconds + Double(index) / rate
            var value = 0.0
            for (harmonic, amplitude) in harmonics.enumerated() {
                value += amplitude * sin(2 * .pi * frequency * Double(harmonic + 1) * time + phase * Double(harmonic + 1))
            }
            if decay > 0 { value *= exp(-time / decay) }
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let uniform = 2 * Double(state >> 11) / 9_007_199_254_740_992.0 - 1
            return Float(value + noise * uniform + dc)
        }
    }
}
