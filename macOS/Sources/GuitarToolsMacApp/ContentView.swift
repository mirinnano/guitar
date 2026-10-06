import SwiftUI

enum MacTool:
    String,
    CaseIterable,
    Identifiable {

    case metronome =
        "メトロノーム"
    case tuner =
        "チューナー"
    case chords =
        "コード"
    case charts =
        "譜面"
    case fretboard =
        "指板"
    case practice =
        "コード進行"
    case chordFollow =
        "演奏判定"
    case chordDetection =
        "コード判定"

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .metronome:
            "metronome"
        case .tuner:
            "tuningfork"
        case .chords:
            "guitars"
        case .charts:
            "music.note.list"
        case .fretboard:
            "rectangle.grid.1x2"
        case .practice:
            "repeat"
        case .chordFollow:
            "scope"
        case .chordDetection:
            "waveform.badge.magnifyingglass"
        }
    }
}

struct ContentView: View {

    @StateObject
    private var audio: AudioInputModel

    @StateObject
    private var preferences: AppPreferencesStore

    @StateObject private var output: AudioOutputModel

    @State
    private var selection:
        MacTool? =
        .charts

    @State private var practiceRequest: ChartPracticeRequest?
    @StateObject private var chartModel: ChordWikiViewerModel
    @State private var additionalToolsExpanded = false
    @StateObject private var practiceModel: ChordFollowPracticeModel
    @StateObject private var chordLearning = ChordLearningModel()

    init() {
        let audio = AudioInputModel()
        let preferences = AppPreferencesStore()
        _audio = StateObject(wrappedValue: audio)
        _preferences = StateObject(wrappedValue: preferences)
        _output = StateObject(wrappedValue: AudioOutputModel(preferencesStore: preferences))
        let charts = ChordWikiViewerModel(recentStore: RecentChartsStore(), timingDefaults: .standard)
        charts.countInEnabled = false
        _chartModel = StateObject(wrappedValue: charts)
        _practiceModel = StateObject(wrappedValue: ChordFollowPracticeModel(
            audio: audio, preferencesStore: preferences
        ))
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                navigationItem(.charts)

                Section("ツール") {
                    navigationItem(.tuner)
                    navigationItem(.metronome)
                }

                Section("ライブラリ") {
                    navigationItem(.chords)
                    navigationItem(.fretboard)
                }

                DisclosureGroup("その他のツール", isExpanded: $additionalToolsExpanded) {
                    navigationItem(.practice)
                    navigationItem(.chordFollow)
                    navigationItem(.chordDetection)
                }

            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if selection == .tuner || selection == .chordFollow || selection == .chordDetection
                    || audio.isStartRequested || audio.isRunning {
                    audioFooter
                        .padding(12)
                }
            }
            .navigationTitle(
                "Guitar Tools"
            )
            .navigationSplitViewColumnWidth(
                min: 210,
                ideal: 244,
                max: 300
            )
        } detail: {
            detail
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationSplitViewStyle(
            .balanced
        )
        .onAppear {
            let savedAudio = preferences.value.audio
            audio.configureInput(uid: savedAudio.inputDeviceUID, channel: savedAudio.selectedChannel)
        }
        .onChange(
            of:
                audio.selectedChannel
        ) {
            channel in

            preferences.update {
                value in

                value.audio
                    .selectedChannel =
                    channel
            }
        }
        .onChange(
            of:
                audio.selectedDeviceUID
        ) {
            uid in

            preferences.update {
                value in

                value.audio
                    .inputDeviceUID =
                    uid
            }
        }
        .onReceive(
            NotificationCenter
                .default
                .publisher(
                    for:
                        .toggleAudioInput
                )
        ) {
            _ in

            audio.toggle()
        }
    }

    @ViewBuilder
    private var detail:
        some View {

        switch selection {
        case .metronome:
            MetronomeView(
                preferencesStore:
                    preferences
            )

        case .tuner:
            TunerView(
                audio: audio,
                output: output,
                preferencesStore:
                    preferences
            )

        case .chords:
            ChordsView(learning: chordLearning)

        case .charts:
            ChordWikiViewerView(model: chartModel, onPractice: { request in
                practiceRequest = request
                selection = .chordFollow
            }, onLearnChords: { symbols, title in
                chordLearning.startCustom(symbols: symbols, title: title)
                selection = .chords
            })

        case .fretboard:
            FretboardView()

        case .practice:
            ProgressionPracticeView()

        case .chordFollow:
            ChordFollowPracticeView(
                audio: audio,
                model: practiceModel,
                practiceRequest: practiceRequest,
                onPracticeRequestConsumed: { id in
                    if practiceRequest?.id == id {
                        practiceRequest = nil
                    }
                }
            )

        case .chordDetection:
            ChordDetectionView(
                audio: audio
            )

        case .none:
            ContentUnavailableView(
                "ツールを選択",
                systemImage:
                    "guitars"
            )
        }
    }

    private var audioInputActionTitle: String {
        if audio.isRunning { return "オーディオ入力を停止" }
        return audio.isStartRequested ? "入力開始をキャンセル" : "オーディオ入力を開始"
    }

    private var audioFooter:
        some View {

        Button {
            audio.toggle()
        } label: {
            HStack(
                spacing: 10
            ) {
                Image(
                    systemName:
                        audio.isRunning
                        ? "waveform.circle.fill"
                        : (audio.isStartRequested ? "hourglass.circle" : "waveform.circle")
                )
                .font(.title3)
                .foregroundStyle(
                    audio.isStartRequested
                    ? Color.accentColor
                    : Color.secondary
                )

                VStack(
                    alignment: .leading,
                    spacing: 1
                ) {
                    Text(audioInputActionTitle)
                    .font(
                        .callout
                            .weight(.medium)
                    )

                    Text(audio.inputLabel)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)
                    .truncationMode(.middle)
                }

                Spacer(minLength: 4)

                Image(systemName: audio.isRunning ? "pause.fill" : (audio.isStartRequested ? "xmark" : "play.fill"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(audio.clipping ? .red : .secondary)
            }
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
        .padding(
            .horizontal,
            12
        )
        .padding(
            .vertical,
            12
        )
        .macGlassSurface(radius: 16)
        .help(audioInputActionTitle)
        .accessibilityLabel(audioInputActionTitle)
        .accessibilityValue(audio.inputLabel)
    }

    private func navigationItem(
        _ tool: MacTool
    ) -> some View {
        NavigationLink(
            value: tool
        ) {
            Label(
                tool.rawValue,
                systemImage:
                    tool.systemImage
            )
            .padding(.vertical, 5)
        }
    }
}

struct MacAboutView:
    View {

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 22
            ) {
                MacPageHeader(
                    "Guitar Tools for Mac",
                    subtitle:
                        "譜面、コードの押さえ方、チューナー"
                )

                MacSection(
                    "機能"
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        Label(
                            "メトロノーム、チューナー、コード、譜面、指板、コード進行",
                            systemImage:
                                "checkmark.circle.fill"
                        )

                        Label(
                            "YouTube 再生と譜面の同期、自動スクロール",
                            systemImage:
                                "checkmark.circle.fill"
                        )

                        Label(
                            "入力音からコードと演奏タイミングを判定",
                            systemImage:
                                "checkmark.circle.fill"
                        )
                    }
                    .foregroundStyle(
                        .secondary
                    )
                }

                MacSection(
                    "対応範囲"
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        Label(
                            "SwiftUI による macOS アプリ",
                            systemImage:
                                "swift"
                        )

                        Label(
                            "オーディオインターフェースの入力に対応",
                            systemImage:
                                "cable.connector"
                        )

                        Label(
                            "録音、ミキサー、エフェクトは非対応",
                            systemImage:
                                "xmark.circle"
                        )
                    }
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .padding(MacLayout.pagePadding)
            .macPageWidth(900)
        }
        .navigationTitle(
            "Mac版"
        )
    }
}
