import Foundation

public struct YinPitchDetector: Sendable {
    public var threshold: Double
    public var minimumFrequencyHz: Double
    public var maximumFrequencyHz: Double

    public init(
        threshold: Double = 0.15,
        minimumFrequencyHz: Double = 55,
        maximumFrequencyHz: Double = 1_200
    ) {
        self.threshold = threshold
        self.minimumFrequencyHz = minimumFrequencyHz
        self.maximumFrequencyHz = maximumFrequencyHz
    }

    public func detect(samples: [Float], sampleRate: Double) -> Double? {
        guard sampleRate.isFinite, sampleRate > 0,
              threshold.isFinite, threshold > 0, threshold < 1,
              minimumFrequencyHz.isFinite, minimumFrequencyHz > 0,
              maximumFrequencyHz.isFinite, maximumFrequencyHz > minimumFrequencyHz,
              samples.count >= 64, samples.allSatisfy({ $0.isFinite }) else {
            return nil
        }

        let shortestPeriod = sampleRate / maximumFrequencyHz
        let longestPeriod = sampleRate / minimumFrequencyHz
        let available = samples.count / 2
        guard shortestPeriod.isFinite, longestPeriod.isFinite,
              shortestPeriod < Double(available - 1) else { return nil }

        // Clamp in Double BEFORE converting to Int, including the interpolation halo.
        let maximumTau = Int(min(ceil(longestPeriod * 1.09) + 2, Double(available)))
        let minimumTau = max(2, Int(floor(shortestPeriod)))
        let lastCandidate = min(maximumTau - 1, Int(min(ceil(longestPeriod), Double(available))))
        guard minimumTau < lastCandidate else { return nil }

        // Every lag uses the same comparison length. N - tau biases the fallback
        // toward long periods, especially in noise. Two samples are reserved for
        // fractional-delay verification below.
        let window = samples.count - maximumTau - 2
        var difference = [Double](repeating: 0, count: maximumTau + 1)
        for tau in 1...maximumTau {
            var sum = 0.0
            for index in 0..<window {
                let delta = Double(samples[index]) - Double(samples[index + tau])
                sum += delta * delta
            }
            difference[tau] = sum
        }

        var cmnd = [Double](repeating: 1, count: maximumTau + 1)
        var runningSum = 0.0
        for tau in 1...maximumTau {
            runningSum += difference[tau]
            cmnd[tau] = runningSum > 0 ? difference[tau] * Double(tau) / runningSum : 1
        }

        // Keep the FIRST credible valley, not the global minimum. An earlier
        // fallback-quality valley must not be skipped for a noisy later cycle.
        let acceptance = max(threshold, 0.35)
        guard let first = (minimumTau...lastCandidate).first(where: { cmnd[$0] < acceptance }) else {
            return nil
        }
        let end = Int(min(Double(lastCandidate), ceil(Double(first) * 1.25)))
        guard var period = valley(in: first...end, difference: difference, cmnd: cmnd) else {
            return nil
        }
        let compensateDecay = hasDecayingEnvelope(samples)
        let depth = fractionalDepth(samples, period: period, window: window, difference: difference, compensateDecay: compensateDecay)
        guard depth <= acceptance else { return nil }

        // A weak fundamental can leave a shallow half/third-period valley. Only
        // promote an integer multiple with >10x better periodicity, and never
        // promote an already nearly exact period. Fractional-delay verification
        // avoids mistaking integer-lag quantization for a missing fundamental.
        if depth > 0.005 {
            for multiple in 2...4 {
                let expected = period * Double(multiple)
                guard expected <= Double(lastCandidate) else { break }
                let low = max(minimumTau, Int(floor(expected * 0.98)))
                let high = Int(min(Double(lastCandidate), ceil(expected * 1.02)))
                guard low <= high,
                      let alternative = valley(in: low...high, difference: difference, cmnd: cmnd),
                      abs(alternative / expected - 1) < 0.02,
                      fractionalDepth(samples, period: alternative, window: window, difference: difference, compensateDecay: compensateDecay) < depth * 0.1 else {
                    continue
                }
                period = alternative
                break
            }
        }

        let frequency = sampleRate / period
        // Small interpolation uncertainty at an inclusive range boundary is
        // clamped back into the range; a real out-of-range trough is rejected.
        let boundaryTolerance = pow(2.0, 2.0 / 1_200)
        guard frequency.isFinite, frequency > 0,
              frequency >= minimumFrequencyHz / boundaryTolerance,
              frequency <= maximumFrequencyHz * boundaryTolerance else { return nil }
        return min(max(frequency, minimumFrequencyHz), maximumFrequencyHz)
    }

    private func valley(
        in range: ClosedRange<Int>,
        difference: [Double],
        cmnd: [Double]
    ) -> Double? {
        // A short average merges noise ripples inside one valley, without
        // searching the next cycle. All averaging/fitting windows must be full.
        let smoothRadius = max(1, Int(Double(range.lowerBound) * 0.04))
        var best: Int?
        var bestValue = Double.infinity
        for index in range {
            guard index - smoothRadius >= 1, index + smoothRadius < cmnd.count else { continue }
            let value = cmnd[(index - smoothRadius)...(index + smoothRadius)].reduce(0, +) / Double(2 * smoothRadius + 1)
            if value < bestValue {
                best = index
                bestValue = value
            }
        }
        guard var center = best else { return nil }

        let radius = max(center >= 24 ? 2 : 1, Int(Double(center) * 0.075))
        var fitted: Double?
        for iteration in 0..<3 {
            guard center - radius >= 1, center + radius < difference.count,
                  let offset = quadraticOffset(difference, center: center, radius: radius),
                  abs(offset) <= Double(radius) else { return nil }
            fitted = offset
            if abs(offset) <= 0.5 { break }
            if iteration < 2 { center += Int(offset.rounded()) }
        }
        guard let fitted, abs(fitted) <= 1 else { return nil }
        var period = Double(center) + fitted

        // In a smooth/clean valley, use the three-point difference minimum for
        // precision. CMND's asymmetric normalization biases high notes. A broad
        // fit remains preferable when adjacent curvatures are dominated by noise.
        let checks = max(1, center - 2)...min(difference.count - 2, center + 2)
        let curvatures = checks.map { difference[$0 - 1] - 2 * difference[$0] + difference[$0 + 1] }
        let mean = curvatures.reduce(0, +) / Double(curvatures.count)
        let roughness = curvatures.map { abs($0 - mean) }.max() ?? .infinity
        if mean > 0, roughness < mean * 0.2 {
            let fineRadius = max(2, Int(period * 0.03))
            let low = max(1, center - fineRadius)
            let high = min(difference.count - 2, center + fineRadius)
            if let fine = (low...high).min(by: { difference[$0] < difference[$1] }),
               let offset = quadraticOffset(difference, center: fine, radius: 1), abs(offset) <= 0.5 {
                period = Double(fine) + offset
            }
        }
        return period
    }

    private func quadraticOffset(_ values: [Double], center: Int, radius: Int) -> Double? {
        var y0 = 0.0, y1 = 0.0, y2 = 0.0
        var x2 = 0.0, x4 = 0.0
        for index in -radius...radius {
            let x = Double(index), squared = x * x, y = values[center + index]
            y0 += y
            y1 += x * y
            y2 += squared * y
            x2 += squared
            x4 += squared * squared
        }
        let count = Double(2 * radius + 1)
        let a = (y2 - x2 * y0 / count) / (x4 - x2 * x2 / count)
        let b = y1 / x2
        guard a.isFinite, a > 0, b.isFinite else { return nil }
        let offset = -b / (2 * a)
        return offset.isFinite ? offset : nil
    }

    private func fractionalDepth(
        _ samples: [Float],
        period: Double,
        window: Int,
        difference: [Double],
        compensateDecay: Bool
    ) -> Double {
        guard period.isFinite, period >= 2, period < Double(difference.count - 1) else {
            return .infinity
        }
        let whole = Int(period)
        let fraction = period - Double(whole)
        let average = difference[1...whole].reduce(0, +) / Double(whole)
        guard average > 0 else { return .infinity }
        var sum = 0.0
        var sourceSum = 0.0, shiftedSum = 0.0
        var sourceSquared = 0.0, shiftedSquared = 0.0, cross = 0.0
        for index in 0..<window {
            let shifted = index + whole
            let a = Double(samples[shifted - 1]), b = Double(samples[shifted])
            let c = Double(samples[shifted + 1]), d = Double(samples[shifted + 2])
            let interpolated = b + 0.5 * fraction * (c - a + fraction * (2 * a - 5 * b + 4 * c - d + fraction * (3 * (b - c) + d - a)))
            let source = Double(samples[index])
            let delta = source - interpolated
            sum += delta * delta
            if compensateDecay {
                sourceSum += source
                shiftedSum += interpolated
                sourceSquared += source * source
                shiftedSquared += interpolated * interpolated
                cross += source * interpolated
            }
        }
        // Only a clearly decreasing envelope permits AC gain matching. Remove
        // DC before measuring power/correlation, and cap gain: this is a mild
        // decay correction, not permission to explain away arbitrary noise.
        if compensateDecay {
            let count = Double(window)
            let sourcePower = sourceSquared - sourceSum * sourceSum / count
            let shiftedPower = shiftedSquared - shiftedSum * shiftedSum / count
            let correlation = cross - sourceSum * shiftedSum / count
            if sourcePower > 0, shiftedPower > 0, correlation > 0 {
                let gain = sqrt(sourcePower / shiftedPower)
                if gain.isFinite, gain > 1.02, gain < 1.25 {
                    sum = max(0, 2 * sourcePower - 2 * gain * correlation)
                }
            }
        }
        return sum / average
    }

    private func hasDecayingEnvelope(_ samples: [Float]) -> Bool {
        // Both halves must show a meaningful drop, with monotonic quarter powers.
        // A stationary waveform's incomplete-cycle power variation alone must
        // not turn integer-lag quantization into evidence for a longer period.
        func power(_ range: Range<Int>) -> Double {
            var sum = 0.0, squared = 0.0
            for index in range {
                let value = Double(samples[index])
                sum += value
                squared += value * value
            }
            let count = Double(range.count)
            return max(0, squared / count - (sum / count) * (sum / count))
        }
        let half = samples.count / 2
        let quarter = samples.count / 4
        let first = power(0..<half), second = power(half..<samples.count)
        return second > 0 && first > second * 1.2 &&
            power(0..<quarter) > power(quarter..<half) &&
            power(half..<(half + quarter)) > power((half + quarter)..<samples.count)
    }
}

public struct TapTempoCalculator:
    Sendable {

    public var maximumTapCount: Int
    public var resetAfterSeconds:
        Double

    private var taps:
        [Double] = []

    public init(
        maximumTapCount: Int = 5,
        resetAfterSeconds:
            Double = 2
    ) {
        self.maximumTapCount =
            max(
                maximumTapCount,
                2
            )
        self.resetAfterSeconds =
            max(
                resetAfterSeconds,
                0.1
            )
    }

    public mutating func tap(
        timestampSeconds:
            Double
    ) -> Int? {
        if let previous =
            taps.last,
           (
               timestampSeconds <=
                   previous ||
               timestampSeconds -
                   previous >
                   resetAfterSeconds
           ) {
            taps.removeAll(
                keepingCapacity:
                    true
            )
        }

        taps.append(
            timestampSeconds
        )

        if taps.count >
            maximumTapCount {
            taps.removeFirst(
                taps.count -
                maximumTapCount
            )
        }

        guard taps.count >= 2
        else {
            return nil
        }

        let intervals =
            zip(
                taps,
                taps.dropFirst()
            )
            .map {
                $1 - $0
            }

        let average =
            intervals.reduce(
                0,
                +
            ) /
            Double(
                intervals.count
            )

        guard average > 0 else {
            return nil
        }

        return min(
            max(
                Int(
                    (
                        60 /
                        average
                    )
                    .rounded()
                ),
                30
            ),
            300
        )
    }

    public mutating func reset() {
        taps.removeAll(
            keepingCapacity: true
        )
    }
}
