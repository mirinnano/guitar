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
    private var inspectorTab = InspectorTab.chords

    @State
    private var musicURL = ""

    @State private var musicPanelPresented = false
    @State private var coachPresented = false
    @AppStorage("guitar-tools.chart.show-fingerings") private var showFingerings = false
    @AppStorage("guitar-tools.chart.font-size") private var chartFontSize = 20

    private enum InspectorTab: Hashable {
        case chords, settings
    }

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
                    Menu {
                        Button("小さく") { chartFontSize = max(14, chartFontSize - 2) }
                            .disabled(chartFontSize <= 14)
                        Button("大きく") { chartFontSize = min(28, chartFontSize + 2) }
                            .disabled(chartFontSize >= 28)
                        Divider()
                        Button("標準（20）") { chartFontSize = 20 }
                    } label: {
                        Label("文字サイズ", systemImage: "textformat.size")
                    }
                    .accessibilityLabel("文字サイズ")
                    .help("譜面の文字サイズを変更")

                    Button {
                        if inspectorPresented && inspectorTab == .chords {
                            inspectorPresented = false
                        } else {
                            inspectorTab = .chords
                            inspectorPresented = true
                        }
                    } label: {
                        Label("押さえ方", systemImage: "square.grid.2x2")
                    }
                    .help("使用コード・押さえ方のサイドパネルを表示 / 非表示")

                    Button {
                        if inspectorPresented && inspectorTab == .settings {
                            inspectorPresented = false
                        } else {
                            inspectorTab = .settings
                            inspectorPresented = true
                        }
                    } label: {
                        Label(
                            "表示と再生の設定",
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
        .onChange(of: model.chart?.sourceTitle) { title in
            inspectorPresented = title != nil
            if title != nil { inspectorTab = .chords }
        }
        .onChange(of: model.loopRestartRevision) { _ in
            guard model.loopEnabled, model.youtubeSyncEnabled,
                  let range = model.practiceLoop else { return }
            youtubeController.seek(toMilliseconds: model.videoPosition(forBeat: range.startBeat))
            youtubeController.play()
        }
        .onReceive(NotificationCenter.default.publisher(for: .practiceTogglePlayback)) { _ in
            guard model.chart != nil else { return }
            togglePlayback()
        }
        .onReceive(NotificationCenter.default.publisher(for: .practiceReset)) { _ in
            guard model.chart != nil else { return }
            seekPlayback(to: model.loopEnabled ? (model.practiceLoop?.startBeat ?? 0) : 0)
        }
        .onReceive(NotificationCenter.default.publisher(for: .practiceToggleInspector)) { _ in
            guard model.chart != nil else { return }
            inspectorPresented.toggle()
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
                onSearch: model.search,
                recentCharts: model.recentCharts,
                onOpenRecent: model.open,
                onRemoveRecent: model.removeRecentChart
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

            if model.countInRemaining != nil || model.calibrationMode {
                currentPositionBar
                Divider()
            }

            ScrollViewReader {
                proxy in

                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 14
                    ) {
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
                                showFingerings: showFingerings,
                                fontSize: CGFloat(min(max(chartFontSize, 14), 28)),
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
                    .frame(maxWidth: 1_100, alignment: .leading)
                    .padding(28)
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            .center
                    )
                }
                .background(Color(nsColor: .textBackgroundColor))
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    transport
                        .frame(maxWidth: 880)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity)
                }
                .task(id: scrollTrackingID) {
                    guard model.autoScroll, !model.calibrationMode,
                          let line = model.currentLine else { return }
                    if !model.isPlaying && model.scrollRevision == 0 { return }
                    try? await Task.sleep(for: .milliseconds(50))
                    guard !Task.isCancelled else { return }
                    proxy.scrollTo(line.lineIndex, anchor: .center)
                    guard model.isPlaying,
                          let next = model.timeline?.lineTimings.first(where: { $0.startBeat > line.startBeat })
                    else { return }
                    let duration = model.secondsUntilNextLine()
                    guard duration > 0 else { return }
                    withAnimation(.linear(duration: duration)) {
                        proxy.scrollTo(next.lineIndex, anchor: .center)
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

            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear { musicPanelPresented = !compact && model.youtubeVideoID != nil }
            .onChange(of: compact) { small in
                if small && !playbackActive { setMusicPanelPresented(false) }
            }
        }
    }

    private var scrollTrackingID: String {
        [String(model.currentLine?.lineIndex ?? -1), String(model.scrollRevision),
         String(model.isPlaying), String(model.autoScroll), String(model.calibrationMode),
         String(model.youtubeSyncEnabled ? model.youtubePlaybackRate : model.internalPlaybackRate),
         String(model.playbackBPM), String(showFingerings), String(chartFontSize)].joined(separator: ":")
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
                    .font(.system(size: 26, weight: .bold))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                if !chart.artist
                    .isEmpty {
                    Text(
                        chart.artist
                    )
                    .font(.callout)
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
                    "\(Int(model.playbackBPM.rounded())) BPM"
                )

                Text(
                    "\(chart.beatsPerBar)/\(chart.beatUnit)"
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
            .font(.callout)
            .monospacedDigit()
            .foregroundStyle(.secondary)

            ChartFingeringContext(chart: chart)

        }
        .frame(maxWidth: 1_100, alignment: .leading)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(
            .vertical,
            20
        )
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var currentPositionBar: some View {
        HStack {
            if let remaining = model.countInRemaining {
                Text("カウントイン \(remaining)")
                    .monospacedDigit()
            }
            Spacer()
            if model.calibrationMode {
                Text("コードをクリックして同期アンカーを追加")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
    }

    private var transport:
        some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    playbackButtons
                    Spacer(minLength: 12)
                    currentChord
                    Spacer(minLength: 12)
                    HStack(spacing: 12) { practiceControls }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        playbackButtons
                        Spacer(minLength: 8)
                        currentChord
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { practiceControls }
                        VStack(alignment: .leading, spacing: 6) { practiceControls }
                    }
                }
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
            .accessibilityLabel("譜面の再生位置")

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

                Text("\(model.timeline?.barNumber(atBeat: model.currentBeat) ?? 1)小節目")

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
                .callout
                    .monospacedDigit()
            )
            .foregroundStyle(.primary)
        }
        .padding(
            .horizontal,
            18
        )
        .padding(
            .vertical,
            14
        )
        .macGlassSurface(radius: 26)
    }

    private var currentChord: some View {
        Text(model.currentEvent?.symbol ?? "—")
            .font(.system(size: 19, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .accessibilityLabel("現在のコード")
            .accessibilityValue(model.currentEvent?.symbol ?? "なし")
    }

    private var playbackButtons: some View {
        Group {
            Button(action: togglePlayback) {
                Image(systemName: playbackActive ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel(playbackActive ? "一時停止" : "再生")
            .help(playbackActive ? "一時停止（⌘Return）" : "再生（⌘Return）")
            Button(musicPanelPresented ? "音楽を閉じて停止" : "音楽", systemImage: "music.note") {
                setMusicPanelPresented(!musicPanelPresented)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .help("音楽パネルを閉じると動画再生も停止します。")
        }
    }

    private var practiceControls: some View {
        Group {
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
            .labelsHidden()
            .frame(width: 76)
            .help("再生速度")
            Toggle(isOn: Binding(get: { model.loopEnabled }, set: model.setLoopEnabled)) {
                Label("区間リピート", systemImage: "repeat")
            }
            .labelStyle(.iconOnly)
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .help("設定した区間を繰り返す")
            Menu("区間") {
                Button("ここから4小節") {
                    model.useFourBarLoop()
                    if let range = model.practiceLoop { seekPlayback(to: range.startBeat) }
                }
                Button("現在位置をA（開始）に設定", action: model.setLoopStart)
                Button("現在位置をB（終了）に設定", action: model.setLoopEnd)
                    .disabled(model.currentBeat <= (model.practiceLoop?.startBeat ?? 0))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("繰り返す区間の開始・終了位置を設定")
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
            Label("音楽", systemImage: "music.note")
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

                Text("譜面位置は推定です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("前奏や間奏で位置がずれる場合は、表示と再生の設定で開始オフセットや同期アンカーを調整できます。")

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

    private func inspector(_ chart: ChordChart) -> some View {
        VStack(spacing: 0) {
            Picker("サイドパネル", selection: $inspectorTab) {
                Text("コード").tag(InspectorTab.chords)
                Text("設定").tag(InspectorTab.settings)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(16)
            switch inspectorTab {
            case .chords:
                ChartChordSummaryView(chart: chart)
                    .id(chart.sourceURL?.absoluteString ?? chart.sourceTitle)
            case .settings:
                inspectorSettings(chart)
            }
        }
    }

    @ViewBuilder
    private func inspectorSettings(
        _ chart: ChordChart
    ) -> some View {
        Form {
            Section("表示") {
                Toggle("各コードの上に押さえ方を表示", isOn: $showFingerings)
                Stepper("文字サイズ \(chartFontSize)", value: $chartFontSize, in: 14...28, step: 2)
            }
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
                    if let status = model.syncStatus {
                        LabeledContent("同期方式", value: syncPrecisionText(status.precision))
                        if status.anchorCount >= 2 {
                            LabeledContent("局所BPM", value: String(format: "%.1f", status.localBPM))
                        }
                    }
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
                Toggle("カウントイン", isOn: $model.countInEnabled)
                Picker("小節線のない行", selection: Binding(
                    get: { model.unmarkedBarsPerLine },
                    set: model.setUnmarkedBarsPerLine
                )) {
                    Text("自動（\(ChordTimelineBuilder.inferredUnmarkedBars(chart: chart))小節）").tag(Optional<Int>.none)
                    ForEach(1...16, id: \.self) { count in
                        Text("\(count)小節").tag(Optional(count))
                    }
                }
                .help("小節線のない行の長さは推定です。この設定で行あたりの小節数を指定できます。")
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
            Section {
                DisclosureGroup("その他のツール") {
                    Button("コード切替", systemImage: "arrow.left.arrow.right") {
                        youtubeController.pause()
                        model.stop()
                        coachPresented = true
                    }
                    if let onPractice {
                        Button("演奏判定", systemImage: "scope") {
                            let request = ChartPracticeRequest(chart: chart, beat: model.currentBeat, bpm: model.bpm)
                            youtubeController.pause()
                            model.stop()
                            onPractice(request)
                        }
                    }
                    if let onLearnChords, !learnableChordSymbols.isEmpty {
                        Button("コード学習", systemImage: "brain") {
                            model.stop()
                            youtubeController.pause()
                            onLearnChords(learnableChordSymbols, "\(chart.title)のコード")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
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
