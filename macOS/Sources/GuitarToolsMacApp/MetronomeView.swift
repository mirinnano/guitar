import SwiftUI

struct MetronomeView:
    View {

    @StateObject
    private var model =
        MetronomeModel()

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
                spacing: 20
            ) {
                MacPageHeader(
                    "メトロノーム",
                    subtitle:
                        "テンポ、拍子、アクセントを一画面で調整します。"
                ) {
                    if model.isCountIn {
                        MacStatusPill(
                            text: "Count-in",
                            systemImage:
                                "hourglass",
                            role: .neutral
                        )
                    } else if model.isPlaying {
                        MacStatusPill(
                            text: "Playing",
                            systemImage:
                                "play.fill",
                            role: .success
                        )
                    }
                }

                tempoHero

                LazyVGrid(
                    columns:
                        settingsColumns,
                    alignment: .leading,
                    spacing: 16
                ) {
                    rhythmSection
                    clickSection
                    speedTrainerSection
                }
            }
            .padding(26)
            .macPageWidth(1_100)
        }
        .navigationTitle(
            "メトロノーム"
        )
        .toolbar {
            ToolbarItemGroup(
                placement:
                    .primaryAction
            ) {
                Button(
                    "Tap"
                ) {
                    model.registerTap()
                }
                .keyboardShortcut(
                    "t",
                    modifiers: []
                )
                .help(
                    "Tap Tempo"
                )

                Button {
                    model.toggle()
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
                .help(
                    model.isPlaying
                    ? "メトロノームを停止"
                    : "メトロノームを開始"
                )
            }
        }
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
                    .font(.title2)
                }
                .buttonStyle(.plain)
                .help("-5 BPM")

                Button {
                    model.changeBpm(-1)
                } label: {
                    Image(
                        systemName:
                            "minus"
                    )
                }
                .help("-1 BPM")

                VStack(
                    spacing: 0
                ) {
                    Text(
                        "\(model.bpm)"
                    )
                    .font(
                        .system(
                            size: 76,
                            weight: .semibold,
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
                .help("+1 BPM")

                Button {
                    model.changeBpm(5)
                } label: {
                    Image(
                        systemName:
                            "plus.circle"
                    )
                    .font(.title2)
                }
                .buttonStyle(.plain)
                .help("+5 BPM")
            }

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

            beatIndicator
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
        .background(
            .quaternary.opacity(0.18),
            in:
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
        )
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

        MacSection(
            "リズム",
            subtitle:
                "拍子・サブディビジョン・拍ごとのアクセント"
        ) {
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
                    "Subdivision",
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

                    HStack(
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

        MacSection(
            "クリック",
            subtitle:
                "音色とカウントイン"
        ) {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                Picker(
                    "Sound",
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
                    "Count-in: \(model.countInBars) bars",
                    value:
                        $model.countInBars,
                    in: 0...4
                )

                MacMetric(
                    "Current meter",
                    value:
                        "\(model.beatsPerBar)/\(model.beatUnit)",
                    detail:
                        model.subdivision.label,
                    systemImage:
                        "music.note"
                )
            }
        }
    }

    private var speedTrainerSection:
        some View {

        MacSection(
            "Speed Trainer",
            subtitle:
                "一定小節ごとにテンポを上げる反復練習"
        ) {
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                Toggle(
                    "Speed Trainer",
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
                        "Start",
                        value:
                            $model
                                .speedStartBpm,
                        suffix: "BPM",
                        range: 30...300
                    )

                    trainerRow(
                        "End",
                        value:
                            $model
                                .speedEndBpm,
                        suffix: "BPM",
                        range: 30...300
                    )

                    trainerRow(
                        "Step",
                        value:
                            $model
                                .speedStepBpm,
                        suffix: "BPM",
                        range: 1...20
                    )

                    trainerRow(
                        "Every",
                        value:
                            $model
                                .speedBarsPerStep,
                        suffix: "bars",
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
                        "Progress",
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
