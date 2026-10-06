import Foundation
import GuitarToolsCore

struct TunerAnalysisResult: Sendable {
    let generation: UUID
    let frequencyHz: Double?
    let timestampSeconds: Double
    let isReset: Bool
}

/// Only one analysis and one replaceable latest window may be outstanding.
/// PCM accumulation stays off the main thread; obsolete work cannot publish after reset/stop.
final class TunerAnalysisPipeline: @unchecked Sendable {
    static let freshnessSeconds = 0.4

    private struct Work {
        let frame: TunerAnalysisFrame
        let sensitivity: Double
        let generation: UUID
    }

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "dev.mirinnano.guitartools.mac.tuner", qos: .userInitiated)
    private let detectPitch: @Sendable ([Float], Double) -> Double?
    private var accumulator = TunerFrameAccumulator()
    private var generation = UUID()
    private var active = false
    private var sensitivity = 0.6
    private var pending: Work?
    private var working = false
    private var lastPCMReceivedAt: Double?
    private var onResult: (@Sendable (TunerAnalysisResult) -> Void)?

    init(detectPitch: @escaping @Sendable ([Float], Double) -> Double? = { samples, rate in
        YinPitchDetector(minimumFrequencyHz: 27.5).detect(samples: samples, sampleRate: rate)
    }) {
        self.detectPitch = detectPitch
    }

    func start(sensitivity: Double, onResult: @escaping @Sendable (TunerAnalysisResult) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        resetLocked()
        active = true
        self.sensitivity = sensitivity
        self.onResult = onResult
    }

    func setSensitivity(_ value: Double) {
        lock.lock()
        sensitivity = value
        lock.unlock()
    }

    func reset() {
        lock.lock()
        resetLocked()
        lock.unlock()
    }

    func stop() {
        lock.lock()
        resetLocked()
        active = false
        onResult = nil
        lock.unlock()
    }

    func accepts(_ result: TunerAnalysisResult) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return active && generation == result.generation && (result.isReset || hasFreshPCMLocked())
    }

    func ingest(samples: [Float], sampleRate: Double, timestampSeconds: Double) {
        lock.lock()
        guard active else { lock.unlock(); return }
        lastPCMReceivedAt = ProcessInfo.processInfo.systemUptime
        let previousRevision = accumulator.revision
        let frame = accumulator.append(samples: samples, sampleRate: sampleRate, timestampSeconds: timestampSeconds)
        var resetResult: TunerAnalysisResult?
        if previousRevision != accumulator.revision {
            generation = UUID()
            pending = nil
            resetResult = TunerAnalysisResult(generation: generation, frequencyHz: nil, timestampSeconds: timestampSeconds, isReset: true)
        }
        var schedule = false
        if let frame {
            pending = Work(frame: frame, sensitivity: sensitivity, generation: generation)
            if !working { working = true; schedule = true }
        }
        let callback = onResult
        lock.unlock()
        if let resetResult { callback?(resetResult) }
        if schedule { queue.async { self.drain() } }
    }

    private func resetLocked() {
        generation = UUID()
        accumulator.reset()
        pending = nil
        lastPCMReceivedAt = nil
    }

    private func hasFreshPCMLocked() -> Bool {
        lastPCMReceivedAt.map { ProcessInfo.processInfo.systemUptime - $0 <= Self.freshnessSeconds } ?? false
    }

    private func drain() {
        while true {
            lock.lock()
            guard let work = pending else { working = false; lock.unlock(); return }
            pending = nil
            let current = active && work.generation == generation && hasFreshPCMLocked()
            lock.unlock()
            guard current else { continue }

            // AC level, not DC offset. Sensitivity is a detection gate, not input gain.
            let samples = work.frame.samples
            let mean = samples.reduce(0.0) { $0 + Double($1) } / Double(samples.count)
            let power = samples.reduce(0.0) { total, sample in
                let delta = Double(sample) - mean
                return total + delta * delta
            } / Double(samples.count)
            let sensitivity = work.sensitivity.isFinite ? min(max(work.sensitivity, 0), 1) : 0.6
            let minimumRMS = pow(10, (-35 - sensitivity * 25) / 20)
            let frequency = sqrt(power) >= minimumRMS ? detectPitch(samples, work.frame.sampleRate) : nil

            lock.lock()
            let callback = active && work.generation == generation && hasFreshPCMLocked() ? onResult : nil
            lock.unlock()
            callback?(TunerAnalysisResult(generation: work.generation, frequencyHz: frequency, timestampSeconds: work.frame.timestampSeconds, isReset: false))
        }
    }
}
