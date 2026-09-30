import Foundation

public struct AudioOnset:
    Sendable,
    Equatable {

    public let timestampSeconds:
        Double
    public let sampleOffset: Int
    public let levelDBFS: Double
    public let riseDB: Double

    public init(
        timestampSeconds: Double,
        sampleOffset: Int,
        levelDBFS: Double,
        riseDB: Double
    ) {
        self.timestampSeconds =
            timestampSeconds
        self.sampleOffset =
            sampleOffset
        self.levelDBFS =
            levelDBFS
        self.riseDB =
            riseDB
    }
}

public struct EnergyOnsetDetector:
    Sendable {

    public var minimumLevelDBFS:
        Double
    public var minimumRiseDB:
        Double
    public var refractorySeconds:
        Double
    public var windowSize: Int

    private var previousLevelDBFS =
        -120.0
    private var refractoryUntil =
        -Double.infinity

    public init(
        minimumLevelDBFS:
            Double = -42,
        minimumRiseDB:
            Double = 7,
        refractorySeconds:
            Double = 0.11,
        windowSize:
            Int = 128
    ) {
        self.minimumLevelDBFS =
            minimumLevelDBFS
        self.minimumRiseDB =
            minimumRiseDB
        self.refractorySeconds =
            refractorySeconds
        self.windowSize =
            max(windowSize, 32)
    }

    public mutating func reset() {
        previousLevelDBFS = -120
        refractoryUntil =
            -Double.infinity
    }

    public mutating func process(
        samples: [Float],
        sampleRate: Double,
        bufferStartTimeSeconds:
            Double
    ) -> AudioOnset? {
        guard
            sampleRate > 0,
            !samples.isEmpty
        else {
            return nil
        }

        var offset = 0
        var detected:
            AudioOnset?

        while offset < samples.count {
            let end =
                min(
                    offset +
                        windowSize,
                    samples.count
                )

            let window =
                samples[offset..<end]

            let level =
                levelDBFS(window)

            let rise =
                level -
                previousLevelDBFS

            let center =
                offset +
                (end - offset) / 2

            let timestamp =
                bufferStartTimeSeconds +
                Double(center) /
                sampleRate

            if detected == nil,
               timestamp >=
                refractoryUntil,
               level >=
                minimumLevelDBFS,
               rise >=
                minimumRiseDB {
                detected =
                    AudioOnset(
                        timestampSeconds:
                            timestamp,
                        sampleOffset:
                            offset,
                        levelDBFS:
                            level,
                        riseDB:
                            rise
                    )

                refractoryUntil =
                    timestamp +
                    refractorySeconds
            }

            previousLevelDBFS =
                level
            offset = end
        }

        return detected
    }

    private func levelDBFS<
        Samples:
            Collection<Float>
    >(
        _ samples: Samples
    ) -> Double {
        guard !samples.isEmpty else {
            return -120
        }

        let sum =
            samples.reduce(
                0.0
            ) {
                result,
                sample in

                result +
                    Double(
                        sample * sample
                    )
            }

        let rms =
            sqrt(
                sum /
                Double(samples.count)
            )

        guard rms > 1e-9 else {
            return -120
        }

        return 20 *
            log10(rms)
    }
}
