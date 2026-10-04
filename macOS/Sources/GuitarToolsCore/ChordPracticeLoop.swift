import Foundation

/// A half-open practice interval, expressed in chart beats rather than video time.
public struct ChordPracticeLoop: Sendable, Equatable {
    public let startBeat: Double
    public let endBeat: Double

    public init?(startBeat: Double, endBeat: Double, totalBeats: Double) {
        guard startBeat.isFinite, endBeat.isFinite, totalBeats.isFinite,
              totalBeats > 0 else { return nil }
        let start = min(max(startBeat, 0), totalBeats)
        let end = min(max(endBeat, 0), totalBeats)
        guard end > start else { return nil }
        self.startBeat = start
        self.endBeat = end
    }

    public static func bars(
        startingAt beat: Double,
        count: Int = 4,
        timeline: ChordTimeline
    ) -> Self? {
        guard beat.isFinite, count > 0, timeline.beatsPerBar > 0,
              timeline.totalBeats > 0 else { return nil }
        let bar = Double(timeline.beatsPerBar)
        let lastBar = max(ceil(timeline.totalBeats / bar) - 1, 0)
        let start = min(max(floor(beat / bar), 0), lastBar) * bar
        return Self(
            startBeat: start,
            endBeat: start + Double(count) * bar,
            totalBeats: timeline.totalBeats
        )
    }

    public func contains(_ beat: Double) -> Bool {
        beat >= startBeat && beat < endBeat
    }

    public func wrappedBeat(_ beat: Double) -> Double {
        guard beat.isFinite, beat >= startBeat else { return startBeat }
        return startBeat + (beat - startBeat).truncatingRemainder(dividingBy: endBeat - startBeat)
    }
}
