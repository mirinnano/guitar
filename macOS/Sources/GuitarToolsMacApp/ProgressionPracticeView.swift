import GuitarToolsCore
import SwiftUI
import UniformTypeIdentifiers

struct ProgressionPracticeView:
    View {

    @StateObject
    private var model =
        ProgressionPracticeModel()

    @State
    private var root =
        GuitarNote.c

    @State
    private var quality =
        GuitarChordQuality.major

    @State
    private var showingImporter =
        false

    @State
    private var showingChordPro =
        false

    @State
    private var showingSongSearch =
        false

    var body: some View {
        VStack(
            spacing: 0
        ) {
            header

            Divider()

            ScrollViewReader {
                proxy in

                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: 18
                    ) {
                        currentChordCard

                        progressionRow

                        controlsGrid
                    }
                    .padding(22)
                }
                .onChange(
                    of:
                        model
                            .currentStepIndex
                ) {
                    index in

                    guard
                        model.autoScroll,
                        model.progression
                            .indices
                            .contains(index)
                    else {
                        return
                    }

                    withAnimation(
                        .easeOut(
                            duration: 0.16
                        )
                    ) {
                        proxy.scrollTo(
                            model
                                .progression[
                                    index
                                ]
                                .id,
                            anchor:
                                .center
                        )
                    }
                }
            }
        }
        .navigationTitle(
            "練習"
        )
        .toolbar {
            ToolbarItemGroup(
                placement:
                    .primaryAction
            ) {
                Button {
                    model
                        .togglePlayback()
                } label: {
                    Label(
                        model.isPlaying
                        ? "停止"
                        : "開始",
                        systemImage:
                            model.isPlaying
                            ? "stop.fill"
                            : "play.fill"
                    )
                }

                Button {
                    model.restart()
                } label: {
                    Label(
                        "最初から",
                        systemImage:
                            "backward.end.fill"
                    )
                }

                Button {
                    showingImporter =
                        true
                } label: {
                    Label(
                        "Backing Track",
                        systemImage:
                            "waveform"
                    )
                }
            }
        }
        .fileImporter(
            isPresented:
                $showingImporter,
            allowedContentTypes:
                [.audio],
            allowsMultipleSelection:
                false
        ) {
            result in

            guard
                case let .success(
                    urls
                ) = result,
                let url =
                    urls.first
            else {
                return
            }

            model
                .loadBackingTrack(
                    url
                )
        }
        .sheet(
            isPresented:
                $showingChordPro
        ) {
            ChordProImportSheet(
                model: model
            )
            .frame(
                width: 620,
                height: 480
            )
        }
        .sheet(
            isPresented:
                $showingSongSearch
        ) {
            SongSearchSheet(
                model: model
            )
            .frame(
                width: 660,
                height: 520
            )
        }
        .onDisappear {
            model.stop()
        }
    }

    private var header:
        some View {
        HStack {
            VStack(
                alignment: .leading
            ) {
                Text(model.title)
                    .font(
                        .title2
                            .weight(
                                .semibold
                            )
                    )

                if !model.artist
                    .isEmpty {
                    Text(model.artist)
                        .foregroundStyle(
                            .secondary
                        )
                }

                if !model.musicalKey
                    .isEmpty {
                    Text(
                        "Key \(model.musicalKey)"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Spacer()

            Stepper(
                "\(model.bpm) BPM",
                value:
                    $model.bpm,
                in: 30...300
            )

            Toggle(
                "自動スクロール",
                isOn:
                    $model.autoScroll
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

    @ViewBuilder
    private var currentChordCard:
        some View {

        if
            model.progression
                .indices
                .contains(
                    model
                        .currentStepIndex
                ) {

            let step =
                model.progression[
                    model
                        .currentStepIndex
                ]

            HStack(
                alignment: .center,
                spacing: 28
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(
                        "Current"
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Text(
                        step.symbol
                    )
                    .font(
                        .system(
                            size: 54,
                            weight: .bold,
                            design:
                                .rounded
                        )
                    )

                    Text(
                        "\(model.beatInStep + 1) / \(step.beats) beats"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                if let shape =
                    CommonGuitarChords
                        .shape(
                            named:
                                step.lookupName
                        ) {
                    ChordShapeDiagram(
                        shape: shape
                    )
                    .frame(
                        width: 180
                    )
                }

                Spacer()
            }
            .padding(18)
            .background(
                .quaternary
                    .opacity(0.25),
                in:
                    RoundedRectangle(
                        cornerRadius: 12
                    )
            )
        }
    }

    private var progressionRow:
        some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text(
                "コード進行"
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
                        Array(
                            model
                                .progression
                                .enumerated()
                        ),
                        id:
                            \.element.id
                    ) {
                        index,
                        step in

                        VStack(
                            spacing: 8
                        ) {
                            Text(
                                step.symbol
                            )
                            .font(
                                .title2
                                    .bold()
                            )

                            if let shape =
                                CommonGuitarChords
                                    .shape(
                                        named:
                                            step.lookupName
                                    ) {
                                ChordShapeDiagram(
                                    shape: shape,
                                    compact: true
                                )
                                .frame(
                                    width: 120
                                )
                            }

                            Stepper(
                                "\(step.beats)拍",
                                value:
                                    Binding(
                                        get: {
                                            step.beats
                                        },
                                        set: {
                                            model
                                                .setStepBeats(
                                                    index:
                                                        index,
                                                    beats:
                                                        $0
                                                )
                                        }
                                    ),
                                in: 1...32
                            )

                            Button(
                                role:
                                    .destructive
                            ) {
                                model
                                    .removeStep(
                                        index
                                    )
                            } label: {
                                Label(
                                    "削除",
                                    systemImage:
                                        "trash"
                                )
                            }
                        }
                        .padding(12)
                        .frame(
                            width: 150
                        )
                        .background(
                            model
                                .currentStepIndex ==
                            index
                            ? Color
                                .accentColor
                                .opacity(
                                    0.13
                                )
                            : Color
                                .secondary
                                .opacity(
                                    0.05
                                ),
                            in:
                                RoundedRectangle(
                                    cornerRadius:
                                        10
                                )
                        )
                        .id(step.id)
                    }
                }
            }
        }
    }

    private var controlsGrid:
        some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: 300
                    )
                )
            ],
            alignment: .leading,
            spacing: 14
        ) {
            GroupBox(
                "コード追加"
            ) {
                VStack(
                    spacing: 10
                ) {
                    Picker(
                        "Root",
                        selection:
                            $root
                    ) {
                        ForEach(
                            GuitarNote
                                .allCases
                        ) {
                            Text(
                                $0.displayName
                            )
                            .tag($0)
                        }
                    }

                    Picker(
                        "Quality",
                        selection:
                            $quality
                    ) {
                        ForEach(
                            GuitarChordQuality
                                .allCases
                        ) {
                            Text(
                                $0.displayName
                            )
                            .tag($0)
                        }
                    }

                    Button(
                        "追加"
                    ) {
                        model
                            .addChord(
                                root: root,
                                quality:
                                    quality
                            )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }
                .padding(5)
            }

            GroupBox(
                "Import / Song"
            ) {
                VStack(
                    spacing: 8
                ) {
                    Button(
                        "ChordProを読み込む"
                    ) {
                        showingChordPro =
                            true
                    }

                    Button(
                        "曲メタデータを検索"
                    ) {
                        showingSongSearch =
                            true
                    }

                    if let song =
                        model.selectedSong {
                        VStack(
                            alignment:
                                .leading
                        ) {
                            Text(
                                song.title
                            )
                            .fontWeight(
                                .semibold
                            )
                            Text(
                                song.artist
                            )
                            .foregroundStyle(
                                .secondary
                            )

                            HStack {
                                if let source =
                                    song.sourceURL {
                                    Link(
                                        song.sourceName,
                                        destination:
                                            source
                                    )
                                }

                                Link(
                                    "ChordWiki",
                                    destination:
                                        chordWikiURL(
                                            song
                                        )
                                )

                                Link(
                                    "U-FRET",
                                    destination:
                                        uFretURL(
                                            song
                                        )
                                )
                            }
                        }
                    }
                }
                .padding(5)
            }

            GroupBox(
                "Backing Track"
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {
                    if model
                        .backingTrackURL !=
                        nil {
                        Text(
                            model
                                .backingTrackTitle
                        )
                        .fontWeight(
                            .semibold
                        )

                        Slider(
                            value:
                                Binding(
                                    get: {
                                        Double(
                                            model
                                                .backingPositionMs
                                        )
                                    },
                                    set: {
                                        model
                                            .seekBackingTrack(
                                                milliseconds:
                                                    Int64(
                                                        $0
                                                    )
                                            )
                                    }
                                ),
                            in:
                                0...max(
                                    Double(
                                        model
                                            .backingDurationMs
                                    ),
                                    1
                                )
                        )

                        Text(
                            "\(formatTime(model.backingPositionMs)) / \(formatTime(model.backingDurationMs))"
                        )
                        .font(
                            .caption
                                .monospacedDigit()
                        )

                        HStack {
                            Button {
                                model
                                    .toggleBackingTrack()
                            } label: {
                                Label(
                                    model
                                        .backingPlaying
                                    ? "一時停止"
                                    : "再生",
                                    systemImage:
                                        model
                                            .backingPlaying
                                        ? "pause.fill"
                                        : "play.fill"
                                )
                            }

                            Button(
                                "停止"
                            ) {
                                model
                                    .stopBackingTrack()
                            }
                        }
                    }

                    Toggle(
                        "Backing trackと進行を同期",
                        isOn:
                            $model
                                .syncBackingTrack
                    )

                    if model
                        .syncBackingTrack {
                        LabeledContent(
                            "Offset"
                        ) {
                            HStack {
                                Slider(
                                    value:
                                        Binding(
                                            get: {
                                                Double(
                                                    model
                                                        .syncOffsetMs
                                                )
                                            },
                                            set: {
                                                model
                                                    .syncOffsetMs =
                                                    Int64(
                                                        $0
                                                    )
                                            }
                                        ),
                                    in:
                                        0...60_000
                                )

                                Text(
                                    String(
                                        format:
                                            "%.1f s",
                                        Double(
                                            model
                                                .syncOffsetMs
                                        ) /
                                        1_000
                                    )
                                )
                                .monospacedDigit()
                            }
                        }
                    }
                }
                .padding(5)
            }
        }
    }

    private func chordWikiURL(
        _ song:
            MacSongSearchResult
    ) -> URL {
        let value =
            song.title
                .addingPercentEncoding(
                    withAllowedCharacters:
                        .urlPathAllowed
                )
            ?? song.title

        return URL(
            string:
                "https://ja.chordwiki.org/wiki/\(value)"
        )!
    }

    private func uFretURL(
        _ song:
            MacSongSearchResult
    ) -> URL {
        let query =
            (
                song.title +
                " " +
                song.artist
            )
            .addingPercentEncoding(
                withAllowedCharacters:
                    .urlQueryAllowed
            )
            ?? song.title

        return URL(
            string:
                "https://www.google.com/search?q=site%3Aufret.jp+\(query)"
        )!
    }

    private func formatTime(
        _ milliseconds:
            Int64
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
}

private struct ChordProImportSheet:
    View {

    @ObservedObject
    var model:
        ProgressionPracticeModel

    @Environment(
        \.dismiss
    )
    private var dismiss

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text(
                "ChordPro Import"
            )
            .font(.title2)

            TextEditor(
                text:
                    $model.importText
            )
            .font(
                .system(
                    .body,
                    design:
                        .monospaced
                )
            )
            .border(
                .quaternary
            )

            HStack {
                Spacer()

                Button(
                    "キャンセル"
                ) {
                    dismiss()
                }

                Button(
                    "読み込む"
                ) {
                    model
                        .importChordPro()
                    dismiss()
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    model
                        .importText
                        .isEmpty
                )
            }
        }
        .padding(20)
    }
}

private struct SongSearchSheet:
    View {

    @ObservedObject
    var model:
        ProgressionPracticeModel

    @AppStorage(
        "getsongbpm.apiKey"
    )
    private var getSongBPMAPIKey =
        ""

    @Environment(
        \.dismiss
    )
    private var dismiss

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text(
                "曲を検索"
            )
            .font(.title2)

            HStack {
                TextField(
                    "曲名・アーティスト",
                    text:
                        $model
                            .searchQuery
                )

                Button(
                    "検索"
                ) {
                    model
                        .searchSongs()
                }
                .disabled(
                    model
                        .searchQuery
                        .isEmpty
                )
            }

            DisclosureGroup(
                "BPM / Key metadata"
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {
                    SecureField(
                        "GetSongBPM API key（任意）",
                        text:
                            $getSongBPMAPIKey
                    )

                    Text(
                        "キーが設定されている場合はGetSongBPMを優先し、BPM・キー・拍子を取得します。未設定または検索失敗時はMusicBrainzへフォールバックします。"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
                .padding(
                    .top,
                    4
                )
            }

            if model
                .isSearching {
                ProgressView()
            }

            List(
                model.searchResults
            ) {
                song in

                Button {
                    model
                        .selectSong(
                            song
                        )
                    dismiss()
                } label: {
                    VStack(
                        alignment: .leading
                    ) {
                        Text(
                            song.title
                        )

                        Text(
                            song.artist
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        HStack(
                            spacing: 8
                        ) {
                            Text(
                                song.sourceName
                            )

                            if let bpm =
                                song.bpm {
                                Text(
                                    "\(bpm) BPM"
                                )
                            }

                            if let key =
                                song.musicalKey {
                                Text(
                                    "Key \(key)"
                                )
                            }

                            if let meter =
                                song.timeSignature {
                                Text(meter)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(
                            .tertiary
                        )
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
    }
}
