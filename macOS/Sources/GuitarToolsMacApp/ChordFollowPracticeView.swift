import GuitarToolsCore
import SwiftUI

struct ChordFollowPracticeView:
    View {

    @ObservedObject
    private var audio:
        AudioInputModel

    @StateObject
    private var model:
        ChordFollowPracticeModel

    @State
    private var inspectorPresented =
        true

    init(
        audio: AudioInputModel
    ) {
        self.audio = audio

        _model =
            StateObject(
                wrappedValue:
                    ChordFollowPracticeModel(
                        audio: audio
                    )
            )
    }

    var body: some View {
        Group {
            if let chart =
                model.chart {
                practiceCanvas(
                    chart
                )
            } else {
                searchView
            }
        }
        .navigationTitle(
            model.chart?.title
                ?? "譜面練習"
        )
        .searchable(
            text: $model.query,
            placement: .toolbar,
            prompt:
                "ChordWikiで曲名・アーティストを検索"
        )
        .onSubmit(
            of: .search
        ) {
            model.search()
        }
        .toolbar {
            toolbarContent
        }
        .inspector(
            isPresented:
                $inspectorPresented
        ) {
            if model.chart != nil {
                PracticeInspectorView(
                    model: model,
                    audio: audio
                )
                .inspectorColumnWidth(
                    min: 280,
                    ideal: 330,
                    max: 400
                )
            }
        }
        .onReceive(
            NotificationCenter
                .default
                .publisher(
                    for:
                        .practiceTogglePlayback
                )
        ) { _ in
            guard model.chart != nil
            else {
                return
            }

            model.togglePlayback()
        }
        .onReceive(
            NotificationCenter
                .default
                .publisher(
                    for:
                        .practiceReset
                )
        ) { _ in
            guard model.chart != nil
            else {
                return
            }

            model.resetSession()
        }
        .onReceive(
            NotificationCenter
                .default
                .publisher(
                    for:
                        .practiceToggleInspector
                )
        ) { _ in
            guard model.chart != nil
            else {
                return
            }

            inspectorPresented.toggle()
        }
        .overlay {
            if model.isLoadingChart {
                ProgressView()
                    .controlSize(.small)
                    .padding(12)
                    .background(
                        .regularMaterial,
                        in:
                            RoundedRectangle(
                                cornerRadius: 10
                            )
                    )
            }
        }
    }

    @ViewBuilder
    private var searchView:
        some View {

        if model.isSearching {
            VStack(
                spacing: 12
            ) {
                ProgressView()
                    .controlSize(.small)

                Text(
                    "ChordWikiを検索中"
                )
                .foregroundStyle(
                    .secondary
                )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        } else if
            let error =
                model.errorMessage,
            model.searchResults.isEmpty {
            ContentUnavailableView(
                "検索できませんでした",
                systemImage:
                    "exclamationmark.triangle",
                description:
                    Text(error)
            )
        } else if
            model.searchResults.isEmpty {
            ContentUnavailableView(
                "ChordWikiから譜面を検索",
                systemImage:
                    "music.note.list",
                description:
                    Text(
                        "ツールバーの検索欄に曲名またはアーティスト名を入力してください。"
                    )
            )
        } else {
            List(
                model.searchResults
            ) {
                result in

                Button {
                    model.open(result)
                } label: {
                    HStack(
                        spacing: 10
                    ) {
                        Image(
                            systemName:
                                "music.note"
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        VStack(
                            alignment:
                                .leading,
                            spacing: 2
                        ) {
                            Text(
                                result.title
                            )
                            .foregroundStyle(
                                .primary
                            )

                            Text(
                                "ChordWiki"
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
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
                .padding(
                    .vertical,
                    3
                )
            }
        }
    }

    private func practiceCanvas(
        _ chart: ChordChart
    ) -> some View {
        VStack(
            spacing: 0
        ) {
            chartHeader(chart)

            Divider()

            PracticeFeedbackBar(
                expected:
                    model.currentEvent?
                        .symbol,
                pending:
                    model.pendingExpected?
                        .symbol,
                detected:
                    audio.stableChord
                    ?? audio.estimate?
                        .name,
                lastAttempt:
                    model.lastAttempt
            )
            .padding(
                .horizontal,
                22
            )
            .padding(
                .vertical,
                12
            )

            Divider()

            chartScrollView(
                chart
            )

            Divider()

            transport
        }
    }

    private func chartHeader(
        _ chart: ChordChart
    ) -> some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: 16
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
                    Text(
                        "Key \(key)"
                    )
                }

                Text(
                    "\(model.bpm) BPM"
                )

                Text(
                    "\(chart.beatsPerBar)/\(chart.beatUnit)"
                )

                if let url =
                    chart.sourceURL {
                    Link(
                        "ChordWiki",
                        destination: url
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
            14
        )
    }

    private func chartScrollView(
        _ chart: ChordChart
    ) -> some View {
        ScrollViewReader {
            proxy in

            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 7
                ) {
                    ForEach(
                        Array(
                            chart.lines
                                .enumerated()
                        ),
                        id: \.offset
                    ) {
                        lineIndex,
                        line in

                        ChartPracticeLineView(
                            line: line,
                            lineIndex:
                                lineIndex,
                            activeEvent:
                                model.currentEvent
                        )
                        .id(lineIndex)
                    }
                }
                .padding(
                    .horizontal,
                    28
                )
                .padding(
                    .vertical,
                    22
                )
                .frame(
                    maxWidth:
                        .infinity,
                    alignment:
                        .leading
                )
            }
            .onChange(
                of:
                    model.currentEvent?
                        .lineIndex
            ) {
                lineIndex in

                guard
                    model.autoScroll,
                    let lineIndex
                else {
                    return
                }

                withAnimation(
                    .easeOut(
                        duration: 0.18
                    )
                ) {
                    proxy.scrollTo(
                        lineIndex,
                        anchor: .center
                    )
                }
            }
        }
    }

    private var transport:
        some View {

        VStack(
            spacing: 5
        ) {
            Slider(
                value:
                    Binding(
                        get: {
                            model.currentSeconds
                        },
                        set: {
                            model.seek(
                                to: $0
                            )
                        }
                    ),
                in:
                    0...max(
                        model.durationSeconds,
                        0.01
                    )
            )

            HStack {
                Text(
                    formatTime(
                        model.currentSeconds
                    )
                )

                Spacer()

                if let event =
                    model.currentEvent {
                    Text(
                        "現在: \(event.symbol)"
                    )
                    .fontWeight(
                        .medium
                    )
                }

                Spacer()

                Text(
                    formatTime(
                        model.durationSeconds
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
            9
        )
        .background(
            .bar
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent:
        some ToolbarContent {

        if model.chart != nil {
            ToolbarItem(
                placement:
                    .navigation
            ) {
                Button {
                    model.closeChart()
                } label: {
                    Label(
                        "検索へ戻る",
                        systemImage:
                            "chevron.left"
                    )
                }
                .help(
                    "譜面検索へ戻る"
                )
            }

            ToolbarItemGroup(
                placement:
                    .primaryAction
            ) {
                Button {
                    model.togglePlayback()
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
                .help(
                    model.isPlaying
                    ? "練習を一時停止"
                    : "練習を開始"
                )

                Button {
                    model.resetSession()
                } label: {
                    Label(
                        "最初から",
                        systemImage:
                            "backward.end.fill"
                    )
                }
                .help(
                    "練習結果と再生位置をリセット"
                )

                Button {
                    audio.toggle()
                } label: {
                    Label(
                        audio.isRunning
                        ? "入力停止"
                        : "入力開始",
                        systemImage:
                            audio.isRunning
                            ? "waveform.slash"
                            : "waveform"
                    )
                }
                .help(
                    audio.isRunning
                    ? "オーディオ入力を停止"
                    : "オーディオ入力を開始"
                )

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
                .help(
                    "練習インスペクタを表示/非表示"
                )
            }
        }
    }

    private func formatTime(
        _ seconds: Double
    ) -> String {
        let safe =
            max(seconds, 0)

        let minutes =
            Int(safe) / 60

        let remainder =
            Int(safe) % 60

        return String(
            format:
                "%d:%02d",
            minutes,
            remainder
        )
    }
}

private struct PracticeFeedbackBar:
    View {

    let expected: String?
    let pending: String?
    let detected: String?
    let lastAttempt:
        PracticeAttempt?

    var body: some View {
        HStack(
            spacing: 16
        ) {
            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text("期待")
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                Text(
                    pending
                    ?? expected
                    ?? "—"
                )
                .font(
                    .title3
                        .weight(.semibold)
                )
            }
            .frame(
                minWidth: 80,
                alignment: .leading
            )

            Image(
                systemName:
                    "arrow.right"
            )
            .foregroundStyle(
                .tertiary
            )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text("検出")
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                Text(
                    detected ?? "—"
                )
                .font(
                    .title3
                        .weight(.semibold)
                )
            }
            .frame(
                minWidth: 80,
                alignment: .leading
            )

            Divider()
                .frame(height: 34)

            if let attempt =
                lastAttempt {
                harmonyPill(
                    attempt
                )

                timingPill(
                    attempt
                )
            } else {
                MacStatusPill(
                    text: "演奏待ち",
                    systemImage:
                        "waveform",
                    role: .neutral
                )
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func harmonyPill(
        _ attempt:
            PracticeAttempt
    ) -> some View {

        switch attempt.harmony {
        case .correct:
            MacStatusPill(
                text: "コード正解",
                systemImage:
                    "checkmark.circle.fill",
                role: .success
            )

        case .incorrect:
            MacStatusPill(
                text:
                    "\(attempt.playedChord ?? "—") を検出",
                systemImage:
                    "xmark.circle.fill",
                role:
                    .destructive
            )

        case .unrecognized:
            MacStatusPill(
                text: "コード未判定",
                systemImage:
                    "questionmark.circle",
                role: .neutral
            )
        }
    }

    @ViewBuilder
    private func timingPill(
        _ attempt:
            PracticeAttempt
    ) -> some View {

        let milliseconds =
            abs(
                attempt
                    .timingErrorMs
            )

        switch attempt.timing {
        case .early:
            MacStatusPill(
                text:
                    String(
                        format:
                            "%.0f ms 早い",
                        milliseconds
                    ),
                systemImage:
                    "arrow.left.circle",
                role: .warning
            )

        case .onTime:
            MacStatusPill(
                text:
                    String(
                        format:
                            "%.0f ms",
                        milliseconds
                    ),
                systemImage:
                    "scope",
                role: .success
            )

        case .late:
            MacStatusPill(
                text:
                    String(
                        format:
                            "%.0f ms 遅い",
                        milliseconds
                    ),
                systemImage:
                    "arrow.right.circle",
                role: .warning
            )
        }
    }
}

private struct ChartPracticeLineView:
    View {

    let line: ChartLine
    let lineIndex: Int
    let activeEvent:
        TimedChordEvent?

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
            contentLine
        }
    }

    private var contentLine:
        some View {

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

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    if let chord =
                        segment.chord {
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
                                4
                            )
                            .padding(
                                .vertical,
                                2
                            )
                            .background(
                                isActive(
                                    segmentIndex
                                )
                                ? Color
                                    .accentColor
                                    .opacity(0.16)
                                : Color.clear,
                                in:
                                    RoundedRectangle(
                                        cornerRadius:
                                            5
                                    )
                            )
                            .foregroundStyle(
                                isActive(
                                    segmentIndex
                                )
                                ? Color
                                    .accentColor
                                : Color.primary
                            )
                    } else {
                        Text(" ")
                            .font(
                                .system(
                                    .body,
                                    design:
                                        .monospaced
                                )
                            )
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

    private func isActive(
        _ segmentIndex: Int
    ) -> Bool {
        activeEvent?
            .lineIndex ==
            lineIndex &&
        activeEvent?
            .segmentIndex ==
            segmentIndex
    }
}

private struct PracticeInspectorView:
    View {

    @ObservedObject
    var model:
        ChordFollowPracticeModel

    @ObservedObject
    var audio:
        AudioInputModel

    var body: some View {
        Form {
            Section(
                "現在"
            ) {
                LabeledContent(
                    "期待コード",
                    value:
                        model
                            .pendingExpected?
                            .symbol
                        ?? model
                            .currentEvent?
                            .symbol
                        ?? "—"
                )

                LabeledContent(
                    "検出コード",
                    value:
                        audio.stableChord
                        ?? audio.estimate?
                            .name
                        ?? "—"
                )

                if let attempt =
                    model.lastAttempt {
                    LabeledContent(
                        "コード"
                    ) {
                        Text(
                            harmonyText(
                                attempt
                            )
                        )
                    }

                    LabeledContent(
                        "タイミング"
                    ) {
                        Text(
                            timingText(
                                attempt
                            )
                        )
                        .monospacedDigit()
                    }
                }
            }

            Section(
                "Audio Input"
            ) {
                LabeledContent(
                    "状態",
                    value:
                        audio.isRunning
                        ? "入力中"
                        : "停止"
                )

                LabeledContent(
                    "入力",
                    value:
                        audio.inputLabel
                )

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    HStack {
                        Text(
                            "レベル"
                        )

                        Spacer()

                        Text(
                            dbText
                        )
                        .monospacedDigit()
                    }

                    ProgressView(
                        value:
                            levelProgress
                    )
                    .tint(
                        audio.clipping
                        ? .red
                        : .accentColor
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    HStack {
                        Text(
                            "入力遅延補正"
                        )

                        Spacer()

                        Text(
                            String(
                                format:
                                    "%+.0f ms",
                                model
                                    .inputLatencyCompensationMs
                            )
                        )
                        .monospacedDigit()
                    }

                    Slider(
                        value:
                            $model
                                .inputLatencyCompensationMs,
                        in:
                            -100...250,
                        step: 1
                    )
                }
            }

            Section(
                "判定"
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    HStack {
                        Text(
                            "On Time幅"
                        )

                        Spacer()

                        Text(
                            String(
                                format:
                                    "±%.0f ms",
                                model
                                    .onTimeToleranceMs
                            )
                        )
                        .monospacedDigit()
                    }

                    Slider(
                        value:
                            $model
                                .onTimeToleranceMs,
                        in: 40...200,
                        step: 5
                    )
                }

                Toggle(
                    "自動スクロール",
                    isOn:
                        $model
                            .autoScroll
                )
            }

            Section(
                "セッション"
            ) {
                let stats =
                    model.statistics

                LabeledContent(
                    "コード正答率",
                    value:
                        percent(
                            stats
                                .chordAccuracy
                        )
                )

                LabeledContent(
                    "On Time率",
                    value:
                        percent(
                            stats
                                .timingAccuracy
                        )
                )

                LabeledContent(
                    "平均タイミング誤差",
                    value:
                        String(
                            format:
                                "%.0f ms",
                            stats
                                .meanAbsoluteTimingErrorMs
                        )
                )

                LabeledContent(
                    "判定数",
                    value:
                        "\(stats.totalAttempts)"
                )
            }

            if !model.attempts
                .isEmpty {
                Section(
                    "直近の演奏"
                ) {
                    ForEach(
                        model.attempts
                            .suffix(8)
                            .reversed()
                    ) {
                        attempt in

                        VStack(
                            alignment:
                                .leading,
                            spacing: 2
                        ) {
                            HStack {
                                Text(
                                    attempt
                                        .expectedChord
                                )
                                .fontWeight(
                                    .semibold
                                )

                                Spacer()

                                Text(
                                    attempt
                                        .playedChord
                                    ?? "—"
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }

                            Text(
                                timingText(
                                    attempt
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var levelProgress:
        Double {
        min(
            max(
                (
                    audio.levelDBFS +
                    60
                ) / 60,
                0
            ),
            1
        )
    }

    private var dbText: String {
        if audio.levelDBFS <=
            -119 {
            return "−∞ dBFS"
        }

        return String(
            format:
                "%.1f dBFS",
            audio.levelDBFS
        )
    }

    private func harmonyText(
        _ attempt:
            PracticeAttempt
    ) -> String {
        switch attempt.harmony {
        case .correct:
            "正解"
        case .incorrect:
            "別コード"
        case .unrecognized:
            "未判定"
        }
    }

    private func timingText(
        _ attempt:
            PracticeAttempt
    ) -> String {
        switch attempt.timing {
        case .early:
            String(
                format:
                    "%.0f ms 早い",
                abs(
                    attempt
                        .timingErrorMs
                )
            )

        case .onTime:
            String(
                format:
                    "%.0f ms",
                abs(
                    attempt
                        .timingErrorMs
                )
            )

        case .late:
            String(
                format:
                    "%.0f ms 遅い",
                abs(
                    attempt
                        .timingErrorMs
                )
            )
        }
    }

    private func percent(
        _ value: Double
    ) -> String {
        String(
            format:
                "%.0f%%",
            value * 100
        )
    }
}
