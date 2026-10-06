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

    public func beat(
        forVideoPositionMs:
            Int64
    ) -> Double {
        guard totalBeats > 0
        else {
            return 0
        }

        let raw:
            Double

        switch anchors.count {
        case 0:
            raw = fallbackTempoMap.beat(forSeconds: Double(forVideoPositionMs - fallbackOffsetMs) / 1_000)

        case 1:
            let anchor =
                anchors[0]

            raw = fallbackTempoMap.beat(forSeconds:
                fallbackTempoMap.seconds(forBeat: anchor.chartBeat)
                    + Double(forVideoPositionMs - anchor.videoPositionMs) / 1_000)

        default:
            raw =
                beatFromAnchors(
                    forVideoPositionMs
                )
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

        let value:
            Double

        switch anchors.count {
        case 0:
            value = Double(fallbackOffsetMs) + fallbackTempoMap.seconds(forBeat: target) * 1_000

        case 1:
            let anchor =
                anchors[0]

            value = Double(anchor.videoPositionMs) +
                (fallbackTempoMap.seconds(forBeat: target) - fallbackTempoMap.seconds(forBeat: anchor.chartBeat)) * 1_000

        default:
            value =
                positionFromAnchors(
                    target
                )
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
        guard anchors.count >= 2
        else {
            return fallbackTempoMap.bpm(atBeat: beat)
        }

        let pair =
            anchorPair(
                forBeat:
                    min(
                        max(
                            beat,
                            0
                        ),
                        totalBeats
                    )
            )

        let deltaBeat =
            pair.1.chartBeat -
            pair.0.chartBeat

        let deltaMs =
            pair.1
                .videoPositionMs -
            pair.0
                .videoPositionMs

        guard
            deltaBeat > 0,
            deltaMs > 0
        else {
            return Double(
                fallbackBPM
            )
        }

        return deltaBeat *
            60_000 /
            Double(deltaMs)
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

    private func beatFromAnchors(
        _ positionMs: Int64
    ) -> Double {
        let pair =
            anchorPair(
                forPositionMs:
                    positionMs
            )

        let deltaMs =
            pair.1
                .videoPositionMs -
            pair.0
                .videoPositionMs

        guard deltaMs > 0
        else {
            return pair.0
                .chartBeat
        }

        let ratio =
            Double(
                positionMs -
                pair.0
                    .videoPositionMs
            ) /
            Double(deltaMs)

        return pair.0
            .chartBeat +
            (
                pair.1
                    .chartBeat -
                pair.0
                    .chartBeat
            ) *
            ratio
    }

    private func positionFromAnchors(
        _ beat: Double
    ) -> Double {
        let pair =
            anchorPair(
                forBeat: beat
            )

        let deltaBeat =
            pair.1.chartBeat -
            pair.0.chartBeat

        guard deltaBeat > 0
        else {
            return Double(
                pair.0
                    .videoPositionMs
            )
        }

        let ratio =
            (
                beat -
                pair.0.chartBeat
            ) /
            deltaBeat

        return Double(
            pair.0
                .videoPositionMs
        ) +
        Double(
            pair.1
                .videoPositionMs -
            pair.0
                .videoPositionMs
        ) *
        ratio
    }

    private func anchorPair(
        forPositionMs value:
            Int64
    ) -> (
        ChordSyncAnchor,
        ChordSyncAnchor
    ) {
        if value <=
            anchors[0]
                .videoPositionMs {
            return (
                anchors[0],
                anchors[1]
            )
        }

        if value >=
            anchors[
                anchors.count - 1
            ]
            .videoPositionMs {
            return (
                anchors[
                    anchors.count - 2
                ],
                anchors[
                    anchors.count - 1
                ]
            )
        }

        let upper =
            anchors.firstIndex {
                $0.videoPositionMs >=
                value
            }!

        return (
            anchors[upper - 1],
            anchors[upper]
        )
    }

    private func anchorPair(
        forBeat value: Double
    ) -> (
        ChordSyncAnchor,
        ChordSyncAnchor
    ) {
        if value <=
            anchors[0]
                .chartBeat {
            return (
                anchors[0],
                anchors[1]
            )
        }

        if value >=
            anchors[
                anchors.count - 1
            ]
            .chartBeat {
            return (
                anchors[
                    anchors.count - 2
                ],
                anchors[
                    anchors.count - 1
                ]
            )
        }

        let upper =
            anchors.firstIndex {
                $0.chartBeat >=
                value
            }!

        return (
            anchors[upper - 1],
            anchors[upper]
        )
    }
}
