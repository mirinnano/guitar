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

    @State
    private var selection:
        MacTool? =
        .metronome

    var body: some View {
        NavigationSplitView {
            List(
                selection: $selection
            ) {
                Section(
                    "Guitar Tools"
                ) {
                    navigationItem(
                        .metronome
                    )
                    navigationItem(
                        .tuner
                    )
                    navigationItem(
                        .chords
                    )
                    navigationItem(
                        .charts
                    )
                    navigationItem(
                        .fretboard
                    )
                    navigationItem(
                        .practice
                    )
                }

                Section(
                    "Audio Interface"
                ) {
                    navigationItem(
                        .chordFollow
                    )
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
            .navigationTitle(
                "Guitar Tools"
            )
            .navigationSplitViewColumnWidth(
                min: 190,
                ideal: 220,
                max: 280
            )
        } detail: {
            switch selection {
            case .metronome:
                MetronomeView()

            case .tuner:
                TunerView(
                    audio: audio
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
                    audio: audio
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
        .navigationSplitViewStyle(
            .balanced
        )
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
                spacing: 18
            ) {
                Text(
                    "Guitar Tools for Mac"
                )
                .font(
                    .largeTitle
                        .bold()
                )

                Text(
                    "Android版の機能をSwiftUIへ移植し、Macではオーディオインターフェース入力を使った演奏解析を追加しています。"
                )

                GroupBox(
                    "Android parity"
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {
                        Label(
                            "Metronome / Tuner / Chords / ChordWiki / Fretboard / Practice",
                            systemImage:
                                "checkmark.circle"
                        )

                        Label(
                            "ChordWiki高精度同期・YouTube・自動スクロール",
                            systemImage:
                                "checkmark.circle"
                        )

                        Label(
                            "Audio Interfaceコード判定・演奏タイミング評価",
                            systemImage:
                                "checkmark.circle"
                        )
                    }
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            .leading
                    )
                    .padding(4)
                }

                GroupBox(
                    "方針"
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 8
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
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            .leading
                    )
                    .padding(4)
                }
            }
            .padding(28)
            .frame(
                maxWidth: 900,
                alignment: .leading
            )
        }
        .navigationTitle(
            "Mac版"
        )
    }
}
