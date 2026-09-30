import SwiftUI

enum MacTool:
    String,
    CaseIterable,
    Identifiable {

    case practice =
        "譜面練習"
    case chordDetection =
        "コード判定"
    case roadmap =
        "Mac版"

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .practice:
            "music.note.list"
        case .chordDetection:
            "waveform.badge.magnifyingglass"
        case .roadmap:
            "guitars"
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
        .practice

    var body: some View {
        NavigationSplitView {
            List(
                selection: $selection
            ) {
                Section(
                    "Practice"
                ) {
                    navigationItem(
                        .practice
                    )
                }

                Section(
                    "Utilities"
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
            case .practice:
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
        ) { _ in
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
                    "Android版の延長線として、譜面・同期・メトロノーム・チューナー・練習支援をSwiftUIで実装します。Macではオーディオインターフェース入力を使い、演奏内容とタイミングの解析を強化します。"
                )

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
                        maxWidth: .infinity,
                        alignment: .leading
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
