import GuitarToolsCore
import SwiftUI

struct ChordWikiViewerView:
    View {

    @StateObject
    private var model =
        ChordWikiViewerModel()

    @StateObject
    private var youtubeController =
        YouTubePlayerController()

    @State
    private var inspectorPresented =
        true

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
                "ChordWikiで検索"
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
                    Button {
                        if model
                            .youtubeSyncEnabled {
                            model
                                .youtubePlaying
                            ? youtubeController
                                .pause()
                            : youtubeController
                                .play()
                        } else {
                            model
                                .toggleInternalPlayback()
                        }
                    } label: {
                        Label(
                            model.isPlaying
                            ? "一時停止"
                            : "再生",
                            systemImage:
                                model.isPlaying
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
        .onDisappear {
            model.stop()
        }
    }

    @ViewBuilder
    private var searchView:
        some View {
        if model.isSearching {
            ProgressView(
                "ChordWikiを検索中"
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        } else if let error =
            model.errorMessage,
            model.results.isEmpty {
            ContentUnavailableView(
                "検索できませんでした",
                systemImage:
                    "exclamationmark.triangle",
                description:
                    Text(error)
            )
        } else if
            model.results.isEmpty {
            ContentUnavailableView(
                "ChordWiki譜面",
                systemImage:
                    "music.note.list",
                description:
                    Text(
                        "ツールバーから曲名・アーティストを検索してください。"
                    )
            )
        } else {
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

                        Text(result.title)

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

    private func chartView(
        _ chart: ChordChart
    ) -> some View {
        VStack(
            spacing: 0
        ) {
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
                        if !usedShapes
                            .isEmpty {
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

            Divider()

            transport
        }
    }

    private func header(
        _ chart: ChordChart
    ) -> some View {
        HStack(
            alignment: .firstTextBaseline
        ) {
            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(chart.title)
                    .font(
                        .title2
                            .weight(
                                .semibold
                            )
                    )

                if !chart.artist
                    .isEmpty {
                    Text(
                        chart.artist
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Spacer()

            HStack(
                spacing: 12
            ) {
                if let key =
                    chart.key {
                    Text("Key \(key)")
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
                        "ChordWiki",
                        destination:
                            url
                    )
                }
            }
            .font(.callout)
            .foregroundStyle(
                .secondary
            )
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
                Text(
                    syncPrecisionText(
                        status.precision
                    )
                )
                .foregroundStyle(
                    .secondary
                )

                if status.anchorCount >= 2 {
                    Text(
                        String(
                            format:
                                "局所 %.1f BPM",
                            status.localBPM
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Spacer()

            if model.calibrationMode {
                Label(
                    "コードをクリックして同期アンカーを追加",
                    systemImage:
                        "scope"
                )
                .foregroundStyle(
                    Color
                        .accentColor
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
        VStack(
            spacing: 4
        ) {
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
        .background(.bar)
    }

    @ViewBuilder
    private func inspector(
        _ chart: ChordChart
    ) -> some View {
        Form {
            if let video =
                chart.youtubeVideoID {
                Section(
                    "YouTube"
                ) {
                    YouTubePlayerView(
                        videoID: video,
                        controller:
                            youtubeController,
                        onProgress: {
                            position,
                            duration,
                            playing,
                            rate in

                            model
                                .onYouTubeProgress(
                                    positionMs:
                                        position,
                                    durationMs:
                                        duration,
                                    playing:
                                        playing,
                                    rate: rate
                                )
                        },
                        onUnavailable: {
                            model
                                .setYouTubeSync(
                                    false
                                )
                        }
                    )
                    .frame(
                        minHeight: 200
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 8
                        )
                    )

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
                    "高精度同期"
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
                "Playback"
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

    private var usedShapes:
        [GuitarChordShape] {
        guard let chart =
            model.chart
        else {
            return []
        }

        let names =
            chart.lines
                .flatMap(\.segments)
                .compactMap(\.chord)

        var seen =
            Set<String>()

        return names
            .compactMap {
                symbol in

                guard
                    let normalized =
                        normalizeChordLookup(
                            symbol
                        ),
                    !seen.contains(
                        normalized
                    )
                else {
                    return nil
                }

                seen.insert(
                    normalized
                )

                return CommonGuitarChords
                    .shape(
                        named:
                            normalized
                    )
            }
    }

    private var usedChordShapes:
        some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text(
                "使用コード / 押さえ方"
            )
            .font(.headline)

            ScrollView(
                .horizontal
            ) {
                HStack(
                    alignment: .top,
                    spacing: 10
                ) {
                    ForEach(
                        usedShapes
                    ) {
                        shape in

                        GroupBox {
                            ChordShapeDiagram(
                                shape: shape,
                                compact: true
                            )
                            .frame(
                                width: 128
                            )
                            .padding(4)
                        }
                    }
                }
            }
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
            }
            .padding(
                .vertical,
                2
            )
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
