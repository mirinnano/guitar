import Foundation

public enum ChartLineKind: Sendable, Equatable {
    case content
    case comment
    case blank
}

public struct ChartSegment: Sendable, Equatable {
    public let chord: String?
    public let text: String

    public init(
        chord: String? = nil,
        text: String
    ) {
        self.chord = chord
        self.text = text
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
        youtubeVideoID: String? = nil
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
        self.youtubeVideoID =
            youtubeVideoID
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

    public init(
        id: Int,
        symbol: String,
        lineIndex: Int,
        segmentIndex: Int,
        startBeat: Double,
        durationBeats: Double
    ) {
        self.id = id
        self.symbol = symbol
        self.lineIndex = lineIndex
        self.segmentIndex = segmentIndex
        self.startBeat = startBeat
        self.durationBeats = durationBeats
    }
}

public struct ChordTimeline: Sendable, Equatable {
    public let beatsPerBar: Int
    public let totalBeats: Double
    public let events: [TimedChordEvent]

    public init(
        beatsPerBar: Int,
        totalBeats: Double,
        events: [TimedChordEvent]
    ) {
        self.beatsPerBar = beatsPerBar
        self.totalBeats = totalBeats
        self.events = events
    }

    public func seconds(
        forBeat beat: Double,
        bpm: Int
    ) -> Double {
        guard bpm > 0 else {
            return 0
        }

        return max(beat, 0) *
            60.0 /
            Double(bpm)
    }

    public func beat(
        forSeconds seconds: Double,
        bpm: Int
    ) -> Double {
        guard bpm > 0 else {
            return 0
        }

        return min(
            max(
                seconds *
                    Double(bpm) /
                    60.0,
                0
            ),
            totalBeats
        )
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

    private static let bracket =
        try! NSRegularExpression(
            pattern:
                #"\[([^\]]+)\]"#
        )

    private static let chordToken =
        try! NSRegularExpression(
            pattern:
                #"^[A-Ga-g](?:#|b|♯|♭)?[A-Za-z0-9#b♯♭()+,\-△Δ°ø]*(?:/[A-Ga-g](?:#|b|♯|♭)?)?$"#
        )

    public static func parse(
        _ source: String,
        fallbackTitle: String,
        sourceURL: URL? = nil
    ) -> ChordChart {
        var title = fallbackTitle
        var artist = ""
        var key: String?
        var bpm: Int?
        var beatsPerBar = 4
        var beatUnit = 4
        var lines: [ChartLine] = []

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

                    case "tempo", "bpm":
                        if let number =
                            Int(value),
                           (20...400)
                            .contains(number) {
                            bpm = number
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

                lines.append(
                    parseContentLine(
                        rawLine
                    )
                )
            }

        while lines.first?.kind == .blank {
            lines.removeFirst()
        }

        while lines.last?.kind == .blank {
            lines.removeLast()
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
                extractYouTubeVideoID(
                    source
                )
        )
    }

    private static func extractYouTubeVideoID(
        _ source: String
    ) -> String? {
        let patterns = [
            #"https?://(?:www\.)?youtube\.com/watch\?[^\s}]*?\bv=([A-Za-z0-9_-]{11})"#,
            #"https?://youtu\.be/([A-Za-z0-9_-]{11})"#,
            #"https?://(?:www\.)?youtube\.com/embed/([A-Za-z0-9_-]{11})"#,
            #"\{(?:youtube|yt)\s*:\s*([A-Za-z0-9_-]{11})\s*\}"#
        ]

        for pattern in patterns {
            guard let regex =
                try? NSRegularExpression(
                    pattern: pattern,
                    options:
                        [.caseInsensitive]
                )
            else {
                continue
            }

            let ns =
                source as NSString

            if let match =
                regex.firstMatch(
                    in: source,
                    range: NSRange(
                        location: 0,
                        length: ns.length
                    )
                ) {
                return ns.substring(
                    with:
                        match.range(at: 1)
                )
            }
        }

        return nil
    }

    private static func parseContentLine(
        _ line: String
    ) -> ChartLine {
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

            if isChordToken(token) {
                pendingChord = token
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
        chart: ChordChart
    ) -> ChordTimeline {
        var beatCursor = 0.0
        var nextID = 0
        var events:
            [TimedChordEvent] = []

        for (
            lineIndex,
            line
        ) in chart.lines.enumerated() {
            guard line.kind == .content else {
                continue
            }

            let groups =
                splitIntoBars(line)

            let effective =
                groups.isEmpty
                ? [[]]
                : groups

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
                        $0.chord != nil
                    }

            guard hasText || hasChord else {
                continue
            }

            for group in effective {
                let barStart =
                    beatCursor

                if !group.isEmpty {
                    let duration =
                        Double(
                            chart.beatsPerBar
                        ) /
                        Double(group.count)

                    for (
                        index,
                        chord
                    ) in group.enumerated() {
                        events.append(
                            TimedChordEvent(
                                id: nextID,
                                symbol:
                                    chord.symbol,
                                lineIndex:
                                    lineIndex,
                                segmentIndex:
                                    chord.segmentIndex,
                                startBeat:
                                    barStart +
                                    Double(index) *
                                    duration,
                                durationBeats:
                                    duration
                            )
                        )
                        nextID += 1
                    }
                }

                beatCursor +=
                    Double(
                        chart.beatsPerBar
                    )
            }
        }

        return ChordTimeline(
            beatsPerBar:
                chart.beatsPerBar,
            totalBeats:
                beatCursor,
            events: events
        )
    }

    private struct IndexedChord {
        let segmentIndex: Int
        let symbol: String
    }

    private static func splitIntoBars(
        _ line: ChartLine
    ) -> [[IndexedChord]] {
        var groups:
            [[IndexedChord]] = []
        var current:
            [IndexedChord] = []
        var sawBar = false

        for (
            segmentIndex,
            segment
        ) in line.segments.enumerated() {
            if let chord =
                segment.chord {
                current.append(
                    IndexedChord(
                        segmentIndex:
                            segmentIndex,
                        symbol: chord
                    )
                )
            }

            let barCount =
                segment.text
                    .split(
                        separator: "|",
                        omittingEmptySubsequences:
                            false
                    )
                    .count - 1

            if barCount > 0 {
                sawBar = true

                for _ in 0..<barCount {
                    groups.append(
                        current
                    )
                    current.removeAll(
                        keepingCapacity: true
                    )
                }
            }
        }

        if !current.isEmpty ||
            !sawBar {
            groups.append(current)
        }

        while groups.count > 1 &&
            groups.last?.isEmpty == true {
            groups.removeLast()
        }

        return groups
    }
}
