import SwiftUI

struct MetronomeView:
    View {

    @StateObject
    private var model =
        MetronomeModel()

    @StateObject
    private var outputRoute =
        AudioOutputRouteModel()

    var body: some View {
        Form {
            if outputRoute
                .isBluetooth {
                Section {
                    Label(
                        "Bluetooth出力は音声遅延が大きいため、クリックと実際の発音にズレが出ることがあります。有線またはオーディオインターフェース出力を推奨します。",
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(
                        .orange
                    )
                }
            }

            Section(
                "Tempo"
            ) {
                HStack(
                    alignment: .center,
                    spacing: 22
                ) {
                    Button("-5") {
                        model.changeBpm(-5)
                    }
                    .help("5 BPM下げる")

                    Button {
                        model.changeBpm(-1)
                    } label: {
                        Image(
                            systemName:
                                "minus"
                        )
                    }
                    .help("1 BPM下げる")

                    Text(
                        "\(model.bpm)"
                    )
                    .font(
                        .system(
                            size: 64,
                            weight: .semibold,
                            design:
                                .rounded
                        )
                    )
                    .monospacedDigit()

                    Text("BPM")
                        .foregroundStyle(
                            .secondary
                        )

                    Button {
                        model.changeBpm(1)
                    } label: {
                        Image(
                            systemName:
                                "plus"
                        )
                    }
                    .help("1 BPM上げる")

                    Button("+5") {
                        model.changeBpm(5)
                    }
                    .help("5 BPM上げる")

                    Spacer()

                    Button(
                        "Tap"
                    ) {
                        model.registerTap()
                    }
                    .keyboardShortcut(
                        "t",
                        modifiers: []
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
                    .buttonStyle(
                        .borderedProminent
                    )
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
            }

            Section(
                "拍子"
            ) {
                HStack {
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
                        "Beat Unit",
                        selection:
                            Binding(
                                get: {
                                    model.beatUnit
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
                    .frame(
                        width: 120
                    )
                }

                HStack(
                    spacing: 8
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
                            VStack {
                                Text(
                                    model
                                        .accents[
                                            index
                                        ]
                                        .symbol
                                )
                                .font(
                                    .title2
                                )

                                Text(
                                    "\(index + 1)"
                                )
                                .font(
                                    .caption
                                )
                            }
                            .frame(
                                minWidth: 38
                            )
                            .foregroundStyle(
                                model
                                    .currentBeat ==
                                index
                                ? Color
                                    .accentColor
                                : Color.primary
                            )
                        }
                        .buttonStyle(
                            .borderless
                        )
                    }
                }

                if model.isCountIn {
                    Label(
                        "Count-in",
                        systemImage:
                            "hourglass"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Section(
                "Subdivision"
            ) {
                Picker(
                    "Subdivision",
                    selection:
                        $model
                            .subdivision
                ) {
                    ForEach(
                        MacMetronomeSubdivision
                            .allCases
                    ) {
                        Text($0.label)
                            .tag($0)
                    }
                }
                .pickerStyle(
                    .segmented
                )
            }

            Section(
                "Click"
            ) {
                Picker(
                    "Sound",
                    selection:
                        $model
                            .clickSound
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
                        $model
                            .countInBars,
                    in: 0...4
                )
            }

            Section(
                "Speed Trainer"
            ) {
                Toggle(
                    "Speed Trainer",
                    isOn:
                        $model
                            .speedTrainerEnabled
                )

                LabeledContent(
                    "Start"
                ) {
                    Stepper(
                        "\(model.speedStartBpm) BPM",
                        value:
                            $model
                                .speedStartBpm,
                        in: 30...300
                    )
                }

                LabeledContent(
                    "End"
                ) {
                    Stepper(
                        "\(model.speedEndBpm) BPM",
                        value:
                            $model
                                .speedEndBpm,
                        in: 30...300
                    )
                }

                LabeledContent(
                    "Step"
                ) {
                    Stepper(
                        "+\(model.speedStepBpm) BPM",
                        value:
                            $model
                                .speedStepBpm,
                        in: 1...20
                    )
                }

                LabeledContent(
                    "Every"
                ) {
                    Stepper(
                        "\(model.speedBarsPerStep) bars",
                        value:
                            $model
                                .speedBarsPerStep,
                        in: 1...16
                    )
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(
            "メトロノーム"
        )
        .onDisappear {
            model.stop()
        }
    }
}
