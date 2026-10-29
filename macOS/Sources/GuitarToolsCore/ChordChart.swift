import Foundation

public enum ChartLineKind: Sendable, Equatable {
    case content
    case comment
    case blank
}

public struct ChartSegment: Sendable, Equatable {
    public let chord: String?
    public let text: String
    /// Keeps a timing slot when a source chord cannot safely be played in concert pitch.
    public let timingChord: String?

    public init(
        chord: String? = nil,
        text: String,
        timingChord: String? = nil
    ) {
        self.chord = chord
        self.text = text
        self.timingChord = timingChord ?? chord
    }
}

public struct ChartLine: Sendable, Equatable {
    public let segments: [ChartSegment]
    public let kind: ChartLineKind

    public init(
        segments: [ChartSegment] = [],
        kind: ChartLineKind = .content
    ) {
        self.segments = segments
        self.kind = kind
    }
}

public struct ChordChart: Sendable, Equatable {
    public let sourceTitle: String
    public let title: String
    public let artist: String
    public let key: String?
    public let bpm: Int?
    public let beatsPerBar: Int
    public let beatUnit: Int
    public let lines: [ChartLine]
    public let sourceURL: URL?
    public let youtubeVideoID: String?
    /// The source chart's explicit capo directive. Displayed chords are concert pitch.
    public let sourceCapo: Int
    public let sourceKey: String?
    public let capoDirectiveWarning: String?
    /// Symbols that could not safely be converted; these are retained as text, not diagrams.
    public let unconvertedChordSymbols: [String]
    public let tempoChanges: [ChartTempoChange]

    public init(
        sourceTitle: String,
        title: String,
        artist: String = "",
        key: String? = nil,
        bpm: Int? = nil,
        beatsPerBar: Int = 4,
        beatUnit: Int = 4,
        lines: [ChartLine],
        sourceURL: URL? = nil,
        youtubeVideoID: String? = nil,
        sourceCapo: Int = 0,
        sourceKey: String? = nil,
        capoDirectiveWarning: String? = nil,
        unconvertedChordSymbols: [String] = [],
        tempoChanges: [ChartTempoChange] = []
    ) {
        self.sourceTitle = sourceTitle
        self.title = title
        self.artist = artist
        self.key = key
        self.bpm = bpm
        self.beatsPerBar = beatsPerBar
        self.beatUnit = beatUnit
        self.lines = lines
        self.sourceURL = sourceURL
        self.youtubeVideoID = youtubeVideoID
        self.sourceCapo = sourceCapo
        self.sourceKey = sourceKey
        self.capoDirectiveWarning = capoDirectiveWarning
        self.unconvertedChordSymbols = unconvertedChordSymbols
        self.tempoChanges = tempoChanges
    }
}

public struct TimedChordEvent:
    Sendable,
    Equatable,
    Identifiable {

    public let id: Int
    public let symbol: String
    public let lineIndex: Int
    public let segmentIndex: Int
    public let startBeat: Double
    public let durationBeats: Double
    public let isPlayable: Bool

    public init(
        id: Int,
        symbol: String,
        lineIndex: Int,
        segmentIndex: Int,
        startBeat: Double,
        durationBeats: Double,
        isPlayable: Bool = true
    ) {
        self.id = id
        self.symbol = symbol
        self.lineIndex = lineIndex
        self.segmentIndex = segmentIndex
        self.startBeat = startBeat
        self.durationBeats = durationBeats
        self.isPlayable = isPlayable
    }
}

public struct ChordTimeline: Sendable, Equatable {
    public let beatsPerBar: Int
    public let totalBeats: Double
    public let events: [TimedChordEvent]
    public let lineTimings: [TimedChartLine]
    public let tempoChanges: [TimedTempoChange]
    public let sourceBPM: Int?

    public init(
        beatsPerBar: Int,
        totalBeats: Double,
        events: [TimedChordEvent],
        lineTimings: [TimedChartLine] = [],
        tempoChanges: [TimedTempoChange] = [],
        sourceBPM: Int? = nil
    ) {
        self.beatsPerBar = beatsPerBar
        self.totalBeats = totalBeats
        self.events = events
        self.lineTimings = lineTimings
        self.tempoChanges = tempoChanges
        self.sourceBPM = sourceBPM
    }

    public func seconds(
        forBeat beat: Double,
        bpm: Int
    ) -> Double {
        guard bpm > 0 else {
            return 0
        }

        return tempoMap(bpm: bpm).seconds(forBeat: max(beat, 0))
    }

    public func beat(
        forSeconds seconds: Double,
        bpm: Int
    ) -> Double {
        guard bpm > 0 else {
            return 0
        }

        return min(max(tempoMap(bpm: bpm).beat(forSeconds: seconds), 0), totalBeats)
    }

    public func tempoMap(bpm: Int) -> ChordTempoMap {
        ChordTempoMap(bpm: bpm, sourceBPM: sourceBPM, changes: tempoChanges)
    }

    public func line(atBeat beat: Double) -> TimedChartLine? {
        if beat >= totalBeats { return lineTimings.last }
        return lineTimings.last { beat >= $0.startBeat && beat < $0.startBeat + $0.durationBeats }
    }

    public func event(
        atBeat beat: Double
    ) -> TimedChordEvent? {
        events.last {
            beat >= $0.startBeat &&
            beat < $0.startBeat +
                $0.durationBeats
        }
    }

    public func milliseconds(
        forBeat beat: Double,
        bpm: Int
    ) -> Int64 {
        Int64(
            (
                seconds(
                    forBeat: beat,
                    bpm: bpm
                ) *
                1_000
            ).rounded()
        )
    }

    public func beat(
        forMilliseconds value: Int64,
        bpm: Int
    ) -> Double {
        beat(
            forSeconds:
                Double(
                    max(
                        value,
                        0
                    )
                ) /
                1_000,
            bpm: bpm
        )
    }

    public func barNumber(
        atBeat beat: Double
    ) -> Int {
        guard beatsPerBar > 0
        else {
            return 1
        }

        return Int(
            floor(
                max(beat, 0) /
                Double(
                    beatsPerBar
                )
            )
        ) + 1
    }
}

public enum ChordChartParser {

    private static let directive =
        try! NSRegularExpression(
            pattern:
                #"^\{([^}:]+)(?::(.*))?\}$"#
        )

    private static let commentTempo = try! NSRegularExpression(
        pattern: #"\bBPM\s*[=:：]\s*(\d+)"#,
        options: [.caseInsensitive]
    )

    private static let bracket =
        try! NSRegularExpression(
            pattern:
                #"\[([^\]]+)\]"#
        )

    /// Rhythm and bar marks some editors put in brackets: `[|]`, `[-- --]`, `[↓]`.
    private static let rhythmBracket = try! NSRegularExpression(pattern: #"\[([\s\-|｜│↓↑>＞]+)\]"#)

    private static let chordToken =
        try! NSRegularExpression(
            pattern:
                #"^[A-Ga-g](?:#|b|♯|♭)?[A-Za-z0-9#b♯♭()+,\-△Δ°ø]*(?:/9)?(?:/[A-Ga-g](?:#|b|♯|♭)?)?$"#
        )

    public static func parse(
        _ source: String,
        fallbackTitle: String,
        sourceURL: URL? = nil,
        linkedMediaHTML: String? = nil
    ) -> ChordChart {
        var title = fallbackTitle
        var artist = ""
        var key: String?
        var sourceCapo = 0
        var capoDirectiveWarning: String?
        var bpm: Int?
        var hasExplicitTempo = false
        var tempoChanges: [ChartTempoChange] = []
        var beatsPerBar = 4
        var beatUnit = 4
        var lines: [ChartLine] = []
        var previousChord: String?

        source
            .replacingOccurrences(
                of: "\r\n",
                with: "\n"
            )
            .replacingOccurrences(
                of: "\r",
                with: "\n"
            )
            .split(
                separator: "\n",
                omittingEmptySubsequences:
                    false
            )
            .map(String.init)
            .forEach { rawLine in
                let trimmed =
                    rawLine.trimmingCharacters(
                        in: .whitespaces
                    )

                if trimmed.hasPrefix("#") {
                    return
                }

                if let directiveValue =
                    parseDirective(trimmed) {
                    let name =
                        directiveValue.name
                            .lowercased()

                    let value =
                        directiveValue.value

                    switch name {
                    case "title", "t":
                        if !value.isEmpty {
                            title = value
                        }

                    case "artist",
                        "subtitle",
                        "st":
                        if !value.isEmpty {
                            artist = value
                        }

                    case "key":
                        key =
                            value.isEmpty
                            ? nil
                            : value

                    case "capo":
                        if let number = Int(value), (0...12).contains(number) {
                            sourceCapo = number
                            capoDirectiveWarning = nil
                        } else {
                            capoDirectiveWarning = "カポ指定「\(value)」を解釈できないため、コード図を表示しません。"
                        }

                    case "tempo", "bpm":
                        if let number =
                            Int(value),
                           (20...400)
                            .contains(number) {
                            if !hasExplicitTempo {
                                bpm = number
                                hasExplicitTempo = true
                            } else if lines.contains(where: { $0.kind == .content }) {
                                tempoChanges.append(ChartTempoChange(lineIndex: lines.count, bpm: number))
                            } else {
                                bpm = number
                            }
                        }

                    case "time",
                        "meter",
                        "time_signature":
                        if let meter =
                            parseMeter(value) {
                            beatsPerBar =
                                meter.0
                            beatUnit =
                                meter.1
                        }

                    case "comment",
                        "c",
                        "comment_italic",
                        "ci":
                        let nsValue = value as NSString
                        if bpm == nil,
                           let match = commentTempo.firstMatch(
                               in: value,
                               range: NSRange(location: 0, length: nsValue.length)
                           ),
                           let number = Int(nsValue.substring(with: match.range(at: 1))),
                           (20...400).contains(number) {
                            bpm = number
                        }
                        if !value.isEmpty {
                            lines.append(
                                ChartLine(
                                    segments: [
                                        ChartSegment(
                                            text: value
                                        )
                                    ],
                                    kind: .comment
                                )
                            )
                        }

                    default:
                        break
                    }

                    return
                }

                if trimmed.isEmpty {
                    lines.append(
                        ChartLine(
                            kind: .blank
                        )
                    )
                    return
                }

                // `<検索用> …` holds search keywords, not music.
                if trimmed.hasPrefix("※") || (trimmed.hasPrefix("<") && trimmed.contains(">") && !trimmed.contains("[")) {
                    lines.append(ChartLine(segments: [ChartSegment(text: rawLine)], kind: .comment))
                } else {
                    lines.append(parseContentLine(rawLine, previousChord: &previousChord))
                }
            }

        var removedLeadingLines = 0
        while lines.first?.kind == .blank {
            lines.removeFirst()
            removedLeadingLines += 1
        }

        while lines.last?.kind == .blank {
            lines.removeLast()
        }

        let sourceKey = key
        var unconverted: [String] = []
        if sourceCapo > 0 || capoDirectiveWarning != nil {
            key = capoDirectiveWarning == nil
                ? key.flatMap { ChordSymbolTransposition.transpose($0, semitones: sourceCapo) } : nil
            lines = lines.map { line in
                ChartLine(segments: line.segments.map { segment in
                    guard let symbol = segment.chord,
                          !["NC", "N.C.", "<"].contains(symbol.uppercased()) else { return segment }
                    if capoDirectiveWarning == nil,
                       let transposed = ChordSymbolTransposition.transpose(symbol, semitones: sourceCapo) {
                        return ChartSegment(chord: transposed, text: segment.text)
                    }
                    if !unconverted.contains(symbol) { unconverted.append(symbol) }
                    return ChartSegment(text: "[\(symbol)]" + segment.text, timingChord: symbol)
                }, kind: line.kind)
            }
        }

        return ChordChart(
            sourceTitle: fallbackTitle,
            title: title,
            artist: artist,
            key: key,
            bpm: bpm,
            beatsPerBar: beatsPerBar,
            beatUnit: beatUnit,
            lines: lines,
            sourceURL: sourceURL,
            youtubeVideoID:
                YouTubeLink.videoID(in: source)
                ?? linkedMediaHTML.flatMap {
                    YouTubeLink.videoID(in: $0)
                },
            sourceCapo: sourceCapo,
            sourceKey: sourceKey,
            capoDirectiveWarning: capoDirectiveWarning,
            unconvertedChordSymbols: unconverted,
            tempoChanges: tempoChanges.compactMap {
                let index = max($0.lineIndex - removedLeadingLines, 0)
                return index < lines.count ? ChartTempoChange(lineIndex: index, bpm: $0.bpm) : nil
            }
        )
    }

    private static func parseContentLine(
        _ source: String,
        previousChord: inout String?
    ) -> ChartLine {
        let line = rhythmBracket.stringByReplacingMatches(
            in: source, range: NSRange(location: 0, length: (source as NSString).length), withTemplate: "$1")
        let nsLine =
            line as NSString

        let matches =
            bracket.matches(
                in: line,
                range: NSRange(
                    location: 0,
                    length: nsLine.length
                )
            )

        var segments: [ChartSegment] = []
        var cursor = 0
        var pendingChord: String?

        for match in matches {
            let fullRange =
                match.range(at: 0)

            let tokenRange =
                match.range(at: 1)

            let beforeRange =
                NSRange(
                    location: cursor,
                    length:
                        max(
                            fullRange.location -
                                cursor,
                            0
                        )
                )

            let before =
                nsLine.substring(
                    with: beforeRange
                )

            if !before.isEmpty ||
                pendingChord != nil {
                appendSegment(
                    chord: pendingChord,
                    text: before,
                    to: &segments
                )
                pendingChord = nil
            }

            let token =
                nsLine.substring(
                    with: tokenRange
                )
                .trimmingCharacters(
                    in: .whitespaces
                )

            if let chord = normalizedChordToken(token, previous: previousChord) {
                pendingChord = chord
                if !["<", "N.C.", "NC"].contains(chord.uppercased()) { previousChord = chord }
            } else {
                appendSegment(
                    chord: nil,
                    text: "[\(token)]",
                    to: &segments
                )
            }

            cursor =
                fullRange.location +
                fullRange.length
        }

        if cursor <= nsLine.length {
            let tail =
                nsLine.substring(
                    from: cursor
                )

            if !tail.isEmpty ||
                pendingChord != nil {
                appendSegment(
                    chord: pendingChord,
                    text: tail,
                    to: &segments
                )
            }
        }

        if segments.isEmpty {
            segments = [
                ChartSegment(
                    text: line
                )
            ]
        }

        return ChartLine(
            segments: segments,
            kind: .content
        )
    }

    private static func appendSegment(
        chord: String?,
        text: String,
        to segments:
            inout [ChartSegment]
    ) {
        if chord == nil,
           let last = segments.last,
           last.chord == nil {
            segments[
                segments.index(
                    before:
                        segments.endIndex
                )
            ] =
                ChartSegment(
                    text:
                        last.text + text
                )
        } else {
            segments.append(
                ChartSegment(
                    chord: chord,
                    text: text
                )
            )
        }
    }

    private static let bassNote = try! NSRegularExpression(pattern: #"^[A-G](?:#|b)?$"#)

    /// Reads editor variations of a chord name: full-width letters, accent marks
    /// (`[Am>]`), and bass-only changes (`[/B]` after `[Em7]` means `Em7/B`).
    private static func normalizedChordToken(_ token: String, previous: String?) -> String? {
        var value = String(token.unicodeScalars.map { scalar -> Character in
            switch scalar.value {
            case 0xFF01...0xFF5E: Character(UnicodeScalar(scalar.value - 0xFEE0)!)
            case 0x266F: "#"
            default: Character(scalar)
            }
        })
        while let last = value.last, ">^!".contains(last) { value.removeLast() }
        value = value.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("/"), let previous {
            let bass = String(value.dropFirst())
            guard bassNote.firstMatch(in: bass, range: NSRange(location: 0, length: (bass as NSString).length)) != nil
            else { return nil }
            var base = previous
            if let slash = previous.range(of: "/", options: .backwards),
               bassNote.firstMatch(in: String(previous[slash.upperBound...]),
                                   range: NSRange(location: 0, length: (previous[slash.upperBound...] as Substring).utf16.count)) != nil {
                base = String(previous[..<slash.lowerBound])
            }
            value = base + "/" + bass
        }
        return isChordToken(value) ? value : nil
    }

    private static func isChordToken(
        _ value: String
    ) -> Bool {
        let normalized =
            value
                .replacingOccurrences(
                    of: "♯",
                    with: "#"
                )
                .replacingOccurrences(
                    of: "♭",
                    with: "b"
                )

        if normalized == "<" ||
            normalized.uppercased() ==
                "N.C." ||
            normalized.uppercased() ==
                "NC" {
            return true
        }

        let ns =
            normalized as NSString

        return chordToken
            .firstMatch(
                in: normalized,
                range: NSRange(
                    location: 0,
                    length: ns.length
                )
            ) != nil
    }

    private static func parseDirective(
        _ line: String
    ) -> (
        name: String,
        value: String
    )? {
        let ns =
            line as NSString

        guard
            let match =
                directive.firstMatch(
                    in: line,
                    range: NSRange(
                        location: 0,
                        length: ns.length
                    )
                )
        else {
            return nil
        }

        let name =
            ns.substring(
                with:
                    match.range(at: 1)
            )
            .trimmingCharacters(
                in: .whitespaces
            )

        let value: String

        if match.range(at: 2)
            .location != NSNotFound {
            value =
                ns.substring(
                    with:
                        match.range(at: 2)
                )
                .trimmingCharacters(
                    in: .whitespaces
                )
        } else {
            value = ""
        }

        return (
            name,
            value
        )
    }

    private static func parseMeter(
        _ value: String
    ) -> (Int, Int)? {
        let parts =
            value.split(
                separator: "/"
            )

        guard
            parts.count == 2,
            let beats =
                Int(parts[0]),
            let unit =
                Int(parts[1]),
            (1...12).contains(beats),
            [2, 4, 8, 16]
                .contains(unit)
        else {
            return nil
        }

        return (
            beats,
            unit
        )
    }
}

public enum ChordTimelineBuilder {

    public static func build(
        chart: ChordChart,
        unmarkedBarsPerLine: Int? = nil
    ) -> ChordTimeline {
        var beatCursor = 0.0
        var nextID = 0
        var events:
            [TimedChordEvent] = []
        var lineTimings: [TimedChartLine] = []
        var tempoChanges: [TimedTempoChange] = []
        let inferredBars = inferredUnmarkedBars(chart: chart)
        let fallbackBars = min(max(unmarkedBarsPerLine ?? inferredBars, 1), 16)
        var meterBeats = Double(chart.beatsPerBar)

        for (
            lineIndex,
            line
        ) in chart.lines.enumerated() {
            for change in chart.tempoChanges where change.lineIndex == lineIndex {
                tempoChanges.append(TimedTempoChange(startBeat: beatCursor, bpm: change.bpm))
            }
            guard line.kind == .content else {
                continue
            }

            let hasText =
                line.segments
                    .contains {
                        !$0.text
                            .replacingOccurrences(
                                of: "|",
                                with: ""
                            )
                            .trimmingCharacters(
                                in: .whitespaces
                            )
                            .isEmpty
                    }

            let hasChord =
                line.segments
                    .contains {
                        $0.timingChord != nil
                    }

            let hasBars = line.segments.contains { normalizedBars($0.text).contains("|") }
            guard hasText || hasChord || hasBars else {
                continue
            }
            let lineStart = beatCursor
            let scan = scanBars(line, meterBeats: &meterBeats, fallbackBars: fallbackBars)

            for _ in 0..<scan.repeats {
                for bar in scan.bars {
                    let slots = bar.slots
                    let totalWeight = slots.reduce(0) { $0 + $1.weight }
                    var slotStart = beatCursor
                    for (index, slot) in slots.enumerated() {
                        let duration = totalWeight > 0 ? bar.beats * slot.weight / totalWeight : 0
                        if let chord = slot.chord {
                            events.append(TimedChordEvent(id: nextID, symbol: chord.symbol, lineIndex: lineIndex,
                                                          segmentIndex: chord.segmentIndex, startBeat: slotStart,
                                                          durationBeats: duration, isPlayable: chord.isPlayable))
                            nextID += 1
                        } else if index == 0, slots.count > 1, let held = events.last,
                                  abs(held.startBeat + held.durationBeats - slotStart) < 0.0001 {
                            // Lyrics or rests before the bar's first chord keep the previous chord sounding.
                            events[events.count - 1] = TimedChordEvent(
                                id: held.id, symbol: held.symbol, lineIndex: held.lineIndex,
                                segmentIndex: held.segmentIndex, startBeat: held.startBeat,
                                durationBeats: held.durationBeats + duration, isPlayable: held.isPlayable)
                        }
                        slotStart += duration
                    }
                    beatCursor += bar.beats
                }
            }
            lineTimings.append(TimedChartLine(lineIndex: lineIndex, startBeat: lineStart,
                                             durationBeats: beatCursor - lineStart))
        }

        return ChordTimeline(
            beatsPerBar:
                chart.beatsPerBar,
            totalBeats:
                beatCursor,
            events: events,
            lineTimings: lineTimings,
            tempoChanges: tempoChanges,
            sourceBPM: chart.bpm
        )
    }

    public static func inferredUnmarkedBars(chart: ChordChart) -> Int {
        var meterBeats = Double(chart.beatsPerBar)
        let counts = chart.lines.filter { $0.kind == .content }
            .map { scanBars($0, meterBeats: &meterBeats, fallbackBars: 1) }
            .filter(\.isBarred).map(\.bars.count).filter { $0 > 0 }.sorted()
        return counts.isEmpty ? 1 : min(max(counts[counts.count / 2], 1), 16)
    }

    private static func normalizedBars(_ text: String) -> String {
        text.map { "｜│┃¦".contains($0) ? "|" : String($0) }.joined()
    }

    private struct IndexedChord {
        let segmentIndex: Int
        let symbol: String
        let isPlayable: Bool
    }

    /// One bar as written: its chords, the rhythm dashes after each, and what precedes the first chord.
    private struct ScannedBar {
        var chords: [IndexedChord] = []
        var dashes: [Int] = []
        var leadingDashes = 0
        var leadingLyric = false
        var hasLyric = false
        var beats = 0.0

        var isEmpty: Bool {
            chords.isEmpty && leadingDashes == 0 && dashes.allSatisfy { $0 == 0 } && !hasLyric
        }

        /// Wiki rhythm dashes (`[C]---[G]-`) place chords inside the bar when every chord has them.
        /// Otherwise chords share the bar equally, with one held slot for lyrics before the first chord.
        var slots: [(chord: IndexedChord?, weight: Double)] {
            guard !chords.isEmpty else { return [(nil, 1)] }
            let dashTimed = !hasLyric && dashes.allSatisfy { $0 > 0 }
            let hold = dashTimed ? Double(leadingDashes) : (leadingLyric || leadingDashes > 0 ? 1 : 0)
            let timed = chords.indices.map { (Optional(chords[$0]), dashTimed ? Double(dashes[$0]) : 1) }
            return hold > 0 ? [(nil, hold)] + timed : timed
        }
    }

    private struct LineScan {
        var bars: [ScannedBar]
        var isBarred: Bool
        var repeats: Int
    }

    /// Inline meter changes written by wiki editors, e.g. `(3/4)` or `(6/8)`.
    private static let meterToken = try! NSRegularExpression(
        pattern: #"[(（]\s*(\d{1,2})\s*/\s*(1|2|4|8|16)\s*[)）]"#)

    /// A repeat count after the last bar line, e.g. `|[C]----|[G]----| x4`.
    private static let repeatTail = try! NSRegularExpression(pattern: #"^\s*[xX×✕]\s*(\d{1,2})\s*$"#)

    private enum TextPiece {
        case text(String)
        case meter(Double)
    }

    private static func pieces(_ text: String) -> [TextPiece] {
        let ns = text as NSString
        var result: [TextPiece] = []
        var cursor = 0
        for match in meterToken.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard let beats = Int(ns.substring(with: match.range(at: 1))),
                  let unit = Int(ns.substring(with: match.range(at: 2))), (1...16).contains(beats) else { continue }
            if match.range.location > cursor {
                result.append(.text(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))))
            }
            result.append(.meter(Double(beats) * 4 / Double(unit)))
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length { result.append(.text(ns.substring(from: cursor))) }
        return result
    }

    private static func scanBars(_ line: ChartLine, meterBeats: inout Double, fallbackBars: Int) -> LineScan {
        var bars: [ScannedBar] = []
        var current = ScannedBar()
        var barred = false
        var opensWithBarLine = false
        var tail = ""

        func closeBar() {
            current.beats = meterBeats
            bars.append(current)
            current = ScannedBar()
            tail = ""
        }

        func changeMeter(_ beats: Double) {
            // A meter written mid-line starts a new bar, like an implicit bar line.
            if !current.isEmpty {
                closeBar()
                barred = true
            }
            meterBeats = beats
        }

        for (segmentIndex, segment) in line.segments.enumerated() {
            var textPieces = pieces(normalizedBars(segment.text))
            if segment.timingChord != nil,
               case .text(let lead)? = textPieces.first, lead.allSatisfy(\.isWhitespace),
               textPieces.count > 1, case .meter(let beats) = textPieces[1] {
                // `[Em](3/4)` puts the chord on the first beat of the new meter.
                changeMeter(beats)
                textPieces.removeFirst(2)
            } else if segment.timingChord != nil, case .meter(let beats)? = textPieces.first {
                changeMeter(beats)
                textPieces.removeFirst()
            }
            if let chord = segment.timingChord {
                current.chords.append(IndexedChord(segmentIndex: segmentIndex, symbol: chord, isPlayable: segment.chord != nil))
                current.dashes.append(0)
            }
            for piece in textPieces {
                switch piece {
                case .meter(let beats):
                    changeMeter(beats)
                case .text(let text):
                    for character in text {
                        if character == "|" {
                            // A line-leading bar line opens the first bar rather than ending an empty one.
                            if bars.isEmpty && current.isEmpty && !barred { opensWithBarLine = true } else { closeBar() }
                            barred = true
                            tail = ""
                        } else if character == "-" {
                            if current.chords.isEmpty { current.leadingDashes += 1 } else { current.dashes[current.dashes.count - 1] += 1 }
                            tail.append(character)
                        } else if character.isWhitespace || ">＞↓↑".contains(character) {
                            tail.append(character)
                        } else {
                            if current.chords.isEmpty { current.leadingLyric = true }
                            current.hasLyric = true
                            tail.append(character)
                        }
                    }
                }
            }
        }

        var repeats = 1
        if barred {
            let ns = tail as NSString
            if let match = repeatTail.firstMatch(in: tail, range: NSRange(location: 0, length: ns.length)),
               let count = Int(ns.substring(with: match.range(at: 1))), (2...16).contains(count) {
                repeats = count
            }
            if !current.chords.isEmpty || current.leadingDashes > 0 || current.dashes.contains(where: { $0 > 0 }) {
                closeBar()
            }
            // `[C]lyrics[G]more[Am]words-|[F]--|`: a sung phrase before the first bar line
            // is an unmarked line followed by marked bars, not one crowded bar.
            if !opensWithBarLine, let first = bars.first, first.hasLyric, first.chords.count >= 3 {
                bars[0].beats = first.beats * Double(fallbackBars)
            }
        } else {
            current.beats = meterBeats * Double(fallbackBars)
            bars = [current]
        }
        return LineScan(bars: bars, isBarred: barred, repeats: repeats)
    }
}
