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
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("使用コード（\(symbols.count)種類）")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.flexible(minimum: 128)), GridItem(.flexible(minimum: 128))], spacing: 12) {
                    ForEach(symbols, id: \.self) { symbol in
                        GroupBox {
                            ChordFingeringView(symbol: symbol, compact: true)
                                .frame(maxWidth: .infinity)
                                .padding(4)
                        }
                    }
                }
                if !symbols.isEmpty { ChordFingerLegend() }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
