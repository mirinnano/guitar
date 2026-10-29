import Foundation

public struct ChordSyncAnchor:
    Codable,
    Identifiable,
    Sendable,
    Equatable {

    public let chartBeat: Double
    public let videoPositionMs:
        Int64
    public let symbol: String
    public let lineIndex: Int
    public let segmentIndex: Int

    public var id: String {
        "\(chartBeat):\(lineIndex):\(segmentIndex)"
    }

    public init(
        chartBeat: Double,
        videoPositionMs: Int64,
        symbol: String,
        lineIndex: Int,
        segmentIndex: Int
    ) {
        self.chartBeat =
            chartBeat
        self.videoPositionMs =
            videoPositionMs
        self.symbol = symbol
        self.lineIndex =
            lineIndex
        self.segmentIndex =
            segmentIndex
    }
}

public enum ChordSyncPrecision:
    String,
    Sendable {

    case bpmOnly
    case offsetLocked
    case globalWarp
    case piecewiseWarp
}

public struct ChordSyncStatus:
    Sendable,
    Equatable {

    public let precision:
        ChordSyncPrecision
    public let anchorCount: Int
    public let localBPM: Double
}

public struct ChordSyncMap:
    Sendable {

    public let anchors:
        [ChordSyncAnchor]

    public let fallbackBPM: Int
    public let fallbackOffsetMs:
        Int64
    public let totalBeats: Double
    public let tempoMap: ChordTempoMap?

    public init(
        anchors:
            [ChordSyncAnchor],
        fallbackBPM: Int,
        fallbackOffsetMs:
            Int64,
        totalBeats: Double,
        tempoMap: ChordTempoMap? = nil
    ) {
        self.anchors =
            anchors
                .sorted {
                    $0.chartBeat <
                    $1.chartBeat
                }
                .reduce(
                    into:
                        [ChordSyncAnchor]()
                ) {
                    result,
                    anchor in

                    if result.last?
                        .chartBeat !=
                        anchor.chartBeat {
                        result.append(
                            anchor
                        )
                    }
                }

        self.fallbackBPM =
            fallbackBPM
        self.fallbackOffsetMs =
            fallbackOffsetMs
        self.totalBeats =
            totalBeats
        self.tempoMap = tempoMap
    }

    public var precision:
        ChordSyncPrecision {
        switch anchors.count {
        case 0:
            .bpmOnly
        case 1:
            .offsetLocked
        case 2:
            .globalWarp
        default:
            .piecewiseWarp
        }
    }

    /// Anchors closer than this cannot estimate a whole-song tempo reliably.
    /// Outside them the chart tempo continues from the nearest anchor, so a
    /// few milliseconds of tap error are not amplified across the song.
    public static let minimumWarpSpanBeats = 16.0

    public func beat(
        forVideoPositionMs:
            Int64
    ) -> Double {
        guard totalBeats > 0
        else {
            return 0
        }

        let raw: Double
        if anchors.isEmpty {
            raw = fallbackTempoMap.beat(forSeconds: Double(forVideoPositionMs - fallbackOffsetMs) / 1_000)
        } else {
            let segment = segment(forPositionMs: forVideoPositionMs)
            let nominalMs = nominalMs(forBeat: segment.origin.chartBeat)
                + Double(forVideoPositionMs - segment.origin.videoPositionMs) / segment.rate
            raw = fallbackTempoMap.beat(forSeconds: nominalMs / 1_000)
        }

        return min(
            max(raw, 0),
            totalBeats
        )
    }

    public func videoPositionMs(
        forBeat beat: Double
    ) -> Int64 {
        let target =
            min(
                max(beat, 0),
                totalBeats
            )

        let value: Double
        if anchors.isEmpty {
            value = Double(fallbackOffsetMs) + nominalMs(forBeat: target)
        } else {
            let segment = segment(forBeat: target)
            value = Double(segment.origin.videoPositionMs)
                + (nominalMs(forBeat: target) - nominalMs(forBeat: segment.origin.chartBeat)) * segment.rate
        }

        return Int64(
            max(
                value.rounded(),
                0
            )
        )
    }

    public func localBPM(
        atBeat beat: Double
    ) -> Double {
        let target = min(max(beat, 0), totalBeats)
        let nominal = fallbackTempoMap.bpm(atBeat: target)
        guard !anchors.isEmpty else { return nominal }
        return nominal / segment(forBeat: target).rate
    }

    public func status(
        atBeat beat: Double
    ) -> ChordSyncStatus {
        ChordSyncStatus(
            precision:
                precision,
            anchorCount:
                anchors.count,
            localBPM:
                localBPM(
                    atBeat: beat
                )
        )
    }

    private var fallbackTempoMap: ChordTempoMap {
        tempoMap ?? ChordTempoMap(bpm: fallbackBPM)
    }

    public static func canInsert(
        anchors:
            [ChordSyncAnchor],
        candidate:
            ChordSyncAnchor
    ) -> Bool {
        let filtered =
            anchors.filter {
                abs(
                    $0.chartBeat -
                    candidate.chartBeat
                ) >
                0.0001
            }

        let previous =
            filtered
                .filter {
                    $0.chartBeat <
                    candidate.chartBeat
                }
                .max {
                    $0.chartBeat <
                    $1.chartBeat
                }

        let next =
            filtered
                .filter {
                    $0.chartBeat >
                    candidate.chartBeat
                }
                .min {
                    $0.chartBeat <
                    $1.chartBeat
                }

        if let previous,
           candidate
            .videoPositionMs <=
            previous
                .videoPositionMs {
            return false
        }

        if let next,
           candidate
            .videoPositionMs >=
            next.videoPositionMs {
            return false
        }

        return true
    }

    public static func upsert(
        anchors:
            [ChordSyncAnchor],
        candidate:
            ChordSyncAnchor
    ) -> [ChordSyncAnchor] {
        precondition(
            canInsert(
                anchors: anchors,
                candidate:
                    candidate
            )
        )

        return (
            anchors.filter {
                abs(
                    $0.chartBeat -
                    candidate.chartBeat
                ) >
                0.0001
            } +
            [candidate]
        )
        .sorted {
            $0.chartBeat <
            $1.chartBeat
        }
    }

    private func nominalMs(forBeat beat: Double) -> Double {
        fallbackTempoMap.seconds(forBeat: max(beat, 0)) * 1_000
    }

    /// Video milliseconds per nominal chart millisecond, measured from `origin`.
    /// Between anchors the chart's own tempo changes are kept and only stretched.
    private func segment(forBeat beat: Double) -> (origin: ChordSyncAnchor, rate: Double) {
        if let upper = anchors.firstIndex(where: { $0.chartBeat > beat }), upper > 0 {
            return (anchors[upper - 1], rate(from: anchors[upper - 1], to: anchors[upper]))
        }
        return (beat < anchors[0].chartBeat ? anchors[0] : anchors[anchors.count - 1], extrapolationRate)
    }

    private func segment(forPositionMs value: Int64) -> (origin: ChordSyncAnchor, rate: Double) {
        if let upper = anchors.firstIndex(where: { $0.videoPositionMs > value }), upper > 0 {
            return (anchors[upper - 1], rate(from: anchors[upper - 1], to: anchors[upper]))
        }
        return (value < anchors[0].videoPositionMs ? anchors[0] : anchors[anchors.count - 1], extrapolationRate)
    }

    private func rate(from start: ChordSyncAnchor, to end: ChordSyncAnchor) -> Double {
        let nominal = nominalMs(forBeat: end.chartBeat) - nominalMs(forBeat: start.chartBeat)
        let video = Double(end.videoPositionMs - start.videoPositionMs)
        guard nominal > 0, video > 0 else { return 1 }
        return video / nominal
    }

    /// The whole anchored span estimates the tempo outside it; short spans keep the chart tempo.
    private var extrapolationRate: Double {
        guard let first = anchors.first, let last = anchors.last,
              last.chartBeat - first.chartBeat >= Self.minimumWarpSpanBeats else { return 1 }
        return min(max(rate(from: first, to: last), 0.5), 2)
    }
}
