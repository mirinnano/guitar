import Foundation

public struct ChordFingerPosition: Sendable, Equatable {
    /// Standard guitar numbering: 1 is the high E string, 6 is the low E string.
    public let stringNumber: Int
    public let fret: Int

    public init(stringNumber: Int, fret: Int) {
        self.stringNumber = stringNumber
        self.fret = fret
    }
}

public struct ChordFingerAnchor: Sendable, Equatable {
    public let finger: Int
    /// The finger's complete fretted-note footprint, ordered by string number.
    public let positions: [ChordFingerPosition]

    public init(finger: Int, positions: [ChordFingerPosition]) {
        self.finger = finger
        self.positions = positions
    }
}

public struct SongChordTransition: Identifiable, Sendable, Equatable {
    /// Directional verified geometry, independent of source spelling and Swift's randomized hashing.
    public let id: String
    public let fromSymbol: String
    public let toSymbol: String
    public let fromShape: GuitarChordShape
    public let toShape: GuitarChordShape
    /// Starts of the from-events, in source order. Plans only emit nonempty occurrences.
    public let occurrenceBeats: [Double]
    /// End of the to-event at the first occurrence (not the last recurrence).
    public let endBeat: Double
    /// A geometric practice heuristic, not a measured or clinical difficulty rating.
    public let difficultyScore: Int
    public let fixedFingers: [ChordFingerAnchor]
    public let movingFingerCount: Int
}

/// Pure analysis of the chart's concert-pitch timeline using verified no-capo voicings only.
public struct SongTransitionPlan: Sendable, Equatable {
    public let transitions: [SongChordTransition]
    /// Unique written unavailable symbols in timeline order, followed by any remaining
    /// unsafe conversion originals retained by the chart. NC is a barrier, not an error.
    public let unavailableSymbols: [String]

    /// Selections are a snapshot keyed by GuitarChordData.selectionKey(for:).
    /// Invalid or stale IDs retain the verified default fingering.
    public init(chart: ChordChart, voicingSelections: [String: String] = [:]) {
        let timeline = ChordTimelineBuilder.build(chart: chart)
        var unavailable: [String] = []
        var seenUnavailable: Set<String> = []
        var candidates: [Candidate] = []
        var indexByID: [String: Int] = [:]
        var previous: (event: TimedChordEvent, shape: GuitarChordShape)?

        func recordUnavailable(_ symbol: String) {
            if seenUnavailable.insert(symbol).inserted { unavailable.append(symbol) }
        }

        for event in timeline.events {
            let voicingID = GuitarChordData.selectionKey(for: event.symbol)
                .flatMap { voicingSelections[$0] }
            let presentation = ChordFingeringPresentation(symbol: event.symbol, voicingID: voicingID)
            let sourceSegment = chart.lines[event.lineIndex].segments[event.segmentIndex]
            // A custom chart can carry a timing original different from its displayed
            // chord. Do not treat that inconsistent slot as a verified concert chord.
            guard event.isPlayable, sourceSegment.chord == event.symbol,
                  presentation.availability == .supported, let shape = presentation.shape else {
                if presentation.availability != .noChord { recordUnavailable(event.symbol) }
                // Never skip an unsafe slot and accidentally connect its neighbours.
                previous = nil
                continue
            }
            guard event.startBeat.isFinite, event.durationBeats.isFinite,
                  event.durationBeats > 0 else {
                previous = nil
                continue
            }
            if let from = previous, from.shape.frets != shape.frets {
                let id = Self.geometryID(from.shape) + "->" + Self.geometryID(shape)
                if let index = indexByID[id] {
                    candidates[index].occurrenceBeats.append(from.event.startBeat)
                } else {
                    let anchors = Self.anchors(from: from.shape, to: shape)
                    let used = Set(Self.footprints(from.shape).keys)
                        .union(Self.footprints(shape).keys)
                    let moving = max(0, used.count - anchors.count)
                    indexByID[id] = candidates.count
                    candidates.append(Candidate(
                        id: id, fromSymbol: from.event.symbol, toSymbol: event.symbol,
                        fromShape: from.shape, toShape: shape,
                        occurrenceBeats: [from.event.startBeat],
                        endBeat: event.startBeat + event.durationBeats,
                        difficultyScore: Self.difficulty(from: from.shape, to: shape, moving: moving),
                        fixedFingers: anchors, movingFingerCount: moving
                    ))
                }
            }
            // Repeated chords still update the from-event to the immediately preceding slot.
            previous = (event, shape)
        }
        for symbol in chart.unconvertedChordSymbols {
            if ChordFingeringPresentation(symbol: symbol).availability != .noChord {
                recordUnavailable(symbol)
            }
        }

        // Each additional occurrence adds six priority points. Ties favour geometry
        // difficulty, then recurrence, then earliest occurrence, then stable ID.
        candidates.sort {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            if $0.difficultyScore != $1.difficultyScore { return $0.difficultyScore > $1.difficultyScore }
            if $0.occurrenceBeats.count != $1.occurrenceBeats.count {
                return $0.occurrenceBeats.count > $1.occurrenceBeats.count
            }
            if $0.occurrenceBeats[0] != $1.occurrenceBeats[0] {
                return $0.occurrenceBeats[0] < $1.occurrenceBeats[0]
            }
            return $0.id < $1.id
        }
        transitions = candidates.map { $0.transition }
        unavailableSymbols = unavailable
    }

    private struct Candidate {
        let id: String
        let fromSymbol: String
        let toSymbol: String
        let fromShape: GuitarChordShape
        let toShape: GuitarChordShape
        var occurrenceBeats: [Double]
        let endBeat: Double
        let difficultyScore: Int
        let fixedFingers: [ChordFingerAnchor]
        let movingFingerCount: Int

        var priority: Int { difficultyScore + 6 * (occurrenceBeats.count - 1) }
        var transition: SongChordTransition {
            SongChordTransition(
                id: id, fromSymbol: fromSymbol, toSymbol: toSymbol,
                fromShape: fromShape, toShape: toShape, occurrenceBeats: occurrenceBeats,
                endBeat: endBeat, difficultyScore: difficultyScore,
                fixedFingers: fixedFingers, movingFingerCount: movingFingerCount
            )
        }
    }

    private static func footprints(_ shape: GuitarChordShape) -> [Int: [ChordFingerPosition]] {
        var result: [Int: [ChordFingerPosition]] = [:]
        for (index, fret) in shape.frets.enumerated() where fret > 0 {
            if let finger = shape.fingers[index] {
                result[finger, default: []].append(ChordFingerPosition(stringNumber: 6 - index, fret: fret))
            }
        }
        for finger in Array(result.keys) {
            result[finger]?.sort { $0.stringNumber < $1.stringNumber }
        }
        return result
    }

    private static func sortedBarres(_ shape: GuitarChordShape) -> [GuitarBarre] {
        shape.barres.sorted {
            if $0.finger != $1.finger { return $0.finger < $1.finger }
            if $0.fret != $1.fret { return $0.fret < $1.fret }
            if $0.fromString != $1.fromString { return $0.fromString < $1.fromString }
            return $0.toString < $1.toString
        }
    }

    private static func anchors(from: GuitarChordShape, to: GuitarChordShape) -> [ChordFingerAnchor] {
        let fromNotes = footprints(from)
        let toNotes = footprints(to)
        let fromBarres = sortedBarres(from)
        let toBarres = sortedBarres(to)
        return fromNotes.keys.sorted().compactMap { finger in
            guard let positions = fromNotes[finger], positions == toNotes[finger],
                  fromBarres.filter({ $0.finger == finger }) == toBarres.filter({ $0.finger == finger })
            else { return nil }
            return ChordFingerAnchor(finger: finger, positions: positions)
        }
    }

    private static func geometryID(_ shape: GuitarChordShape) -> String {
        let frets = shape.frets.map(String.init).joined(separator: ",")
        let fingers = shape.fingers.map { $0.map(String.init) ?? "_" }.joined(separator: ",")
        let barres = sortedBarres(shape).map {
            "\($0.finger):\($0.fret):\($0.fromString):\($0.toString)"
        }.joined(separator: ",")
        // Frets encode actual sounding bass as well as upper voices; root/name alone cannot.
        return "f[\(frets)]i[\(fingers)]b[\(barres)]"
    }

    private static func difficulty(from: GuitarChordShape, to: GuitarChordShape, moving: Int) -> Int {
        let changedStrings = zip(from.frets, to.frets).filter { $0 != $1 }.count
        let changedBarres = Set(from.barres).symmetricDifference(Set(to.barres)).count
        // Ten per moving finger ID, two per changed string, one per display-position
        // fret shift, and four per added/removed/changed barre descriptor.
        return moving * 10 + changedStrings * 2 + abs(from.baseFret - to.baseFret) + changedBarres * 4
    }
}
