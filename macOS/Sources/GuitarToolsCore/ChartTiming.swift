import Foundation

public struct ChartTempoChange: Sendable, Equatable {
    public let lineIndex: Int
    public let bpm: Int
    public init(lineIndex: Int, bpm: Int) { self.lineIndex = lineIndex; self.bpm = bpm }
}

public struct TimedTempoChange: Sendable, Equatable {
    public let startBeat: Double
    public let bpm: Int
    public init(startBeat: Double, bpm: Int) { self.startBeat = startBeat; self.bpm = bpm }
}

public struct TimedChartLine: Sendable, Equatable {
    public let lineIndex: Int
    public let startBeat: Double
    public let durationBeats: Double
    public init(lineIndex: Int, startBeat: Double, durationBeats: Double) {
        self.lineIndex = lineIndex; self.startBeat = startBeat; self.durationBeats = durationBeats
    }
}

/// Integrates tempo changes; a user-selected opening BPM scales the whole tempo map.
public struct ChordTempoMap: Sendable {
    private let openingBPM: Double
    private let scale: Double
    private let changes: [TimedTempoChange]

    public init(bpm: Int, sourceBPM: Int? = nil, changes: [TimedTempoChange] = []) {
        openingBPM = Double(max(sourceBPM ?? bpm, 1))
        scale = Double(max(bpm, 1)) / openingBPM
        self.changes = changes.filter { $0.startBeat >= 0 && $0.startBeat.isFinite && $0.bpm > 0 }
            .sorted { $0.startBeat < $1.startBeat }
    }

    public func bpm(atBeat beat: Double) -> Double {
        (changes.last { $0.startBeat <= beat }.map { Double($0.bpm) } ?? openingBPM) * scale
    }

    public func seconds(forBeat beat: Double) -> Double {
        if beat < 0 { return beat * 60 / bpm(atBeat: 0) }
        var cursor = 0.0
        var seconds = 0.0
        var tempo = bpm(atBeat: 0)
        for change in changes where change.startBeat > 0 && change.startBeat <= beat {
            seconds += (change.startBeat - cursor) * 60 / tempo
            cursor = change.startBeat
            tempo = Double(change.bpm) * scale
        }
        return seconds + (beat - cursor) * 60 / tempo
    }

    public func beat(forSeconds seconds: Double) -> Double {
        if seconds < 0 { return seconds * bpm(atBeat: 0) / 60 }
        var cursor = 0.0
        var remaining = seconds
        var tempo = bpm(atBeat: 0)
        for change in changes where change.startBeat > 0 {
            let duration = (change.startBeat - cursor) * 60 / tempo
            if remaining < duration { return cursor + remaining * tempo / 60 }
            remaining -= duration
            cursor = change.startBeat
            tempo = Double(change.bpm) * scale
        }
        return cursor + remaining * tempo / 60
    }
}
