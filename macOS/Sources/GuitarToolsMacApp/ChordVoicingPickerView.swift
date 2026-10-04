import GuitarToolsCore
import SwiftUI

struct ChordVoicingPickerView: View {
    private enum Page: String, CaseIterable { case shapes = "押さえ方", data = "コードのデータ" }
    private enum Order: String, CaseIterable {
        case standard = "定番優先", open = "開放弦優先", barre = "バレー少なめ"
        case low = "低い位置", nearby = "前のコードに近い形"
    }
    let symbol: String
    var previousSymbol: String?
    @ObservedObject var preferences: ChordVoicingPreferencesStore
    @State private var page: Page = .shapes
    @State private var order: Order = .standard

    private var data: GuitarChordData? { GuitarChordData(symbol: symbol) }
    private var selected: GuitarChordVoicing? {
        guard let data else { return nil }
        return data.voicings.first { $0.id == preferences.selectedID(for: symbol) } ?? data.voicings.first
    }
    private var previousShape: GuitarChordShape? {
        previousSymbol.flatMap { preferences.presentation(for: $0).shape }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(symbol).font(.title.weight(.bold))
                if let data { Text(data.japaneseName).font(.callout).foregroundStyle(.secondary) }
                Spacer()
                Text("標準チューニング・カポなし").font(.caption).foregroundStyle(.secondary)
            }
            Picker("表示", selection: $page) {
                ForEach(Page.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if let data {
                if page == .shapes {
                    Picker("候補の並び", selection: $order) {
                        ForEach(Order.allCases.filter { $0 != .nearby || previousShape != nil }, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .font(.caption)
                    Text("定番フォームを優先。参考フォームも構成音と最低音を検証していますが、一般的な指使いや弾きやすさを保証するものではありません。")
                        .font(.caption2).foregroundStyle(.secondary)
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                            ForEach(sorted(data.voicings)) { voicing in
                                Button { preferences.select(voicing.id, for: symbol) } label: {
                                    VStack(spacing: 8) {
                                        HStack {
                                            Text(voicing.id == selected?.id ? "選択中" : "候補")
                                            Spacer()
                                            if voicing.id == selected?.id { Image(systemName: "checkmark.circle.fill") }
                                        }
                                        .font(.caption.weight(.semibold))
                                        Text(voicing.isConventional ? "定番フォーム" : "参考フォーム")
                                            .font(.caption).foregroundStyle(.secondary)
                                        ChordShapeDiagram(shape: voicing.shape, compact: true, displayName: symbol)
                                        Text("開放\(voicing.openStringCount)弦 · バレー\(voicing.barreCount)本")
                                            .font(.caption)
                                        Text("\(voicing.lowestFret)〜\(voicing.maxFret)フレット")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        if !voicing.omittedNotes.isEmpty {
                                            Text("省略音：" + voicing.omittedNotes.map(\.displayName).joined(separator: "・"))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                                    .macContentSurface(radius: 14)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(voicing.id == selected?.id ? Color.accentColor : .clear, lineWidth: 2)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(symbol)、\(voicing.isConventional ? "定番フォーム" : "参考フォーム")、開放\(voicing.openStringCount)弦、バレー\(voicing.barreCount)本、\(voicing.lowestFret)から\(voicing.maxFret)フレット")
                                .accessibilityAddTraits(voicing.id == selected?.id ? .isSelected : [])
                            }
                        }
                        .padding(2)
                    }
                } else {
                    ScrollView { chordDetails(data).padding(.vertical, 4) }
                }
            } else {
                ContentUnavailableView("対応データがありません", systemImage: "guitars")
            }
            Divider()
            HStack {
                Button("標準の形へ戻す") { preferences.select(nil, for: symbol) }
                Spacer()
                Text("選んだ形をコードごとに保存。譜面とコード一覧に反映します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 620, height: 530)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func chordDetails(_ data: GuitarChordData) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(data.explanation).font(.callout)
            detailRow("音程", data.intervalLabels.joined(separator: "・"))
            detailRow("構成音", data.theoreticalNotes.map { noteName($0) }.joined(separator: "・"))
            if !data.aliases.isEmpty { detailRow("種類の別表記", data.aliases.map { $0.isEmpty ? "省略（メジャー）" : $0 }.joined(separator: " / ")) }
            if let selected {
                if let lowest = selected.stringNotes.compactMap(\.midi).min() {
                    detailRow("実際の最低音", noteName(GuitarNote.fromMIDI(lowest)) + "\(lowest / 12 - 1)")
                }
                if !selected.omittedNotes.isEmpty {
                    detailRow("この形の省略音", selected.omittedNotes.map { noteName($0) }.joined(separator: "・"))
                }
                Text("選択中の形で鳴る音（A4 = 440 Hz）").font(.headline)
                ForEach(selected.stringNotes.sorted { $0.stringNumber > $1.stringNumber }, id: \.stringNumber) { string in
                    HStack {
                        Text("\(string.stringNumber)弦").frame(width: 42, alignment: .leading)
                        Text(string.fret < 0 ? "× 鳴らさない" : string.fret == 0 ? "○ 開放弦" : "\(string.fret)フレット")
                            .frame(width: 130, alignment: .leading)
                        if let midi = string.midi {
                            Text(noteName(GuitarNote.fromMIDI(midi)) + "\(midi / 12 - 1)")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "%.1f Hz", GuitarNote.frequency(forMIDI: midi, a4Hz: 440)))
                                .monospacedDigit()
                        }
                    }
                    .font(.callout)
                }
                Text("指番号は目安です。省略音がある場合は上に明記します。構成音は異名同音を簡略表記しています。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary).frame(width: 105, alignment: .leading)
            Text(value).fontWeight(.medium)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    private func noteName(_ note: GuitarNote) -> String {
        let root = String(symbol.prefix(2))
        return note.displayName(root.contains("b") || root.contains("♭") ? .flats : .sharps)
    }

    private func sorted(_ options: [GuitarChordVoicing]) -> [GuitarChordVoicing] {
        let chosenID = selected?.id
        let previous = previousShape
        // Pin the current choice so reopening the picker never hides it below the fold.
        return options.sorted { lhs, rhs in
            if (lhs.id == chosenID) != (rhs.id == chosenID) { return lhs.id == chosenID }
            switch order {
            case .standard:
                if lhs.isConventional != rhs.isConventional { return lhs.isConventional }
                // Retain the curated order before applying the optional heuristics.
                let left = options.firstIndex { $0.id == lhs.id } ?? options.count
                let right = options.firstIndex { $0.id == rhs.id } ?? options.count
                if left != right { return left < right }
            case .open:
                if lhs.openStringCount != rhs.openStringCount { return lhs.openStringCount > rhs.openStringCount }
            case .barre:
                if lhs.barreCount != rhs.barreCount { return lhs.barreCount < rhs.barreCount }
            case .nearby:
                if let previous {
                    let left = movement(lhs.shape, from: previous)
                    let right = movement(rhs.shape, from: previous)
                    if left != right { return left < right }
                }
            case .low: break
            }
            if lhs.maxFret != rhs.maxFret { return lhs.maxFret < rhs.maxFret }
            if lhs.barreCount != rhs.barreCount { return lhs.barreCount < rhs.barreCount }
            return lhs.id < rhs.id
        }
    }

    private func movement(_ target: GuitarChordShape, from source: GuitarChordShape) -> Int {
        zip(target.frets, source.frets).reduce(0) { result, pair in
            if pair.0 >= 0 && pair.1 >= 0 { return result + abs(pair.0 - pair.1) }
            return result + (pair.0 == pair.1 ? 0 : 4)
        }
    }
}
