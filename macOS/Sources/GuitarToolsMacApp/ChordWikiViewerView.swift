import GuitarToolsCore
import SwiftUI

struct ChordWikiViewerView:
    View {

    let onPractice: ((ChartPracticeRequest) -> Void)?
    let onLearnChords: (([String], String) -> Void)?

    init(model: ChordWikiViewerModel, onPractice: ((ChartPracticeRequest) -> Void)? = nil,
         onLearnChords: (([String], String) -> Void)? = nil) {
        self.model = model
        self.onPractice = onPractice
        self.onLearnChords = onLearnChords
    }

    @ObservedObject
    private var model: ChordWikiViewerModel

    @StateObject
    private var youtubeController =
        YouTubePlayerController()

    @State
    private var inspectorPresented =
        false

    @State
    private var chordSummaryExpanded = false

    @State
    private var musicURL = ""

    @State private var musicPanelPresented = false
    @State private var coachPresented = false

    private var playbackActive: Bool {
        model.countInRemaining != nil || (model.youtubeVideoID != nil ? model.youtubePlaying : model.isPlaying)
    }

    var body: some View {
        Group {
            if let chart =
                model.chart {
                chartView(chart)
            } else {
                searchView
            }
        }
        .navigationTitle(
            model.chart?.title
            ?? "譜面"
        )
        .searchable(
            text: $model.query,
            placement: .toolbar,
            prompt:
                "曲名またはアーティスト名"
        )
        .onSubmit(
            of: .search
        ) {
            model.search()
        }
        .toolbar {
            if model.chart != nil {
                ToolbarItem(
                    placement:
                        .navigation
                ) {
                    Button {
                        model.close()
                    } label: {
                        Label(
                            "検索へ戻る",
                            systemImage:
                                "chevron.left"
                        )
                    }
                }

                ToolbarItemGroup(
                    placement:
                        .primaryAction
                ) {
                    Button(action: togglePlayback) {
                        Label(
                            playbackActive
                            ? "一時停止"
                            : "再生",
                            systemImage:
                                playbackActive
                                ? "pause.fill"
                                : "play.fill"
                        )
                    }

                    Button {
                        model
                            .setMetronome(
                                !model
                                    .metronomeEnabled
                            )
                    } label: {
                        Label(
                            "メトロノーム",
                            systemImage:
                                model
                                    .metronomeEnabled
                                ? "metronome.fill"
                                : "metronome"
                        )
                    }

                    Button {
                        model.autoScroll
                            .toggle()
                    } label: {
                        Label(
                            "自動スクロール",
                            systemImage:
                                model.autoScroll
                                ? "arrow.down.to.line.compact"
                                : "arrow.down.to.line"
                        )
                    }

                    Button {
                        inspectorPresented
                            .toggle()
                    } label: {
                        Label(
                            "インスペクタ",
                            systemImage:
                                "sidebar.trailing"
                        )
                    }
                }
            }
        }
        .inspector(
            isPresented:
                $inspectorPresented
        ) {
            if let chart =
                model.chart {
                inspector(chart)
                    .inspectorColumnWidth(
                        min: 300,
                        ideal: 350,
                        max: 430
                    )
            }
        }
        .sheet(isPresented: $coachPresented) {
            if let chart = model.chart {
                SongCoachView(chart: chart, sourceBPM: model.bpm, initialBeat: model.currentBeat) { start, end in
                    model.prepareTransitionLoop(startBeat: start, endBeat: end)
                    if model.youtubeSyncEnabled {
                        youtubeController.seek(toMilliseconds: model.videoPosition(forBeat: model.currentBeat))
                    }
                }
            }
        }
        .overlay {
            if model.isLoading {
                ProgressView()
                    .padding(14)
                    .background(
                        .regularMaterial,
                        in:
                            RoundedRectangle(
                                cornerRadius: 10
                            )
                    )
            }
        }
        .onChange(of: model.loopRestartRevision) { _ in
            guard model.loopEnabled, model.youtubeSyncEnabled,
                  let range = model.practiceLoop else { return }
            youtubeController.seek(toMilliseconds: model.videoPosition(forBeat: range.startBeat))
            youtubeController.play()
        }
        .onDisappear {
            youtubeController.pause()
            model.stop()
        }
    }

    @ViewBuilder
    private var searchView:
        some View {
        if model.isSearching {
            ProgressView(
                "ChordWiki・U-FRETを検索中"
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        } else if model.results.isEmpty {
            ChartSearchStateView(
                query: $model.query,
                submittedQuery: model.lastSearchQuery,
                error: model.errorMessage,
                onSearch: model.search
            )
        } else {
            VStack(spacing: 0) {
            if let error = model.errorMessage {
                ChartLoadErrorBanner(message: error)
            }
            List(
                model.results
            ) {
                result in

                Button {
                    model.open(result)
                } label: {
                    HStack {
                        Image(
                            systemName:
                                "music.note"
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                            Text(result.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(
                            systemName:
                                "chevron.right"
                        )
                        .foregroundStyle(
                            .tertiary
                        )
                    }
                    .contentShape(
                        Rectangle()
                    )
                }
                .buttonStyle(.plain)
            }
            }
        }
    }

    private func chartView(
        _ chart: ChordChart
    ) -> some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 900
            VStack(spacing: 0) {
            header(chart)

            Divider()

            currentPositionBar

            Divider()

            ScrollViewReader {
                proxy in

                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 7
                    ) {
                        if !usedChordSymbols.isEmpty {
                            usedChordShapes
                                .padding(
                                    .bottom,
                                    16
                                )
                        }

                        ForEach(
                            Array(
                                chart.lines
                                    .enumerated()
                            ),
                            id: \.offset
                        ) {
                            index,
                            line in

                            ViewerChartLine(
                                line: line,
                                lineIndex: index,
                                activeEvent:
                                    model
                                        .currentEvent,
                                anchors:
                                    model.anchors,
                                calibrationMode:
                                    model
                                        .calibrationMode,
                                events:
                                    model
                                        .timeline?
                                        .events
                                        .filter {
                                            $0.lineIndex ==
                                            index
                                        }
                                    ?? [],
                                previousSymbols: ChartVoicingContext.previousSymbols(timeline: model.timeline, lineIndex: index),
                                onAnchor:
                                    model
                                        .addAnchor
                            )
                            .id(index)
                        }
                    }
                    .padding(24)
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            .leading
                    )
                }
                .task {
                    guard model.autoScroll, let line = model.currentEvent?.lineIndex else { return }
                    try? await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled else { return }
                    proxy.scrollTo(line, anchor: .center)
                }
                .onChange(
                    of:
                        model
                            .currentEvent?
                            .lineIndex
                ) {
                    line in

                    guard
                        model.autoScroll,
                        !model
                            .calibrationMode,
                        let line
                    else {
                        return
                    }

                    withAnimation(
                        .easeOut(
                            duration: 0.16
                        )
                    ) {
                        proxy.scrollTo(
                            line,
                            anchor: .center
                        )
                    }
                }
            }
            .safeAreaInset(edge: .trailing, spacing: 0) {
                if musicPanelPresented {
                    HStack(spacing: 0) {
                        Divider()
                        ScrollView {
                            musicPanel(chart).padding(compact ? 12 : 16)
                        }
                        .frame(width: compact ? 260 : 320)
                    }
                }
            }
            .frame(minHeight: 0, maxHeight: .infinity)
            .clipped()

            transport
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear { musicPanelPresented = !compact && model.youtubeVideoID != nil }
            .onChange(of: compact) { small in
                if small && !playbackActive { setMusicPanelPresented(false) }
            }
        }
    }

    private func header(
        _ chart: ChordChart
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(chart.title)
                    .font(.system(size: 24, weight: .bold))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                if !chart.artist
                    .isEmpty {
                    Text(
                        chart.artist
                    )
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                }
            }

            HStack(
                spacing: 12
            ) {
                if let key =
                    chart.key {
                    Text("キー \(key)")
                }

                Text(
                    "\(model.bpm) BPM"
                )

                Text(
                    "\(chart.beatsPerBar)/\(chart.beatUnit)"
                )

                Text(
                    "\(model.timeline?.barNumber(atBeat: model.currentBeat) ?? 1)小節目"
                )

                if let url =
                    chart.sourceURL {
                    Link(
                        chart.sourceName,
                        destination:
                            url
                    )
                }
            }
            .font(.caption)
            .foregroundStyle(
                .secondary
            )

            ChartFingeringContext(chart: chart)
        }
        .padding(
            .horizontal,
            22
        )
        .padding(
            .vertical,
            13
        )
    }

    private var currentPositionBar:
        some View {
        HStack(
            spacing: 16
        ) {
            if let remaining = model.countInRemaining {
                MacStatusPill(text: "あと\(remaining)拍で開始", systemImage: "metronome", role: .neutral)
            }
            LabeledContent(
                "現在"
            ) {
                Text(
                    model
                        .currentEvent?
                        .symbol
                    ?? "—"
                )
                .fontWeight(
                    .semibold
                )
            }

            if let status =
                model.syncStatus {
                MacStatusPill(
                    text:
                        syncPrecisionText(
                            status.precision
                        ),
                    systemImage:
                        status.anchorCount >= 3
                        ? "point.3.connected.trianglepath.dotted"
                        : "scope",
                    role:
                        status.anchorCount >= 2
                        ? .success
                        : .neutral
                )

                if status.anchorCount >= 2 {
                    Text(
                        String(
                            format:
                                "局所 %.1f BPM",
                            status.localBPM
                        )
                    )
                    .font(
                        .caption
                            .monospacedDigit()
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Spacer()

            if model.calibrationMode {
                MacStatusPill(
                    text:
                        "コードをクリックして同期アンカーを追加",
                    systemImage:
                        "scope",
                    role: .warning
                )
            }
        }
        .padding(
            .horizontal,
            22
        )
        .padding(
            .vertical,
            9
        )
    }

    private var transport:
        some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: togglePlayback) {
                    Label(playbackActive ? "一時停止" : "再生", systemImage: playbackActive ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                Button(musicPanelPresented ? "音楽を閉じて停止" : "音楽", systemImage: "music.note") {
                    setMusicPanelPresented(!musicPanelPresented)
                }
                .help("音楽パネルを閉じると動画再生も停止します。")
                Button("30秒の切替練習", systemImage: "arrow.left.arrow.right") {
                    youtubeController.pause()
                    model.stop()
                    coachPresented = true
                }
                .help("この曲のコード切替を取り出し、残せる指を確認して短く反復します。マイク不要。")
                if let chart = model.chart, let onPractice {
                    Button("演奏判定", systemImage: "guitars") {
                        let request = ChartPracticeRequest(chart: chart, beat: model.currentBeat, bpm: model.bpm)
                        youtubeController.pause()
                        model.stop()
                        onPractice(request)
                    }
                }
                Spacer(minLength: 0)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { practiceControls }
                VStack(alignment: .leading, spacing: 6) { practiceControls }
            }
            Slider(
                value:
                    Binding(
                        get: {
                            model
                                .currentBeat
                        },
                        set: {
                            target in

                            model.seek(
                                beat: target
                            )

                            if model
                                .youtubeSyncEnabled {
                                youtubeController
                                    .seek(
                                        toMilliseconds:
                                            model
                                                .videoPosition(
                                                    forBeat:
                                                        target
                                                )
                                    )
                            }
                        }
                    ),
                in:
                    0...max(
                        model
                            .timeline?
                            .totalBeats
                        ?? 0,
                        0.01
                    )
            )

            HStack {
                Text(
                    formatTime(
                        model
                            .youtubeSyncEnabled
                        ? model
                            .youtubePositionMs
                        : model.timeline?
                            .milliseconds(
                                forBeat:
                                    model
                                        .currentBeat,
                                bpm:
                                    model.bpm
                            )
                            ?? 0
                    )
                )

                Spacer()

                Text(
                    model
                        .currentEvent?
                        .symbol
                    ?? "—"
                )
                .fontWeight(
                    .medium
                )

                Spacer()

                Text(
                    formatTime(
                        model
                            .youtubeSyncEnabled &&
                        model
                            .youtubeDurationMs >
                        0
                        ? model
                            .youtubeDurationMs
                        : model.timeline?
                            .milliseconds(
                                forBeat:
                                    model
                                        .timeline?
                                        .totalBeats
                                    ?? 0,
                                bpm:
                                    model.bpm
                            )
                            ?? 0
                    )
                )
            }
            .font(
                .caption
                    .monospacedDigit()
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding(
            .horizontal,
            18
        )
        .padding(
            .vertical,
            8
        )
        .macGlassSurface()
    }

    private var practiceControls: some View {
        Group {
            Toggle("カウントイン", isOn: $model.countInEnabled)
                .help("再生前に1小節の拍を数えます。")
            Picker("速度", selection: Binding(
                get: { model.youtubeVideoID != nil ? model.youtubePlaybackRate : model.internalPlaybackRate },
                set: { rate in
                    if model.youtubeVideoID != nil { youtubeController.setPlaybackRate(rate) }
                    else { model.setInternalPlaybackRate(rate) }
                }
            )) {
                ForEach(model.youtubeVideoID != nil ? youtubeController.availablePlaybackRates : [0.5, 0.75, 1.0], id: \.self) { rate in
                    Text(String(format: "%g×", rate)).tag(rate)
                }
            }
            .frame(width: 115)
            Toggle("区間リピート", isOn: Binding(get: { model.loopEnabled }, set: model.setLoopEnabled))
            Menu("区間設定") {
                Button("ここから4小節") {
                    model.useFourBarLoop()
                    if let range = model.practiceLoop { seekPlayback(to: range.startBeat) }
                }
                Button("現在位置をA（開始）に設定", action: model.setLoopStart)
                Button("現在位置をB（終了）に設定", action: model.setLoopEnd)
                    .disabled(model.currentBeat <= (model.practiceLoop?.startBeat ?? 0))
            }
            if model.loopEnabled, let range = model.practiceLoop {
                let bar = Double(model.timeline?.beatsPerBar ?? 4)
                Text("\(Int(floor(range.startBeat / bar)) + 1)〜\(Int(ceil(range.endBeat / bar)))小節")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .help(String(format: "A %.1f拍 → B %.1f拍", range.startBeat, range.endBeat))
            }
        }
        .font(.caption)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func setMusicPanelPresented(_ presented: Bool) {
        if !presented {
            youtubeController.pause()
            model.stop()
        }
        musicPanelPresented = presented
    }

    private func seekPlayback(to beat: Double) {
        model.seek(beat: beat)
        if model.youtubeSyncEnabled {
            youtubeController.seek(toMilliseconds: model.videoPosition(forBeat: beat))
        }
    }

    private func togglePlayback() {
        if playbackActive {
            youtubeController.pause()
            model.stop()
            return
        }
        if model.youtubeVideoID != nil {
            musicPanelPresented = true
        }
        model.beginPlayback {
            if model.youtubeVideoID != nil {
                if model.youtubeSyncEnabled {
                    youtubeController.seek(toMilliseconds: model.videoPosition(forBeat: model.currentBeat))
                }
                youtubeController.play()
            } else {
                model.startInternal()
            }
        }
    }

    private func musicPanel(_ chart: ChordChart) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("音楽と一緒に練習", systemImage: "music.note")
                .font(.headline)

            if let videoID = model.youtubeVideoID {
                YouTubePlayerView(
                    videoID: videoID,
                    controller: youtubeController,
                    initialPositionMs: model.youtubePositionMs,
                    initialPlaybackRate: model.youtubePlaybackRate,
                    onProgress: { position, duration, playing, rate in
                        guard model.youtubeVideoID == videoID else { return }
                        model.onYouTubeProgress(
                            positionMs: position,
                            durationMs: duration,
                            playing: playing,
                            rate: rate
                        )
                    },
                    onUnavailable: {
                        guard model.youtubeVideoID == videoID else { return }
                        model.musicUnavailable()
                    }
                )
                .id(videoID)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(chart.youtubeVideoID == videoID ? "譜面の動画リンク" : "指定したYouTube動画")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("音楽に合わせて譜面を進める", isOn: Binding(
                    get: { model.youtubeSyncEnabled },
                    set: model.setYouTubeSync
                ))

                Text("譜面の進む位置はテンポからの推定です。曲の前奏や間奏でずれることがあります。合わないときは右上の設定で位置を調整してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link("YouTubeで開く", destination: URL(string: "https://www.youtube.com/watch?v=\(videoID)")!)
            } else {
                Text("この譜面にはYouTubeの動画リンクが見つかりませんでした。")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("YouTube URLで音楽を指定")
                .font(.subheadline.weight(.medium))
            TextField("https://www.youtube.com/watch?v=…", text: $musicURL)
                .textFieldStyle(.roundedBorder)
                .onSubmit(loadMusicURL)
                .accessibilityLabel("再生するYouTube URL")
            Button("読み込む", action: loadMusicURL)
                .disabled(musicURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let message = model.musicMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .onDisappear {
            youtubeController.pause()
            model.stop()
        }
    }

    private func loadMusicURL() {
        if YouTubeLink.videoID(in: musicURL) != nil {
            youtubeController.pause()
            youtubeController.seek(toMilliseconds: 0)
        }
        model.attachMusicURL(musicURL)
    }

    @ViewBuilder
    private func inspector(
        _ chart: ChordChart
    ) -> some View {
        Form {
            if model.youtubeVideoID != nil {
                Section(
                    "YouTube"
                ) {
                    Toggle(
                        "動画と譜面を同期",
                        isOn:
                            Binding(
                                get: {
                                    model
                                        .youtubeSyncEnabled
                                },
                                set: {
                                    model
                                        .setYouTubeSync(
                                            $0
                                        )
                                }
                            )
                    )

                    LabeledContent(
                        "開始オフセット"
                    ) {
                        HStack {
                            Button {
                                model
                                    .setYouTubeOffset(
                                        model
                                            .youtubeOffsetMs -
                                        500
                                    )
                            } label: {
                                Image(
                                    systemName:
                                        "minus"
                                )
                            }

                            Text(
                                String(
                                    format:
                                        "%+.1f s",
                                    Double(
                                        model
                                            .youtubeOffsetMs
                                    ) /
                                    1_000
                                )
                            )
                            .monospacedDigit()

                            Button {
                                model
                                    .setYouTubeOffset(
                                        model
                                            .youtubeOffsetMs +
                                        500
                                    )
                            } label: {
                                Image(
                                    systemName:
                                        "plus"
                                )
                            }
                        }
                    }
                }

                Section(
                    "同期アンカー"
                ) {
                    Toggle(
                        "アンカー調整",
                        isOn:
                            Binding(
                                get: {
                                    model
                                        .calibrationMode
                                },
                                set: {
                                    model
                                        .setCalibrationMode(
                                            $0
                                        )
                                }
                            )
                    )

                    if let notice =
                        model.syncNotice {
                        Text(notice)
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .secondary
                            )
                    }

                    ForEach(
                        model.anchors
                    ) {
                        anchor in

                        HStack {
                            VStack(
                                alignment:
                                    .leading
                            ) {
                                Text(
                                    anchor
                                        .symbol
                                )
                                .fontWeight(
                                    .semibold
                                )

                                Text(
                                    "\(formatTime(anchor.videoPositionMs)) · beat \(formatBeat(anchor.chartBeat))"
                                )
                                .font(
                                    .caption
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }

                            Spacer()

                            Button {
                                model
                                    .nudgeAnchor(
                                        anchor,
                                        deltaMs:
                                            -50
                                    )
                            } label: {
                                Image(
                                    systemName:
                                        "minus"
                                )
                            }

                            Button {
                                model
                                    .nudgeAnchor(
                                        anchor,
                                        deltaMs:
                                            50
                                    )
                            } label: {
                                Image(
                                    systemName:
                                        "plus"
                                )
                            }

                            Button(
                                role:
                                    .destructive
                            ) {
                                model
                                    .removeAnchor(
                                        anchor
                                    )
                            } label: {
                                Image(
                                    systemName:
                                        "trash"
                                )
                            }
                        }
                    }

                    if !model
                        .anchors
                        .isEmpty {
                        Button(
                            "全アンカーをリセット",
                            role:
                                .destructive
                        ) {
                            model
                                .clearAnchors()
                        }
                    }
                }
            }

            Section(
                "再生"
            ) {
                LabeledContent(
                    "BPM"
                ) {
                    Stepper(
                        "\(model.bpm)",
                        value:
                            $model.bpm,
                        in: 30...300
                    )
                }

                Toggle(
                    "メトロノーム",
                    isOn:
                        Binding(
                            get: {
                                model
                                    .metronomeEnabled
                            },
                            set: {
                                model
                                    .setMetronome(
                                        $0
                                    )
                            }
                        )
                )

                Toggle(
                    "自動スクロール",
                    isOn:
                        $model
                            .autoScroll
                )
            }
        }
        .formStyle(.grouped)
    }

    private var usedChordSymbols: [String] {
        guard let chart = model.chart else { return [] }
        var seen = Set<String>()
        return chart.lines.flatMap(\.segments).compactMap(\.chord).compactMap { symbol in
            let value = ChordFingeringPresentation(symbol: symbol)
            guard value.availability != .noChord, seen.insert(value.symbol).inserted else { return nil }
            return value.symbol
        }
    }

    private var usedChordShapes:
        some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup(isExpanded: $chordSummaryExpanded) {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(usedChordSymbols, id: \.self) { symbol in
                            GroupBox {
                                ChordFingeringView(symbol: symbol, compact: true)
                                .frame(width: 128)
                                .padding(4)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            } label: {
                Text("使用コード・押さえ方一覧（\(usedChordSymbols.count)種類）")
                    .font(.headline)
            }

            if let onLearnChords, !learnableChordSymbols.isEmpty {
                Button("この曲のコードを覚える", systemImage: "brain") {
                    model.stop()
                    youtubeController.pause()
                    onLearnChords(learnableChordSymbols, "\(model.chart?.title ?? "この曲")のコード")
                }
                .buttonStyle(.bordered)
                .help("音楽を止めて、この曲のコードを図なしで思い出す練習へ")
            }
            ChordFingerLegend()
        }
    }

    private var learnableChordSymbols: [String] {
        guard let timeline = model.timeline else { return [] }
        var seen = Set<String>()
        return timeline.events.compactMap { event in
            guard event.isPlayable,
                  ChordFingeringPresentation(symbol: event.symbol).availability == .supported,
                  let key = GuitarChordData.selectionKey(for: event.symbol), seen.insert(key).inserted else { return nil }
            return event.symbol
        }
    }

    private func syncPrecisionText(
        _ precision:
            ChordSyncPrecision
    ) -> String {
        switch precision {
        case .bpmOnly:
            "BPM推定"
        case .offsetLocked:
            "1点固定"
        case .globalWarp:
            "全体補正"
        case .piecewiseWarp:
            "区間補正"
        }
    }

    private func formatTime(
        _ milliseconds: Int64
    ) -> String {
        let seconds =
            max(
                milliseconds,
                0
            ) /
            1_000

        return String(
            format:
                "%d:%02d",
            seconds / 60,
            seconds % 60
        )
    }

    private func formatBeat(
        _ beat: Double
    ) -> String {
        if abs(
            beat -
            beat.rounded()
        ) <
            0.001 {
            return "\(Int(beat.rounded()))"
        }

        return String(
            format:
                "%.2f",
            beat
        )
    }
}

private struct ViewerChartLine:
    View {

    let line: ChartLine
    let lineIndex: Int
    let activeEvent:
        TimedChordEvent?
    let anchors:
        [ChordSyncAnchor]
    let calibrationMode:
        Bool
    let events:
        [TimedChordEvent]
    let previousSymbols: [Int: String]
    let onAnchor:
        (TimedChordEvent) -> Void

    var body: some View {
        switch line.kind {
        case .blank:
            Spacer()
                .frame(height: 8)

        case .comment:
            Text(
                line.segments
                    .map(\.text)
                    .joined()
            )
            .font(.headline)
            .foregroundStyle(
                .secondary
            )
            .padding(
                .vertical,
                5
            )

        case .content:
            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(
                    alignment: .top,
                    spacing: 0
                ) {
                ForEach(
                    Array(
                        line.segments
                            .enumerated()
                    ),
                    id: \.offset
                ) {
                    segmentIndex,
                    segment in

                    let event =
                        events.first {
                            $0.segmentIndex ==
                            segmentIndex
                        }

                    let anchored =
                        anchors.contains {
                            $0.lineIndex ==
                            lineIndex &&
                            $0.segmentIndex ==
                            segmentIndex
                        }

                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        if let chord = segment.chord {
                            InlineChordFingering(
                                chord: chord, previousSymbol: previousSymbols[segmentIndex]
                            )
                        } else {
                            Color.clear
                                .frame(
                                    width: 1,
                                    height: InlineChordFingering.height
                                )
                        }

                        if let chord =
                            segment.chord {
                            Button {
                                if
                                    calibrationMode,
                                    let event {
                                    onAnchor(
                                        event
                                    )
                                }
                            } label: {
                                Text(chord)
                                    .font(
                                        .system(
                                            .body,
                                            design:
                                                .monospaced
                                        )
                                    )
                                    .fontWeight(
                                        .semibold
                                    )
                                    .padding(
                                        .horizontal,
                                        5
                                    )
                                    .padding(
                                        .vertical,
                                        2
                                    )
                                    .background(
                                        chordBackground(
                                            segmentIndex:
                                                segmentIndex,
                                            anchored:
                                                anchored
                                        ),
                                        in:
                                            RoundedRectangle(
                                                cornerRadius:
                                                    5
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(
                                calibrationMode &&
                                event == nil
                            )
                        } else {
                            Text(" ")
                        }

                        Text(
                            segment.text
                                .isEmpty
                            ? " "
                            : segment.text
                        )
                        .font(
                            .system(
                                .body,
                                design:
                                    .monospaced
                            )
                        )
                        .fixedSize(
                            horizontal: true,
                            vertical: false
                        )
                    }
                }
                .padding(
                    .vertical,
                    2
                )
            }
        }
        }
    }

    private func chordBackground(
        segmentIndex: Int,
        anchored: Bool
    ) -> Color {
        if activeEvent?
            .lineIndex ==
            lineIndex &&
            activeEvent?
                .segmentIndex ==
            segmentIndex {
            return Color
                .accentColor
                .opacity(0.18)
        }

        if anchored {
            return Color
                .orange
                .opacity(0.18)
        }

        return .clear
    }
}
