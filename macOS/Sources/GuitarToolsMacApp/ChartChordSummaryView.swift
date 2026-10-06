import GuitarToolsCore
import SwiftUI

struct ChartChordSummaryView: View {
    let chart: ChordChart

    static func symbols(in chart: ChordChart) -> [String] {
        var seen = Set<String>()
        return chart.lines.flatMap(\.segments).compactMap(\.chord).compactMap { symbol in
            let value = ChordFingeringPresentation(symbol: symbol)
            guard value.availability != .noChord, seen.insert(value.symbol).inserted else { return nil }
            return value.symbol
        }
    }

    var body: some View {
        let symbols = Self.symbols(in: chart)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("使用コード")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(symbols.count)種類")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(minimum: 120)), GridItem(.flexible(minimum: 120))], spacing: 12) {
                    ForEach(symbols, id: \.self) { symbol in
                        ChordFingeringView(symbol: symbol, compact: true)
                            .frame(maxWidth: .infinity, minHeight: 138, alignment: .top)
                            .padding(10)
                            .macContentSurface(radius: 14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                if !symbols.isEmpty {
                    ChordFingerLegend()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
            }
        }
    }
}
