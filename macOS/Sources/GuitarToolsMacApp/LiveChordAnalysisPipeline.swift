import Foundation
import GuitarToolsCore

final class LiveChordAnalysisPipeline {

    typealias ResultHandler =
        (
            _ estimate: ChordEstimate?,
            _ stableChord: String?,
            _ levelDBFS: Double,
            _ timestampSeconds: Double
        ) -> Void

    typealias OnsetHandler =
        (_ onset: AudioOnset) -> Void

    private let queue =
        DispatchQueue(
            label:
                "dev.mirinnano.guitartools.mac.chord-analysis",
            qos: .userInitiated
        )

    private var buffer: [Float] = []
    private var detector =
        SpectralChordDetector()
    private var stabilizer =
        ChordStabilizer(
            windowSize: 4,
            votesRequired: 2
        )
    private var onsetDetector =
        EnergyOnsetDetector()

    private let frameSize = 8_192
    private let hopSize = 2_048

    var onResult: ResultHandler?
    var onOnset: OnsetHandler?

    func reset() {
        queue.async {
            self.buffer.removeAll(
                keepingCapacity: true
            )
            self.stabilizer =
                ChordStabilizer(
                    windowSize: 4,
                    votesRequired: 2
                )
            self.onsetDetector.reset()
        }
    }

    func ingest(
        samples: [Float],
        sampleRate: Double,
        bufferStartTimeSeconds: Double
    ) {
        guard
            !samples.isEmpty,
            sampleRate > 0
        else {
            return
        }

        queue.async {
            let onset =
                self.onsetDetector
                    .process(
                        samples: samples,
                        sampleRate:
                            sampleRate,
                        bufferStartTimeSeconds:
                            bufferStartTimeSeconds
                    )

            let chunk: [Float]

            if let onset {
                self.buffer.removeAll(
                    keepingCapacity: true
                )
                self.stabilizer =
                    ChordStabilizer(
                        windowSize: 4,
                        votesRequired: 2
                    )

                let offset =
                    min(
                        max(
                            onset.sampleOffset,
                            0
                        ),
                        samples.count
                    )

                chunk =
                    Array(
                        samples.dropFirst(
                            offset
                        )
                    )

                DispatchQueue.main.async {
                    self.onOnset?(onset)
                }
            } else {
                chunk = samples
            }

            self.buffer.append(
                contentsOf: chunk
            )

            if self.buffer.count >
                self.frameSize * 4 {
                self.buffer.removeFirst(
                    self.buffer.count -
                        self.frameSize * 2
                )
            }

            let analysisTimestamp =
                bufferStartTimeSeconds +
                Double(samples.count) /
                sampleRate

            while self.buffer.count >=
                self.frameSize {
                let frame =
                    Array(
                        self.buffer
                            .prefix(
                                self.frameSize
                            )
                    )

                self.buffer.removeFirst(
                    min(
                        self.hopSize,
                        self.buffer.count
                    )
                )

                let level =
                    SpectralChordDetector
                        .levelDBFS(frame)

                let estimate =
                    self.detector.analyze(
                        samples: frame,
                        sampleRate:
                            sampleRate
                    )

                let stableChord =
                    self.stabilizer
                        .update(estimate)

                DispatchQueue.main.async {
                    self.onResult?(
                        estimate,
                        stableChord,
                        level,
                        analysisTimestamp
                    )
                }
            }
        }
    }
}
