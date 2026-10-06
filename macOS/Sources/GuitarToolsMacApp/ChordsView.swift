import GuitarToolsCore
import SwiftUI

struct ChordsView: View {
    @ObservedObject var learning: ChordLearningModel

    private enum LibraryMode: String, CaseIterable, Identifiable {
        case learn = "覚える"
        case basic = "基本コード"
        case all = "すべてのコード"
        var id: String { rawValue }
    }

    @State private var mode: LibraryMode = .basic
    @State private var query = ""
    @State private var readingGuideExpanded = false
    @State private var selectedRoot: GuitarNote?
    @State private var selectedQuality: GuitarChordQuality?

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 210), spacing: 14)
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                MacPageHeader("コード") {
                    MacStatusPill(text: mode == .learn ? "コード学習" : "\(resultCount) コード", systemImage: "guitars")
                }
                if mode != .learn {
                    Picker("表示するコード", selection: $mode) {
                        Text("基本（9）").tag(LibraryMode.basic)
                        Text("すべて（\(CommonGuitarChords.all.count)）").tag(LibraryMode.all)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(MacLayout.pagePadding)
            .macPageWidth(1_180)
            Divider()
            if mode == .learn {
                ChordLearningView(model: learning)
            } else {
                library
            }
        }
        .navigationTitle("コード")
        .toolbar {
            if mode == .learn {
                Button("コード一覧", systemImage: "guitars") { mode = .basic }
            } else {
                Menu("その他のツール", systemImage: "ellipsis.circle") {
                    Button("コード学習", systemImage: "brain") { mode = .learn }
                }
            }
        }
        .onAppear {
            if learning.phase != .idle && learning.phase != .completed { mode = .learn }
        }
        .searchable(text: $query, placement: .toolbar, prompt: "C, Db/F, Cm6/9...")
        .onChange(of: query) { _, value in
            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && mode == .learn { mode = .all }
        }
        .onChange(of: learning.phase) { _, phase in
            if phase != .idle && phase != .completed { mode = .learn; query = "" }
        }
    }

    private var library: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MacLayout.sectionSpacing) {
                readingGuide

                if mode == .all {
                    filterBar
                }

                if let exactQuery {
                    MacSection("指定したコード（カポなし）") {
                        ChordFingeringView(symbol: exactQuery.symbol)
                            .frame(width: 260)
                            .contextMenu {
                                Button("コード学習", systemImage: "brain") {
                                    learn([exactQuery.symbol], title: "\(exactQuery.symbol)のコード")
                                }
                            }
                    }
                } else if resultCount == 0 {
                    ContentUnavailableView(
                        "コードが見つかりません",
                        systemImage: "magnifyingglass",
                        description: Text("検索語またはフィルターを変更してください。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else if mode == .basic {
                    basicChordGrid
                } else {
                    ForEach(displayedRoots) { root in
                        let shapes = filteredShapes(root: root)
                        if !shapes.isEmpty {
                            rootSection(root, shapes: shapes)
                        }
                    }
                }
            }
            .padding(MacLayout.pagePadding)
            .macPageWidth(1_180)
        }
    }

    private func learn(_ symbols: [String], title: String) {
        learning.startCustom(symbols: symbols, title: title)
        query = ""
        mode = .learn
    }

    private var readingGuide: some View {
        DisclosureGroup("コード図の読み方", isExpanded: $readingGuideExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ChordFingerLegend()
                Text("数字は指番号、○は開放弦、×は鳴らさない弦です。上が1弦、下が6弦、左がヘッド側です。標準チューニング・カポなしの押さえ方を表示します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }

    private var basicChordGrid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(filteredBasicShapes) { shape in
                VStack(alignment: .leading, spacing: 10) {
                    ChordFingeringView(symbol: shape.name, compact: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .macContentSurface(radius: 18)
                .contextMenu {
                    Button("コード学習", systemImage: "brain") {
                        learn([shape.name], title: "\(shape.name)のコード")
                    }
                }
            }
        }
    }

    private var filteredBasicShapes: [GuitarChordShape] {
        ["Em", "Am", "C", "G", "D", "A", "E", "Dm", "F"]
            .compactMap { CommonGuitarChords.shape(named: $0) }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var filterBar: some View {
        MacSection("絞り込み") {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) {
                    rootPicker
                    qualityPicker
                    Spacer(minLength: 0)
                    resetButton
                }
                VStack(alignment: .leading, spacing: 14) {
                    rootPicker
                    qualityPicker
                    resetButton
                }
            }
        }
    }

    private var rootPicker: some View {
        Picker("基準の音", selection: $selectedRoot) {
            Text("すべて").tag(Optional<GuitarNote>.none)
            ForEach(GuitarNote.allCases) { note in
                Text(note.displayName).tag(Optional(note))
            }
        }
        .frame(minWidth: 160)
    }

    private var qualityPicker: some View {
        Picker("種類", selection: $selectedQuality) {
            Text("すべて").tag(Optional<GuitarChordQuality>.none)
            ForEach(GuitarChordQuality.allCases) { quality in
                Text(quality.displayName).tag(Optional(quality))
            }
        }
        .frame(minWidth: 200)
    }

    @ViewBuilder
    private var resetButton: some View {
        if selectedRoot != nil || selectedQuality != nil || !query.isEmpty {
            Button("リセット", systemImage: "arrow.counterclockwise") {
                selectedRoot = nil
                selectedQuality = nil
                query = ""
            }
        }
    }

    private func rootSection(_ root: GuitarNote, shapes: [GuitarChordShape]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(root.displayName)
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("\(shapes.count) 種類")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.top, 6)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(shapes) { shape in
                    VStack(spacing: 10) {
                        ChordFingeringView(symbol: shape.name, compact: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .macContentSurface(radius: 18)
                    .contextMenu {
                        Button("コード学習", systemImage: "brain") {
                            learn([shape.name], title: "\(shape.name)のコード")
                        }
                    }
                }
            }
        }
    }

    private var displayedRoots: [GuitarNote] {
        if let selectedRoot { [selectedRoot] } else { GuitarNote.allCases }
    }

    private var exactQuery: ChordFingeringPresentation? {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let value = ChordFingeringPresentation(symbol: query)
        return value.availability == .supported ? value : nil
    }

    private var resultCount: Int {
        if exactQuery != nil { return 1 }
        if mode == .basic {
            return filteredBasicShapes.count
        } else {
            return displayedRoots.reduce(0) { $0 + filteredShapes(root: $1).count }
        }
    }

    private func filteredShapes(root: GuitarNote) -> [GuitarChordShape] {
        CommonGuitarChords.forRoot(root).filter { shape in
            let queryMatch = query.isEmpty || shape.name.localizedCaseInsensitiveContains(query)
            let qualityMatch = selectedQuality == nil || shape.chord.quality == selectedQuality
            return queryMatch && qualityMatch
        }
    }
}
