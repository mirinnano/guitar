import GuitarToolsCore

/// Keeps the real preceding timing slot, including across source lines.
/// Unsafe slots and NC are barriers rather than skipped neighbours.
enum ChartVoicingContext {
    static func previousSymbols(timeline: ChordTimeline?, lineIndex: Int) -> [Int: String] {
        guard let timeline else { return [:] }
        var result: [Int: String] = [:]
        for index in timeline.events.indices where index > 0 {
            let event = timeline.events[index]
            let previous = timeline.events[index - 1]
            guard event.lineIndex == lineIndex, previous.isPlayable,
                  GuitarChordData.selectionKey(for: previous.symbol) != nil else { continue }
            result[event.segmentIndex] = previous.symbol
        }
        return result
    }
}
