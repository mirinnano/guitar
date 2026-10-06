import Foundation
import XCTest
@testable import GuitarToolsMacApp

final class TunerAnalysisPipelineTests: XCTestCase {
    func testInFlightAnalysisCannotPublishAfterStopOrReset() async {
        for stop in [true, false] {
            let started = expectation(description: "DSP started")
            let gate = DispatchSemaphore(value: 0)
            let recorded = TunerPipelineRecorder()
            let pipeline = TunerAnalysisPipeline { _, _ in
                started.fulfill()
                _ = gate.wait(timeout: .now() + 2)
                return 110
            }
            pipeline.start(sensitivity: 0.6) { if !$0.isReset { recorded.add($0) } }
            pipeline.ingest(samples: tone(count: 16_384), sampleRate: 48_000, timestampSeconds: 100)
            await fulfillment(of: [started], timeout: 2)
            if stop { pipeline.stop() } else { pipeline.reset() }
            gate.signal()
            try? await Task.sleep(nanoseconds: 100_000_000)
            XCTAssertTrue(recorded.results.isEmpty)
            pipeline.stop()
        }
    }

    func testAResultFromBeforePCMStalledCannotReviveTheNeedle() async {
        let started = expectation(description: "DSP started")
        let gate = DispatchSemaphore(value: 0)
        let recorded = TunerPipelineRecorder()
        let clock = PipelineTestClock()
        let pipeline = TunerAnalysisPipeline(clock: clock) { _, _ in
            started.fulfill()
            _ = gate.wait(timeout: .now() + 2)
            return 110
        }
        pipeline.start(sensitivity: 0.6) { if !$0.isReset { recorded.add($0) } }
        pipeline.ingest(samples: tone(count: 16_384), sampleRate: 48_000, timestampSeconds: 100)
        await fulfillment(of: [started], timeout: 2)
        clock.advance(by: TunerAnalysisPipeline.freshnessSeconds + 0.001)
        gate.signal()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(recorded.results.isEmpty)
        pipeline.stop()
    }

    func testBackpressureReplacesPendingWindowsRatherThanQueueingEveryFrame() async {
        let started = expectation(description: "First DSP blocked")
        let completed = expectation(description: "Only first and latest DSP completed")
        completed.expectedFulfillmentCount = 2
        let gate = DispatchSemaphore(value: 0)
        let recorded = TunerPipelineRecorder()
        let calls = TunerPipelineCounter()
        let pipeline = TunerAnalysisPipeline { _, _ in
            if calls.increment() == 1 {
                started.fulfill()
                _ = gate.wait(timeout: .now() + 2)
            }
            return 110
        }
        pipeline.start(sensitivity: 0.6) { result in
            if !result.isReset { recorded.add(result); completed.fulfill() }
        }
        pipeline.ingest(samples: tone(count: 16_384), sampleRate: 48_000, timestampSeconds: 100)
        await fulfillment(of: [started], timeout: 2)
        var start = 16_384
        for _ in 0..<20 {
            pipeline.ingest(samples: tone(count: 2_048, start: start), sampleRate: 48_000, timestampSeconds: 100 + Double(start) / 48_000)
            start += 2_048
        }
        gate.signal()
        await fulfillment(of: [completed], timeout: 2)
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(calls.value, 2)
        XCTAssertEqual(recorded.results.count, 2)
        XCTAssertEqual(recorded.results.last?.timestampSeconds ?? 0, 100 + Double(start) / 48_000, accuracy: 0.000001)
        pipeline.stop()
    }

    func testQueuedResultsBecomeInvalidOnRestart() async throws {
        let completed = expectation(description: "Result retained outside worker")
        let recorded = TunerPipelineRecorder()
        let pipeline = TunerAnalysisPipeline { _, _ in 110 }
        pipeline.start(sensitivity: 0.6) { if !$0.isReset { recorded.add($0); completed.fulfill() } }
        pipeline.ingest(samples: tone(count: 16_384), sampleRate: 48_000, timestampSeconds: 100)
        await fulfillment(of: [completed], timeout: 2)
        let result = try XCTUnwrap(recorded.results.first)
        XCTAssertTrue(pipeline.accepts(result))
        pipeline.stop()
        pipeline.start(sensitivity: 0.6) { _ in }
        XCTAssertFalse(pipeline.accepts(result), "A main-thread callback queued by the old session is obsolete")
        pipeline.stop()
    }

    func testSteadyDCAndSilenceDoNotPassTheACGate() async {
        for level: Float in [0, 0.7] {
            let completed = expectation(description: "Non-pitched frame completed")
            let pipeline = TunerAnalysisPipeline { _, _ in XCTFail("DC must not pass the amplitude gate"); return 110 }
            pipeline.start(sensitivity: 1) { result in
                if !result.isReset { XCTAssertNil(result.frequencyHz); completed.fulfill() }
            }
            pipeline.ingest(samples: Array(repeating: level, count: 32_768), sampleRate: 48_000, timestampSeconds: 100)
            await fulfillment(of: [completed], timeout: 2)
            pipeline.stop()
        }
    }

    private func tone(count: Int, start: Int = 0) -> [Float] {
        (start..<(start + count)).map { Float(0.2 * sin(2 * .pi * 110 * Double($0) / 48_000)) }
    }
}

private final class TunerPipelineRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [TunerAnalysisResult] = []
    var results: [TunerAnalysisResult] { lock.lock(); defer { lock.unlock() }; return storage }
    func add(_ result: TunerAnalysisResult) { lock.lock(); storage.append(result); lock.unlock() }
}

private final class TunerPipelineCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    func increment() -> Int { lock.lock(); defer { lock.unlock() }; count += 1; return count }
}

private final class PipelineTestClock: AudioHostClock, @unchecked Sendable {
    private let lock = NSLock()
    private var time = 100.0
    func nowSeconds() -> Double { lock.withLock { time } }
    func seconds(forHostTime hostTime: UInt64) -> Double { Double(hostTime) / 1_000_000 }
    func advance(by seconds: Double) { lock.withLock { time += seconds } }
}
