import Foundation

public struct TunerAnalysisFrame: Sendable {
    public let samples: [Float]
    public let sampleRate: Double
    public let timestampSeconds: Double
}

/// Native HAL blocks are often only 128 samples. Build a fixed-duration pitch window,
/// low-pass before decimation, and emit at most the latest window at ~30 Hz.
public struct TunerFrameAccumulator: Sendable {
    public private(set) var revision: UInt64 = 0
    private var nativeRate = 0.0
    private var factor = 1
    private var phase = 0
    private var filters: [LowPass] = []
    private var ring = Array(repeating: Float(0), count: 2_048)
    private var writeIndex = 0
    private var filled = 0
    private var sinceAnalysis = 0
    private var expectedStart: Double?

    public init() {}

    public mutating func reset() {
        revision &+= 1
        nativeRate = 0
        phase = 0
        filters.removeAll(keepingCapacity: true)
        writeIndex = 0
        filled = 0
        sinceAnalysis = 0
        expectedStart = nil
    }

    public mutating func append(samples: [Float], sampleRate: Double, timestampSeconds: Double) -> TunerAnalysisFrame? {
        guard sampleRate.isFinite, (4_000...384_000).contains(sampleRate),
              timestampSeconds.isFinite, !samples.isEmpty, samples.allSatisfy({ $0.isFinite }) else {
            reset()
            return nil
        }
        if sampleRate != nativeRate || expectedStart.map({ abs(timestampSeconds - $0) > 0.01 }) == true {
            reset()
            nativeRate = sampleRate
            factor = max(1, Int(ceil(sampleRate / 16_000)))
            filters = [LowPass(sampleRate: sampleRate, q: 0.5411961), LowPass(sampleRate: sampleRate, q: 1.3065630)]
        }
        let end = timestampSeconds + Double(samples.count) / sampleRate
        expectedStart = end
        for sample in samples {
            var value = Double(sample)
            for index in filters.indices { value = filters[index].process(value) }
            phase += 1
            if phase == factor {
                phase = 0
                ring[writeIndex] = Float(value)
                writeIndex = (writeIndex + 1) % ring.count
                filled = min(filled + 1, ring.count)
                sinceAnalysis += 1
            }
        }
        let analysisRate = sampleRate / Double(factor)
        guard filled == ring.count, sinceAnalysis >= Int(analysisRate / 30) else { return nil }
        sinceAnalysis = 0
        let window = Array(ring[writeIndex...]) + ring[..<writeIndex]
        return TunerAnalysisFrame(samples: window, sampleRate: analysisRate, timestampSeconds: end)
    }

    private struct LowPass: Sendable {
        let b0: Double
        let b1: Double
        let b2: Double
        let a1: Double
        let a2: Double
        var z1 = 0.0
        var z2 = 0.0

        init(sampleRate: Double, q: Double) {
            let omega = 2 * Double.pi * min(1_800, sampleRate * 0.4) / sampleRate
            let cosine = cos(omega)
            let alpha = sin(omega) / (2 * q)
            let a0 = 1 + alpha
            b0 = (1 - cosine) / (2 * a0)
            b1 = (1 - cosine) / a0
            b2 = b0
            a1 = -2 * cosine / a0
            a2 = (1 - alpha) / a0
        }

        mutating func process(_ sample: Double) -> Double {
            let output = b0 * sample + z1
            z1 = b1 * sample - a1 * output + z2
            z2 = b2 * sample - a2 * output
            return output
        }
    }
}

/// Brief dropout tolerance without averaging unrelated strings or retaining a stale needle.
public struct TunerPitchTracker: Sendable {
    private var history: [Double] = []
    private var pendingJump: Double?
    private var lastValidTime: Double?
    private var lastTime: Double?
    private var value: Double?
    public let holdSeconds: Double

    public init(holdSeconds: Double = 0.15) {
        self.holdSeconds = holdSeconds.isFinite ? min(max(holdSeconds, 0), 0.5) : 0.15
    }

    public mutating func reset() {
        history.removeAll(keepingCapacity: true)
        pendingJump = nil
        lastValidTime = nil
        lastTime = nil
        value = nil
    }

    public mutating func update(frequencyHz: Double?, timestampSeconds: Double) -> Double? {
        guard timestampSeconds.isFinite else { reset(); return nil }
        if let lastTime, timestampSeconds < lastTime { reset() }
        lastTime = timestampSeconds
        guard let frequencyHz, frequencyHz.isFinite, (20...2_000).contains(frequencyHz) else {
            pendingJump = nil
            if let lastValidTime, timestampSeconds - lastValidTime <= holdSeconds { return value }
            reset()
            return nil
        }
        if let lastValidTime, timestampSeconds - lastValidTime > holdSeconds { reset() }
        if let value, abs(1_200 * log2(frequencyHz / value)) > 80 {
            if let pendingJump, abs(1_200 * log2(frequencyHz / pendingJump)) < 35 {
                history.removeAll(keepingCapacity: true)
            } else {
                pendingJump = frequencyHz
                return value
            }
        }
        pendingJump = nil
        lastValidTime = timestampSeconds
        history.append(frequencyHz)
        if history.count > 3 { history.removeFirst() }
        value = history.sorted()[history.count / 2]
        return value
    }
}
