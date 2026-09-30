import Foundation

public struct YinPitchDetector:
    Sendable {

    public var threshold:
        Double
    public var minimumFrequencyHz:
        Double
    public var maximumFrequencyHz:
        Double

    public init(
        threshold: Double = 0.15,
        minimumFrequencyHz:
            Double = 55,
        maximumFrequencyHz:
            Double = 1_200
    ) {
        self.threshold = threshold
        self.minimumFrequencyHz =
            minimumFrequencyHz
        self.maximumFrequencyHz =
            maximumFrequencyHz
    }

    public func detect(
        samples: [Float],
        sampleRate: Double
    ) -> Double? {
        guard
            sampleRate > 0,
            samples.count >= 64
        else {
            return nil
        }

        let minimumTau =
            max(
                Int(
                    sampleRate /
                    maximumFrequencyHz
                ),
                2
            )

        let maximumTau =
            min(
                Int(
                    sampleRate /
                    minimumFrequencyHz
                ),
                samples.count / 2
            )

        guard
            maximumTau >
            minimumTau
        else {
            return nil
        }

        var difference =
            Array(
                repeating: 0.0,
                count:
                    maximumTau + 1
            )

        for tau in
            1...maximumTau {
            var sum = 0.0

            let limit =
                samples.count -
                tau

            for index in
                0..<limit {
                let delta =
                    Double(
                        samples[index] -
                        samples[
                            index + tau
                        ]
                    )

                sum +=
                    delta * delta
            }

            difference[tau] =
                sum
        }

        var cmnd =
            Array(
                repeating: 0.0,
                count:
                    maximumTau + 1
            )

        cmnd[0] = 1

        var runningSum = 0.0

        for tau in
            1...maximumTau {
            runningSum +=
                difference[tau]

            cmnd[tau] =
                runningSum == 0
                ? 1
                : difference[tau] *
                    Double(tau) /
                    runningSum
        }

        var estimate:
            Int?

        var tau =
            minimumTau

        while tau <=
            maximumTau {
            if cmnd[tau] <
                threshold {
                while
                    tau + 1 <=
                    maximumTau &&
                    cmnd[
                        tau + 1
                    ] <
                    cmnd[tau] {
                    tau += 1
                }

                estimate = tau
                break
            }

            tau += 1
        }

        if estimate == nil {
            var best =
                minimumTau

            if minimumTau + 1 <=
                maximumTau {
                for candidate in
                    (
                        minimumTau + 1
                    )...maximumTau {
                    if cmnd[candidate] <
                        cmnd[best] {
                        best =
                            candidate
                    }
                }
            }

            guard cmnd[best] <=
                0.35
            else {
                return nil
            }

            estimate = best
        }

        guard let estimate else {
            return nil
        }

        let refined =
            parabolicInterpolation(
                values: cmnd,
                index: estimate
            )

        guard refined > 0 else {
            return nil
        }

        let frequency =
            sampleRate /
            refined

        guard
            frequency >=
                minimumFrequencyHz,
            frequency <=
                maximumFrequencyHz
        else {
            return nil
        }

        return frequency
    }

    private func parabolicInterpolation(
        values: [Double],
        index: Int
    ) -> Double {
        guard
            index > 0,
            index <
                values.count - 1
        else {
            return Double(index)
        }

        let left =
            values[index - 1]

        let center =
            values[index]

        let right =
            values[index + 1]

        let denominator =
            2 *
            (
                2 * center -
                right -
                left
            )

        guard
            denominator != 0
        else {
            return Double(index)
        }

        return Double(index) +
            (
                right -
                left
            ) /
            denominator
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
