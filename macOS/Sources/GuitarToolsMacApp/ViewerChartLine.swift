import GuitarToolsCore
import SwiftUI

struct ViewerChartLine: View {
    let line: ChartLine
    let lineIndex: Int
    let activeEvent: TimedChordEvent?
    let anchors: [ChordSyncAnchor]
    let calibrationMode: Bool
    let showFingerings: Bool
    let fontSize: CGFloat
    let events: [TimedChordEvent]
    let previousSymbols: [Int: String]
    let onAnchor: (TimedChordEvent) -> Void
    @State private var selectedSegment: Int?

    private var isInstrumental: Bool {
        line.segments.allSatisfy { segment in
            segment.text.allSatisfy { $0.isWhitespace || "|｜│┃¦".contains($0) }
        }
    }

    var body: some View {
        switch line.kind {
        case .blank:
            Color.clear.frame(height: 8)
        case .comment:
            Text(line.segments.map(\.text).joined())
                .font(.system(size: max(14, fontSize * 0.8), weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)
        case .content:
            ChartLineLayout {
                ForEach(Array(line.segments.enumerated()), id: \.offset) { index, segment in
                    segmentView(segment, index: index)
                }
            }
        }
    }

    private func segmentView(_ segment: ChartSegment, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if showFingerings {
                if let chord = segment.chord {
                    InlineChordFingering(chord: chord, previousSymbol: previousSymbols[index])
                } else {
                    Color.clear.frame(width: 1, height: InlineChordFingering.height)
                }
            }
            if isInstrumental {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    if let chord = segment.chord {
                        chordButton(chord, index: index)
                    }
                    if !segment.text.isEmpty {
                        Text(segment.text)
                            .font(.system(size: fontSize, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Group {
                    if let chord = segment.chord {
                        chordButton(chord, index: index)
                    } else {
                        Color.clear.frame(width: 1)
                    }
                }
                .frame(height: fontSize * 1.4, alignment: .leading)

                Text(segment.text.isEmpty ? " " : segment.text)
                    .font(.system(size: fontSize))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func chordButton(_ chord: String, index: Int) -> some View {
        let event = events.first { $0.segmentIndex == index }
        let anchored = anchors.contains { $0.lineIndex == lineIndex && $0.segmentIndex == index }
        return Button {
            if calibrationMode, let event {
                onAnchor(event)
            } else if !calibrationMode {
                selectedSegment = index
            }
        } label: {
            Text(chord)
                .font(.system(size: max(14, fontSize * 0.9), weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.accentColor)
                .padding(.vertical, 2)
                .padding(.trailing, 8)
                .background(chordBackground(index: index, anchored: anchored),
                            in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(calibrationMode && event == nil)
        .popover(isPresented: Binding(
            get: { selectedSegment == index },
            set: { if !$0 { selectedSegment = nil } }
        )) {
            ChordFingeringView(symbol: chord, previousSymbol: previousSymbols[index])
                .padding(20)
                .frame(width: 280)
        }
    }

    private func chordBackground(index: Int, anchored: Bool) -> Color {
        if activeEvent?.lineIndex == lineIndex && activeEvent?.segmentIndex == index {
            return Color.accentColor.opacity(0.24)
        }
        return anchored ? Color.orange.opacity(0.18) : .clear
    }
}
