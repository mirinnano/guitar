import Foundation
import GuitarToolsCore

final class LiveChordAnalysisPipeline {

    typealias ResultHandler =
        (
            _ estimate: ChordEstimate?,
            _ stableChord: String?,
            _ levelDBFS: Double
        ) -> Void

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
            windowSize: 5,
            votesRequired: 3
        )

    private let frameSize = 4_096
    private let hopSize = 2_048

    var onResult: ResultHandler?

    func reset() {
        queue.async {
            self.buffer.removeAll(
                keepingCapacity: true
            )
            self.stabilizer =
                ChordStabilizer(
                    windowSize: 5,
                    votesRequired: 3
                )
        }
    }

    func ingest(
        samples: [Float],
        sampleRate: Double
    ) {
        guard !samples.isEmpty else {
            return
        }

        queue.async {
            self.buffer.append(
                contentsOf: samples
            )

            if self.buffer.count >
                self.frameSize * 4 {
                self.buffer.removeFirst(
                    self.buffer.count -
                        self.frameSize * 2
                )
            }

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
                        sampleRate: sampleRate
                    )

                let stableChord =
                    self.stabilizer.update(
                        estimate
                    )

                DispatchQueue.main.async {
                    self.onResult?(
                        estimate,
                        stableChord,
                        level
                    )
                }
            }
        }
    }
}
