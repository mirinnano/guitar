import Foundation

public enum PitchClass: Int, CaseIterable, Sendable, Identifiable {
    case c = 0
    case cSharp
    case d
    case dSharp
    case e
    case f
    case fSharp
    case g
    case gSharp
    case a
    case aSharp
    case b

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .c: "C"
        case .cSharp: "C#"
        case .d: "D"
        case .dSharp: "D#"
        case .e: "E"
        case .f: "F"
        case .fSharp: "F#"
        case .g: "G"
        case .gSharp: "G#"
        case .a: "A"
        case .aSharp: "A#"
        case .b: "B"
        }
    }
}

public enum ChordQuality: String, CaseIterable, Sendable {
    case major
    case minor
    case power5
    case dominant7
    case major7
    case minor7
    case diminished
    case augmented
    case sus2
    case sus4

    public var suffix: String {
        switch self {
        case .major: ""
        case .minor: "m"
        case .power5: "5"
        case .dominant7: "7"
        case .major7: "maj7"
        case .minor7: "m7"
        case .diminished: "dim"
        case .augmented: "aug"
        case .sus2: "sus2"
        case .sus4: "sus4"
        }
    }

    fileprivate var intervals: [Int] {
        switch self {
        case .major: [0, 4, 7]
        case .minor: [0, 3, 7]
        case .power5: [0, 7]
        case .dominant7: [0, 4, 7, 10]
        case .major7: [0, 4, 7, 11]
        case .minor7: [0, 3, 7, 10]
        case .diminished: [0, 3, 6]
        case .augmented: [0, 4, 8]
        case .sus2: [0, 2, 7]
        case .sus4: [0, 5, 7]
        }
    }
}

public struct ChordEstimate: Equatable, Sendable {
    public let root: PitchClass
    public let quality: ChordQuality
    public let confidence: Double
    public let chroma: [Double]
    public let levelDBFS: Double

    public init(
        root: PitchClass,
        quality: ChordQuality,
        confidence: Double,
        chroma: [Double],
        levelDBFS: Double
    ) {
        self.root = root
        self.quality = quality
        self.confidence = confidence
        self.chroma = chroma
        self.levelDBFS = levelDBFS
    }

    public var name: String {
        root.displayName + quality.suffix
    }
}

public struct ChordDetectorConfiguration: Sendable {
    public var minimumMIDINote: Int
    public var maximumMIDINote: Int
    public var noiseGateDBFS: Double
    public var minimumConfidence: Double
    public var detuneProbeCents: Double

    public init(
        minimumMIDINote: Int = 40,
        maximumMIDINote: Int = 88,
        noiseGateDBFS: Double = -52,
        minimumConfidence: Double = 0.30,
        detuneProbeCents: Double = 16
    ) {
        self.minimumMIDINote = minimumMIDINote
        self.maximumMIDINote = maximumMIDINote
        self.noiseGateDBFS = noiseGateDBFS
        self.minimumConfidence = minimumConfidence
        self.detuneProbeCents = detuneProbeCents
    }
}

public struct SpectralChordDetector: Sendable {
    public var configuration: ChordDetectorConfiguration

    public init(
        configuration: ChordDetectorConfiguration = .init()
    ) {
        self.configuration = configuration
    }

    public func analyze(
        samples: [Float],
        sampleRate: Double
    ) -> ChordEstimate? {
        guard
            samples.count >= 1024,
            sampleRate > 0
        else {
            return nil
        }

        let levelDBFS = Self.levelDBFS(samples)
        guard levelDBFS >= configuration.noiseGateDBFS else {
            return nil
        }

        let windowed = hannWindow(samples)
        var chroma = Array(
            repeating: 0.0,
            count: PitchClass.allCases.count
        )

        for midi in configuration.minimumMIDINote...configuration.maximumMIDINote {
            let baseFrequency = Self.frequency(forMIDINote: midi)
            guard baseFrequency < sampleRate * 0.45 else {
                continue
            }

            let probes = [
                -configuration.detuneProbeCents,
                0,
                configuration.detuneProbeCents
            ]

            var strongest = 0.0

            for cents in probes {
                let frequency =
                    baseFrequency *
                    pow(2.0, cents / 1200.0)

                strongest = max(
                    strongest,
                    goertzelPower(
                        samples: windowed,
                        sampleRate: sampleRate,
                        frequency: frequency
                    )
                )
            }

            let pitchClass =
                ((midi % 12) + 12) % 12

            let frequencyWeight =
                1.0 /
                sqrt(max(baseFrequency / 82.4069, 1.0))

            chroma[pitchClass] +=
                sqrt(max(strongest, 0)) *
                frequencyWeight
        }

        let total = chroma.reduce(0, +)
        guard total > 1e-12 else {
            return nil
        }

        chroma = chroma.map { $0 / total }

        guard let result = bestTemplateMatch(chroma) else {
            return nil
        }

        let confidence = result.confidence

        guard confidence >= configuration.minimumConfidence else {
            return nil
        }

        return ChordEstimate(
            root: result.root,
            quality: result.quality,
            confidence: confidence,
            chroma: chroma,
            levelDBFS: levelDBFS
        )
    }

    public static func levelDBFS(
        _ samples: [Float]
    ) -> Double {
        guard !samples.isEmpty else {
            return -120
        }

        let sumSquares =
            samples.reduce(0.0) {
                $0 + Double($1 * $1)
            }

        let rms =
            sqrt(
                sumSquares /
                Double(samples.count)
            )

        guard rms > 1e-9 else {
            return -120
        }

        return 20.0 * log10(rms)
    }

    public static func frequency(
        forMIDINote midi: Int
    ) -> Double {
        440.0 *
            pow(
                2.0,
                Double(midi - 69) / 12.0
            )
    }

    private func hannWindow(
        _ samples: [Float]
    ) -> [Float] {
        guard samples.count > 1 else {
            return samples
        }

        let denominator =
            Double(samples.count - 1)

        return samples
            .enumerated()
            .map { index, sample in
                let coefficient =
                    0.5 -
                    0.5 *
                    cos(
                        2.0 *
                        Double.pi *
                        Double(index) /
                        denominator
                    )

                return sample *
                    Float(coefficient)
            }
    }

    private func goertzelPower(
        samples: [Float],
        sampleRate: Double,
        frequency: Double
    ) -> Double {
        let omega =
            2.0 *
            Double.pi *
            frequency /
            sampleRate

        let coefficient =
            2.0 * cos(omega)

        var previous = 0.0
        var previous2 = 0.0

        for sample in samples {
            let current =
                Double(sample) +
                coefficient *
                previous -
                previous2

            previous2 = previous
            previous = current
        }

        return max(
            previous2 * previous2 +
                previous * previous -
                coefficient *
                previous *
                previous2,
            0
        )
    }

    private func bestTemplateMatch(
        _ chroma: [Double]
    ) -> (
        root: PitchClass,
        quality: ChordQuality,
        confidence: Double
    )? {
        let peak =
            chroma.max() ?? 0

        guard peak > 0 else {
            return nil
        }

        struct Candidate {
            let root: PitchClass
            let quality: ChordQuality
            let score: Double
        }

        var candidates: [Candidate] = []

        for root in PitchClass.allCases {
            for quality in ChordQuality.allCases {
                let indices =
                    quality.intervals.map {
                        (root.rawValue + $0) % 12
                    }

                let inside =
                    indices.reduce(0.0) {
                        $0 + chroma[$1]
                    }

                let outside =
                    max(1.0 - inside, 0)

                let completeness =
                    indices
                        .map {
                            min(
                                chroma[$0] /
                                    peak,
                                1.0
                            )
                        }
                        .reduce(0, +) /
                    Double(indices.count)

                let rootPresence =
                    min(
                        chroma[root.rawValue] /
                            peak,
                        1.0
                    )

                let sizePenalty =
                    max(
                        Double(indices.count - 3),
                        0
                    ) * 0.025

                let score =
                    inside * 0.72 +
                    completeness * 0.24 +
                    rootPresence * 0.10 -
                    outside * 0.55 -
                    sizePenalty

                candidates.append(
                    Candidate(
                        root: root,
                        quality: quality,
                        score: score
                    )
                )
            }
        }

        let sorted =
            candidates.sorted {
                $0.score > $1.score
            }

        guard let best = sorted.first else {
            return nil
        }

        let second =
            sorted.dropFirst().first?.score
                ?? best.score

        let margin =
            max(best.score - second, 0)

        let confidence =
            min(
                max(
                    0.50 * best.score +
                    2.2 * margin,
                    0
                ),
                1
            )

        return (
            root: best.root,
            quality: best.quality,
            confidence: confidence
        )
    }
}

public struct ChordStabilizer: Sendable {
    private var history: [String] = []
    private var stableName: String?

    public var windowSize: Int
    public var votesRequired: Int

    public init(
        windowSize: Int = 5,
        votesRequired: Int = 3
    ) {
        self.windowSize = max(windowSize, 1)
        self.votesRequired =
            min(
                max(votesRequired, 1),
                self.windowSize
            )
    }

    public mutating func update(
        _ estimate: ChordEstimate?
    ) -> String? {
        guard let estimate else {
            history.removeAll(
                keepingCapacity: true
            )
            stableName = nil
            return nil
        }

        history.append(estimate.name)

        if history.count > windowSize {
            history.removeFirst(
                history.count - windowSize
            )
        }

        let grouped =
            Dictionary(
                grouping: history,
                by: { $0 }
            )
            .mapValues(\.count)

        if let winner =
            grouped.max(
                by: {
                    $0.value < $1.value
                }
            ),
            winner.value >= votesRequired {
            stableName = winner.key
        }

        return stableName
    }
}
