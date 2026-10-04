import SwiftUI

struct MetronomeView:
    View {

    @StateObject
    private var model:
        MetronomeModel

    @State private var detailsPresented: Bool

    init(
        preferencesStore:
            AppPreferencesStore
    ) {
        _model =
            StateObject(
                wrappedValue:
                    MetronomeModel(
                        preferencesStore:
                            preferencesStore
                    )
            )
        _detailsPresented = State(initialValue:
            preferencesStore.value.metronome.speedTrainerEnabled
            || preferencesStore.value.metronome.countInBars > 0
        )
    }

    private let settingsColumns = [
        GridItem(
            .adaptive(
                minimum: 320,
                maximum: 520
            ),
            spacing: 16
        )
    ]

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: MacLayout.sectionSpacing
            ) {
                MacPageHeader("メトロノーム") {
                    if model.isCountIn {
                        MacStatusPill(
                            text: "カウントイン",
                            systemImage:
                                "hourglass",
                            role: .neutral
                        )
                    } else if model.isPlaying {
                        MacStatusPill(
                            text: "再生中",
                            systemImage:
                                "play.fill",
                            role: .success
                        )
                    }
                }

                tempoHero

                rhythmSection

                DisclosureGroup(isExpanded: $detailsPresented) {
                    LazyVGrid(columns: settingsColumns, alignment: .leading, spacing: 16) {
                        clickSection
                        speedTrainerSection
                    }
                    .padding(.top, 12)
                } label: {
                    Label("詳細設定", systemImage: "slider.horizontal.3")
                        .font(.headline)
                }
                .padding(.horizontal, 4)
            }
            .padding(MacLayout.pagePadding)
            .macPageWidth(1_100)
        }
        .navigationTitle(
            "メトロノーム"
        )
        .onDisappear {
            model.stop()
        }
    }

    private var tempoHero:
        some View {

        VStack(
            spacing: 18
        ) {
            HStack(
                alignment: .center,
                spacing: 18
            ) {
                Button {
                    model.changeBpm(-5)
                } label: {
                    Image(
                        systemName:
                            "minus.circle"
                    )
                    .font(.body)
                    .frame(width: 18, height: 18)
                }
                .macActionButton()
                .help("-5 BPM")
                .accessibilityLabel("テンポを5 BPM下げる")

                Button {
                    model.changeBpm(-1)
                } label: {
                    Image(
                        systemName:
                            "minus"
                    )
                }
                .macActionButton()
                .help("-1 BPM")
                .accessibilityLabel("テンポを1 BPM下げる")

                VStack(
                    spacing: 0
                ) {
                    Text(
                        "\(model.bpm)"
                    )
                    .font(
                        .system(
                            size: 96,
                            weight: .light,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .contentTransition(
                        .numericText()
                    )

                    Text("BPM")
                        .font(
                            .callout
                                .weight(.medium)
                        )
                        .foregroundStyle(
                            .secondary
                        )
                }
                .frame(
                    minWidth: 180
                )

                Button {
                    model.changeBpm(1)
                } label: {
                    Image(
                        systemName:
                            "plus"
                    )
                }
                .macActionButton()
                .help("+1 BPM")
                .accessibilityLabel("テンポを1 BPM上げる")

                Button {
                    model.changeBpm(5)
                } label: {
                    Image(
                        systemName:
                            "plus.circle"
                    )
                    .font(.body)
                    .frame(width: 18, height: 18)
                }
                .macActionButton()
                .help("+5 BPM")
                .accessibilityLabel("テンポを5 BPM上げる")
            }
            .controlSize(.large)

            Slider(
                value:
                    Binding(
                        get: {
                            Double(
                                model.bpm
                            )
                        },
                        set: {
                            model.bpm =
                                Int($0)
                        }
                    ),
                in: 30...300,
                step: 1
            )
            .frame(
                maxWidth: 620
            )

            .accessibilityLabel("テンポ")
            .accessibilityValue("\(model.bpm) BPM")

            beatIndicator

            HStack(spacing: 12) {
                Button {
                    model.registerTap()
                } label: {
                    Label("Tap Tempo", systemImage: "hand.tap")
                }
                .macActionButton()
                .keyboardShortcut("t", modifiers: [])
                .help("タップの間隔からテンポを設定（T）")

                Button {
                    model.toggle()
                } label: {
                    Label(
                        model.isPlaying ? "停止" : "再生",
                        systemImage: model.isPlaying ? "stop.fill" : "play.fill"
                    )
                    .frame(minWidth: 74)
                }
                .macActionButton(prominent: true)
                .keyboardShortcut(.space, modifiers: [])
                .help("メトロノームを再生 / 停止（Space）")
            }
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(
            .vertical,
            26
        )
        .padding(
            .horizontal,
            30
        )
        .macContentSurface(radius: MacLayout.heroRadius)
    }

    private var beatIndicator:
        some View {

        HStack(
            spacing: 10
        ) {
            ForEach(
                0..<model.beatsPerBar,
                id: \.self
            ) {
                index in

                let active =
                    model.currentBeat ==
                    index &&
                    model.isPlaying

                Circle()
                    .fill(
                        active
                        ? Color.accentColor
                        : Color.secondary
                            .opacity(0.18)
                    )
                    .overlay {
                        if model
                            .accents[
                                index
                            ] ==
                            .mute {
                            Image(
                                systemName:
                                    "xmark"
                            )
                            .font(.caption2)
                            .foregroundStyle(
                                active
                                ? Color.white
                                : Color.secondary
                            )
                        }
                    }
                    .frame(
                        width:
                            index == 0
                            ? 22
                            : 18,
                        height:
                            index == 0
                            ? 22
                            : 18
                    )
                    .animation(
                        .easeOut(
                            duration: 0.08
                        ),
                        value: active
                    )
            }
        }
        .frame(
            minHeight: 24
        )
    }

    private var rhythmSection:
        some View {

        MacSection("リズム") {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                HStack {
                    LabeledContent(
                        "拍子"
                    ) {
                        HStack(
                            spacing: 6
                        ) {
                            Stepper(
                                "\(model.beatsPerBar)",
                                value:
                                    Binding(
                                        get: {
                                            model
                                                .beatsPerBar
                                        },
                                        set: {
                                            model
                                                .setTimeSignature(
                                                    beats: $0,
                                                    unit:
                                                        model
                                                            .beatUnit
                                                )
                                        }
                                    ),
                                in: 1...12
                            )

                            Picker(
                                "",
                                selection:
                                    Binding(
                                        get: {
                                            model
                                                .beatUnit
                                        },
                                        set: {
                                            model
                                                .setTimeSignature(
                                                    beats:
                                                        model
                                                            .beatsPerBar,
                                                    unit: $0
                                                )
                                        }
                                    )
                            ) {
                                ForEach(
                                    [2, 4, 8, 16],
                                    id: \.self
                                ) {
                                    Text(
                                        "/\($0)"
                                    )
                                    .tag($0)
                                }
                            }
                            .labelsHidden()
                            .frame(
                                width: 78
                            )
                        }
                    }
                }

                Picker(
                    "音符",
                    selection:
                        $model.subdivision
                ) {
                    ForEach(
                        MacMetronomeSubdivision
                            .allCases
                    ) {
                        Text($0.label)
                            .tag($0)
                    }
                }
                .pickerStyle(.segmented)

                VStack(
                    alignment: .leading,
                    spacing: 7
                ) {
                    Text(
                        "アクセント"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 38, maximum: 46), spacing: 7)],
                        alignment: .leading,
                        spacing: 7
                    ) {
                        ForEach(
                            0..<model
                                .beatsPerBar,
                            id: \.self
                        ) {
                            index in

                            Button {
                                model
                                    .cycleAccent(
                                        index
                                    )
                            } label: {
                                VStack(
                                    spacing: 2
                                ) {
                                    Text(
                                        model
                                            .accents[
                                                index
                                            ]
                                            .symbol
                                    )
                                    .font(
                                        .headline
                                    )

                                    Text(
                                        "\(index + 1)"
                                    )
                                    .font(.caption2)
                                }
                                .frame(
                                    minWidth: 34
                                )
                            }
                            .buttonStyle(
                                .bordered
                            )
                            .tint(
                                model
                                    .currentBeat ==
                                index &&
                                model.isPlaying
                                ? Color.accentColor
                                : Color.secondary
                            )
                        }
                    }
                }
            }
        }
    }

    private var clickSection:
        some View {

        MacSection("音色とカウントイン") {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                Picker(
                    "音色",
                    selection:
                        $model.clickSound
                ) {
                    ForEach(
                        MacClickSound
                            .allCases
                    ) {
                        Text($0.label)
                            .tag($0)
                    }
                }

                Stepper(
                    "カウントイン: \(model.countInBars) 小節",
                    value:
                        $model.countInBars,
                    in: 0...4
                )

            }
        }
    }

    private var speedTrainerSection:
        some View {

        MacSection(
            "テンポトレーニング",
            subtitle:
                "指定した小節数ごとにテンポを上げる"
        ) {
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                Toggle(
                    "徐々にテンポを上げる",
                    isOn:
                        $model
                            .speedTrainerEnabled
                )

                Grid(
                    alignment: .leading,
                    horizontalSpacing: 16,
                    verticalSpacing: 9
                ) {
                    trainerRow(
                        "開始",
                        value:
                            $model
                                .speedStartBpm,
                        suffix: "BPM",
                        range: 30...300
                    )

                    trainerRow(
                        "目標",
                        value:
                            $model
                                .speedEndBpm,
                        suffix: "BPM",
                        range: 30...300
                    )

                    trainerRow(
                        "増分",
                        value:
                            $model
                                .speedStepBpm,
                        suffix: "BPM",
                        range: 1...20
                    )

                    trainerRow(
                        "間隔",
                        value:
                            $model
                                .speedBarsPerStep,
                        suffix: "小節",
                        range: 1...16
                    )
                }
                .disabled(
                    !model
                        .speedTrainerEnabled
                )

                if model
                    .speedTrainerEnabled {
                    MacMetric(
                        "進捗",
                        value:
                            "\(model.speedCompletedBars) / \(model.speedBarsPerStep)",
                        detail:
                            "次のテンポアップまで",
                        systemImage:
                            "chart.line.uptrend.xyaxis"
                    )
                }
            }
        }
    }

    private func trainerRow(
        _ title: String,
        value: Binding<Int>,
        suffix: String,
        range:
            ClosedRange<Int>
    ) -> some View {

        GridRow {
            Text(title)
                .foregroundStyle(
                    .secondary
                )

            Stepper(
                "\(value.wrappedValue) \(suffix)",
                value: value,
                in: range
            )
        }
    }
}
