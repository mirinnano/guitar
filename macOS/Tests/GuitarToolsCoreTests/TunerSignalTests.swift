import XCTest
@testable import GuitarToolsCore

final class TunerSignalTests: XCTestCase {
    func testSmallNativeBlocksCoverAllStringsAndCustomLowC() throws {
        for rate in [44_100.0, 48_000, 96_000] {
            for midi in [24, 40, 45, 50, 55, 59, 64, 84] {
                let frequency = GuitarNote.frequency(forMIDI: midi)
                var accumulator = TunerFrameAccumulator()
                let frame = try XCTUnwrap(feed(&accumulator, rate: rate, frequency: frequency))
                XCTAssertEqual(frame.samples.count, 2_048)
                XCTAssertLessThanOrEqual(frame.sampleRate, 16_000)
                let detected = try XCTUnwrap(YinPitchDetector(minimumFrequencyHz: 27.5).detect(samples: frame.samples, sampleRate: frame.sampleRate), "rate=\(rate), MIDI=\(midi)")
                XCTAssertLessThan(abs(1_200 * log2(detected / frequency)), 2, "rate=\(rate), MIDI=\(midi)")
            }
        }
    }

    func testNoWindowUntilEnoughNativeSamplesAndCadenceIsBounded() throws {
        var accumulator = TunerFrameAccumulator()
        let rate = 48_000.0
        var results: [TunerAnalysisFrame] = []
        for start in stride(from: 0, to: 48_000, by: 128) {
            let window = accumulator.append(samples: wave(start: start, count: 128, frequency: 82.4, rate: rate), sampleRate: rate, timestampSeconds: Double(start) / rate)
            if start + 128 < 6_144 { XCTAssertNil(window) }
            if let window { results.append(window) }
        }
        XCTAssertGreaterThan(results.count, 20)
        XCTAssertLessThanOrEqual(results.count, 30)
        for (previous, next) in zip(results, results.dropFirst()) {
            XCTAssertGreaterThanOrEqual(next.timestampSeconds - previous.timestampSeconds, 1.0 / 30 - 0.001)
        }
    }

    func testRateChangesGapsAndNonfiniteDataResetTheWindow() throws {
        var accumulator = TunerFrameAccumulator()
        XCTAssertNotNil(feed(&accumulator, rate: 48_000, frequency: 82.4))
        var revision = accumulator.revision
        XCTAssertNil(accumulator.append(samples: wave(start: 0, count: 128, frequency: 220, rate: 96_000), sampleRate: 96_000, timestampSeconds: 2))
        XCTAssertGreaterThan(accumulator.revision, revision)
        revision = accumulator.revision
        XCTAssertNil(accumulator.append(samples: [Float.nan], sampleRate: 96_000, timestampSeconds: 2.01))
        XCTAssertGreaterThan(accumulator.revision, revision)
        for rate in [Double.nan, .infinity, 0, -1, 1e300] {
            XCTAssertNil(accumulator.append(samples: [0.1], sampleRate: rate, timestampSeconds: 0))
        }
        XCTAssertNil(accumulator.append(samples: [0.1], sampleRate: 48_000, timestampSeconds: .infinity))
        XCTAssertNotNil(feed(&accumulator, rate: 48_000, frequency: 329.6))
        revision = accumulator.revision
        XCTAssertNil(accumulator.append(samples: wave(start: 0, count: 128, frequency: 220, rate: 48_000), sampleRate: 48_000, timestampSeconds: 10))
        XCTAssertGreaterThan(accumulator.revision, revision)
    }

    func testLowPassPreventsAnUltrasonicPartialAliasingIntoAnotherNote() throws {
        var accumulator = TunerFrameAccumulator()
        let rate = 48_000.0
        let fundamental = GuitarNote.frequency(forMIDI: 40)
        var last: TunerAnalysisFrame?
        for start in stride(from: 0, to: 24_576, by: 128) {
            let samples = (start..<(start + 128)).map { index -> Float in
                let time = Double(index) / rate
                return Float(0.08 * sin(2 * .pi * fundamental * time) + 0.6 * sin(2 * .pi * (12_000 + 220) * time))
            }
            if let frame = accumulator.append(samples: samples, sampleRate: rate, timestampSeconds: Double(start) / rate) { last = frame }
        }
        let frame = try XCTUnwrap(last)
        let pitch = try XCTUnwrap(YinPitchDetector(minimumFrequencyHz: 27.5).detect(samples: frame.samples, sampleRate: frame.sampleRate))
        XCTAssertEqual(pitch, fundamental, accuracy: 0.15)
    }

    func testTrackerHoldsOnlyBriefDropoutsAndDoesNotBlendDifferentStrings() {
        var tracker = TunerPitchTracker()
        XCTAssertEqual(tracker.update(frequencyHz: 82.4, timestampSeconds: 0), 82.4)
        XCTAssertEqual(tracker.update(frequencyHz: nil, timestampSeconds: 0.05), 82.4)
        XCTAssertEqual(tracker.update(frequencyHz: 82.5, timestampSeconds: 0.1), 82.5)
        XCTAssertEqual(tracker.update(frequencyHz: 164.8, timestampSeconds: 0.13), 82.5, "A single octave outlier is not a new note")
        XCTAssertEqual(tracker.update(frequencyHz: 82.4, timestampSeconds: 0.16), 82.4)
        XCTAssertEqual(tracker.update(frequencyHz: 110, timestampSeconds: 0.19), 82.4)
        XCTAssertEqual(tracker.update(frequencyHz: 110.1, timestampSeconds: 0.22), 110.1, "A confirmed string change clears the old median")
        XCTAssertNil(tracker.update(frequencyHz: nil, timestampSeconds: 0.5))
        XCTAssertEqual(tracker.update(frequencyHz: 329.6, timestampSeconds: 0.6), 329.6)
        tracker.reset()
        XCTAssertNil(tracker.update(frequencyHz: nil, timestampSeconds: 0.61))
    }

    func testTrackerRejectsNonfiniteAndBackwardsTime() {
        var tracker = TunerPitchTracker()
        XCTAssertNil(tracker.update(frequencyHz: .infinity, timestampSeconds: 0))
        XCTAssertNil(tracker.update(frequencyHz: .nan, timestampSeconds: 0))
        XCTAssertEqual(tracker.update(frequencyHz: 110, timestampSeconds: 1), 110)
        XCTAssertEqual(tracker.update(frequencyHz: 220, timestampSeconds: 0.1), 220)
        XCTAssertNil(tracker.update(frequencyHz: 220, timestampSeconds: .nan))
    }

    func testGuitarLikePlucksWithDominantHarmonicsNoiseAndDCOffset() throws {
        for rate in [48_000.0, 96_000] {
            for midi in [24, 40, 45, 64] {
                let frequency = GuitarNote.frequency(forMIDI: midi)
                var accumulator = TunerFrameAccumulator()
                var last: TunerAnalysisFrame?
                var random: UInt64 = 42
                let count = Int(rate * 0.5) / 128 * 128
                for start in stride(from: 0, to: count, by: 128) {
                    let samples = (start..<(start + 128)).map { index -> Float in
                        let time = Double(index) / rate
                        let phase = 2 * Double.pi * frequency * time
                        random = random &* 6_364_136_223_846_793_005 &+ 1
                        let noise = (Double(random >> 11) / 9_007_199_254_740_992 - 0.5) * 0.006
                        let envelope = min(time / 0.01, 1) * exp(-time / 0.35)
                        return Float(0.2 + envelope * (0.05 * sin(phase) + 0.6 * sin(2 * phase) + 0.2 * sin(4 * phase)) + noise)
                    }
                    if let frame = accumulator.append(samples: samples, sampleRate: rate, timestampSeconds: Double(start) / rate) { last = frame }
                }
                let frame = try XCTUnwrap(last)
                let detected = try XCTUnwrap(YinPitchDetector(minimumFrequencyHz: 27.5).detect(samples: frame.samples, sampleRate: frame.sampleRate), "rate=\(rate), MIDI=\(midi)")
                XCTAssertLessThan(abs(1_200 * log2(detected / frequency)), 5, "A dominant second harmonic is not a different string: rate=\(rate), MIDI=\(midi)")
            }
        }
    }

    private func feed(_ accumulator: inout TunerFrameAccumulator, rate: Double, frequency: Double) -> TunerAnalysisFrame? {
        var last: TunerAnalysisFrame?
        let count = Int(rate * 0.5) / 128 * 128
        for start in stride(from: 0, to: count, by: 128) {
            if let frame = accumulator.append(samples: wave(start: start, count: 128, frequency: frequency, rate: rate), sampleRate: rate, timestampSeconds: Double(start) / rate) { last = frame }
        }
        return last
    }

    private func wave(start: Int, count: Int, frequency: Double, rate: Double) -> [Float] {
        (start..<(start + count)).map { Float(0.2 * sin(2 * .pi * frequency * Double($0) / rate)) }
    }
}
