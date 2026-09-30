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
        "練習"
    case chordFollow =
        "演奏判定"
    case chordDetection =
        "コード判定"
    case roadmap =
        "Mac版"

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
        case .roadmap:
            "swift"
        }
    }
}

struct ContentView: View {

    @StateObject
    private var audio =
        AudioInputModel()

    @StateObject
    private var preferences =
        AppPreferencesStore()

    @State
    private var selection:
        MacTool? =
        .metronome

    var body: some View {
        NavigationSplitView {
            VStack(
                spacing: 0
            ) {
                List(
                    selection: $selection
                ) {
                    Section(
                        "Practice"
                    ) {
                        navigationItem(
                            .metronome
                        )
                        navigationItem(
                            .tuner
                        )
                        navigationItem(
                            .charts
                        )
                        navigationItem(
                            .practice
                        )
                        navigationItem(
                            .chordFollow
                        )
                    }

                    Section(
                        "Reference"
                    ) {
                        navigationItem(
                            .chords
                        )
                        navigationItem(
                            .fretboard
                        )
                    }

                    Section(
                        "Audio"
                    ) {
                        navigationItem(
                            .chordDetection
                        )
                    }

                    Section(
                        "Project"
                    ) {
                        navigationItem(
                            .roadmap
                        )
                    }
                }
                .listStyle(.sidebar)

                Divider()

                audioFooter
            }
            .navigationTitle(
                "Guitar Tools"
            )
            .navigationSplitViewColumnWidth(
                min: 210,
                ideal: 238,
                max: 300
            )
        } detail: {
            detail
        }
        .navigationSplitViewStyle(
            .balanced
        )
        .onAppear {
            audio.selectedChannel =
                preferences
                    .value
                    .audio
                    .selectedChannel
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
                preferencesStore:
                    preferences
            )

        case .chords:
            ChordsView()

        case .charts:
            ChordWikiViewerView()

        case .fretboard:
            FretboardView()

        case .practice:
            ProgressionPracticeView()

        case .chordFollow:
            ChordFollowPracticeView(
                audio: audio,
                preferencesStore:
                    preferences
            )

        case .chordDetection:
            ChordDetectionView(
                audio: audio
            )

        case .roadmap:
            MacRoadmapView()

        case .none:
            ContentUnavailableView(
                "ツールを選択",
                systemImage:
                    "guitars"
            )
        }
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
                        : "waveform.circle"
                )
                .font(.title3)
                .foregroundStyle(
                    audio.isRunning
                    ? Color.accentColor
                    : Color.secondary
                )

                VStack(
                    alignment: .leading,
                    spacing: 1
                ) {
                    Text(
                        audio.isRunning
                        ? "Audio Input"
                        : "Audio Input Off"
                    )
                    .font(
                        .callout
                            .weight(.medium)
                    )

                    Text(
                        audio.isRunning
                        ? audio.inputLabel
                        : "クリックして入力を開始"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)
                }

                Spacer()

                if audio.isRunning {
                    Circle()
                        .fill(
                            audio.clipping
                            ? Color.red
                            : Color.green
                        )
                        .frame(
                            width: 7,
                            height: 7
                        )
                }
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
            10
        )
        .help(
            audio.isRunning
            ? "オーディオ入力を停止"
            : "オーディオ入力を開始"
        )
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
        }
    }
}

private struct MacRoadmapView:
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
                        "Android版の機能をSwiftUIへ移植し、Macではオーディオインターフェース入力を使った演奏解析を追加しています。"
                )

                MacSection(
                    "Android parity"
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        Label(
                            "Metronome / Tuner / Chords / ChordWiki / Fretboard / Practice",
                            systemImage:
                                "checkmark.circle.fill"
                        )

                        Label(
                            "ChordWiki高精度同期・YouTube・自動スクロール",
                            systemImage:
                                "checkmark.circle.fill"
                        )

                        Label(
                            "Audio Interfaceコード判定・演奏タイミング評価",
                            systemImage:
                                "checkmark.circle.fill"
                        )
                    }
                    .foregroundStyle(
                        .secondary
                    )
                }

                MacSection(
                    "方針"
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        Label(
                            "SwiftUIネイティブ",
                            systemImage:
                                "swift"
                        )

                        Label(
                            "オーディオIF入力を練習解析へ利用",
                            systemImage:
                                "cable.connector"
                        )

                        Label(
                            "録音・ミキサー・エフェクト等のDAW機能は持たない",
                            systemImage:
                                "xmark.circle"
                        )
                    }
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .padding(26)
            .macPageWidth(900)
        }
        .navigationTitle(
            "Mac版"
        )
    }
}
