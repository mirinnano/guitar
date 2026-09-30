import GuitarToolsCore
import SwiftUI

struct TunerView:
    View {

    @ObservedObject
    var audio: AudioInputModel

    @StateObject
    private var model:
        TunerModel

    @State
    private var tonePlayer =
        ReferenceTonePlayer()

    init(
        audio: AudioInputModel
    ) {
        self.audio = audio
        _model =
            StateObject(
                wrappedValue:
                    TunerModel(
                        audio: audio
                    )
            )
    }

    var body: some View {
        Form {
            Section(
                "Tuner"
            ) {
                HStack(
                    alignment: .center,
                    spacing: 24
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        Text(
                            model.reading
                                .map {
                                    $0.note
                                        .displayName(
                                            model
                                                .selectedTuning
                                                .accidentalPreference
                                        ) +
                                    String(
                                        $0.octave
                                    )
                                }
                            ?? "—"
                        )
                        .font(
                            .system(
                                size: 64,
                                weight: .semibold,
                                design:
                                    .rounded
                            )
                        )

                        Text(
                            model.reading
                                .map {
                                    String(
                                        format:
                                            "%.2f Hz",
                                        $0.frequencyHz
                                    )
                                }
                            ?? "入力待ち"
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    VStack(
                        spacing: 6
                    ) {
                        Text(
                            targetText
                        )
                        .font(.title2)

                        Text(
                            centsText
                        )
                        .font(
                            .title
                                .monospacedDigit()
                        )
                        .foregroundStyle(
                            isInTune
                            ? .green
                            : .primary
                        )

                        TunerNeedle(
                            cents:
                                model.target?
                                    .centsFromTarget
                                ?? 0
                        )
                        .frame(
                            width: 320,
                            height: 46
                        )
                    }
                }
                .padding(
                    .vertical,
                    8
                )
            }

            Section(
                "Tuning"
            ) {
                Picker(
                    "Preset",
                    selection:
                        Binding(
                            get: {
                                model
                                    .selectedTuning
                                    .id
                            },
                            set: {
                                id in

                                if id ==
                                    "custom" {
                                    model
                                        .selectCustomTuning()
                                } else if
                                    let tuning =
                                    GuitarTuning
                                        .presets
                                        .first(
                                            where: {
                                                $0.id ==
                                                id
                                            }
                                        ) {
                                    model
                                        .setTuning(
                                            tuning
                                        )
                                }
                            }
                        )
                ) {
                    ForEach(
                        GuitarTuning
                            .presets
                    ) {
                        tuning in
                        Text(tuning.name)
                            .tag(tuning.id)
                    }

                    Text("Custom")
                        .tag("custom")
                }

                ScrollView(
                    .horizontal
                ) {
                    HStack(
                        spacing: 8
                    ) {
                        ForEach(
                            model
                                .selectedTuning
                                .strings
                                .sorted {
                                    $0.stringNumber <
                                    $1.stringNumber
                                }
                        ) {
                            string in

                            Button {
                                model
                                    .setLockedString(
                                        model
                                            .lockedStringNumber ==
                                        string.stringNumber
                                        ? nil
                                        : string
                                            .stringNumber
                                    )
                            } label: {
                                VStack {
                                    Text(
                                        string.label
                                    )
                                    .font(
                                        .headline
                                    )

                                    Text(
                                        "\(string.stringNumber)弦"
                                    )
                                    .font(
                                        .caption
                                    )
                                }
                                .frame(
                                    minWidth: 58
                                )
                            }
                            .buttonStyle(
                                model
                                    .lockedStringNumber ==
                                string.stringNumber
                                ? .borderedProminent
                                : .bordered
                            )
                            .contextMenu {
                                Button(
                                    "基準音を再生"
                                ) {
                                    tonePlayer
                                        .play(
                                            frequency:
                                                GuitarNote
                                                    .frequency(
                                                        forMIDI:
                                                            string.midi,
                                                        a4Hz:
                                                            model.a4Hz
                                                    )
                                        )
                                }
                            }
                        }
                    }
                }

                if model
                    .selectedTuning
                    .id ==
                    "custom" {
                    ForEach(
                        model
                            .selectedTuning
                            .strings
                            .sorted {
                                $0.stringNumber >
                                $1.stringNumber
                            }
                    ) {
                        string in

                        HStack {
                            Text(
                                "\(string.stringNumber)弦"
                            )

                            Spacer()

                            Button {
                                model
                                    .changeCustomString(
                                        stringNumber:
                                            string
                                                .stringNumber,
                                        semitones:
                                            -1
                                    )
                            } label: {
                                Image(
                                    systemName:
                                        "minus"
                                )
                            }

                            Text(
                                string.label
                            )
                            .frame(
                                minWidth: 42
                            )

                            Button {
                                model
                                    .changeCustomString(
                                        stringNumber:
                                            string
                                                .stringNumber,
                                        semitones:
                                            1
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
            }

            Section(
                "Reference"
            ) {
                LabeledContent(
                    "A4"
                ) {
                    HStack {
                        Slider(
                            value:
                                $model.a4Hz,
                            in:
                                400...480,
                            step: 0.1
                        )
                        .frame(
                            width: 250
                        )

                        Text(
                            String(
                                format:
                                    "%.1f Hz",
                                model.a4Hz
                            )
                        )
                        .monospacedDigit()
                    }
                }

                LabeledContent(
                    "Sensitivity"
                ) {
                    Slider(
                        value:
                            $model
                                .sensitivity,
                        in: 0...1
                    )
                    .frame(
                        width: 250
                    )
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(
            "チューナー"
        )
        .toolbar {
            ToolbarItem(
                placement:
                    .primaryAction
            ) {
                Button {
                    if audio.isRunning {
                        model.stop()
                        audio.stop()
                    } else {
                        model.start()
                    }
                } label: {
                    Label(
                        audio.isRunning
                        ? "停止"
                        : "入力開始",
                        systemImage:
                            audio.isRunning
                            ? "waveform.slash"
                            : "waveform"
                    )
                }
            }
        }
        .onAppear {
            model.start()
        }
        .onDisappear {
            model.stop()
            tonePlayer.stop()
        }
        .onChange(
            of: model.a4Hz
        ) {
            _ in
            if let reading =
                model.reading {
                _ = reading
                model
                    .setLockedString(
                        model
                            .lockedStringNumber
                    )
            }
        }
    }

    private var targetText:
        String {
        guard let target =
            model.target
        else {
            return "Target —"
        }

        return "Target \(target.string.label)"
    }

    private var centsText:
        String {
        guard let cents =
            model.target?
                .centsFromTarget
        else {
            return "—"
        }

        return String(
            format:
                "%+.1f ¢",
            cents
        )
    }

    private var isInTune:
        Bool {
        abs(
            model.target?
                .centsFromTarget
            ?? 100
        ) <= 5
    }
}

private struct TunerNeedle:
    View {

    let cents: Double

    var body: some View {
        GeometryReader {
            geometry in

            ZStack {
                Rectangle()
                    .fill(
                        .quaternary
                    )
                    .frame(
                        height: 1
                    )

                Rectangle()
                    .fill(
                        .secondary
                    )
                    .frame(
                        width: 1
                    )

                Capsule()
                    .fill(
                        abs(cents) <= 5
                        ? Color.green
                        : Color.accentColor
                    )
                    .frame(
                        width: 3,
                        height: 34
                    )
                    .offset(
                        x:
                            CGFloat(
                                min(
                                    max(
                                        cents,
                                        -50
                                    ),
                                    50
                                ) /
                                50
                            ) *
                            (
                                geometry
                                    .size
                                    .width /
                                2 -
                                4
                            )
                    )
            }
        }
    }
}
