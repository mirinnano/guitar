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

    private let settingsColumns = [
        GridItem(
            .adaptive(
                minimum: 340,
                maximum: 560
            ),
            spacing: 16
        )
    ]

    init(
        audio: AudioInputModel,
        preferencesStore:
            AppPreferencesStore
    ) {
        self.audio = audio
        _model =
            StateObject(
                wrappedValue:
                    TunerModel(
                        audio: audio,
                        preferencesStore:
                            preferencesStore
                    )
            )
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 20
            ) {
                MacPageHeader(
                    "チューナー",
                    subtitle:
                        "オーディオ入力からYINでピッチを検出します。"
                ) {
                    tuningStatus
                }

                tunerHero

                LazyVGrid(
                    columns:
                        settingsColumns,
                    alignment: .leading,
                    spacing: 16
                ) {
                    tuningSection
                    referenceSection
                }
            }
            .padding(26)
            .macPageWidth(1_080)
        }
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

            model.setLockedString(
                model.lockedStringNumber
            )
        }
    }

    @ViewBuilder
    private var tuningStatus:
        some View {

        if !audio.isRunning {
            MacStatusPill(
                text: "Input Off",
                systemImage:
                    "waveform.slash",
                role: .neutral
            )
        } else if isInTune {
            MacStatusPill(
                text: "In Tune",
                systemImage:
                    "checkmark.circle.fill",
                role: .success
            )
        } else if let cents =
            model.target?
                .centsFromTarget {
            MacStatusPill(
                text:
                    cents > 0
                    ? "Sharp"
                    : "Flat",
                systemImage:
                    cents > 0
                    ? "arrow.up"
                    : "arrow.down",
                role: .neutral
            )
        }
    }

    private var tunerHero:
        some View {

        VStack(
            spacing: 22
        ) {
            HStack(
                alignment: .center,
                spacing: 34
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(noteText)
                        .font(
                            .system(
                                size: 76,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .contentTransition(
                            .numericText()
                        )

                    Text(frequencyText)
                        .font(
                            .callout
                                .monospacedDigit()
                        )
                        .foregroundStyle(
                            .secondary
                        )
                }
                .frame(
                    minWidth: 180,
                    alignment: .leading
                )

                VStack(
                    spacing: 8
                ) {
                    Text(targetText)
                        .font(
                            .headline
                        )

                    TunerNeedle(
                        cents:
                            model.target?
                                .centsFromTarget
                            ?? 0
                    )
                    .frame(
                        minWidth: 360,
                        maxWidth: 620,
                        minHeight: 54,
                        maxHeight: 54
                    )

                    HStack {
                        Text("−50")
                        Spacer()
                        Text(centsText)
                            .font(
                                .title2
                                    .weight(
                                        .semibold
                                    )
                                    .monospacedDigit()
                            )
                            .foregroundStyle(
                                isInTune
                                ? .green
                                : .primary
                            )
                        Spacer()
                        Text("+50")
                    }
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
                .frame(
                    maxWidth: .infinity
                )
            }

            Divider()

            HStack(
                spacing: 16
            ) {
                MacAudioLevelMeter(
                    levelDBFS:
                        audio.levelDBFS,
                    clipping:
                        audio.clipping
                )
                .frame(
                    maxWidth: 360
                )

                Spacer()

                if let target =
                    model.target {
                    MacMetric(
                        "Target",
                        value:
                            target.string.label,
                        detail:
                            String(
                                format:
                                    "%.2f Hz",
                                target
                                    .targetFrequencyHz
                            ),
                        systemImage:
                            "scope"
                    )
                    .frame(
                        maxWidth: 220
                    )
                }
            }
        }
        .padding(24)
        .background(
            .quaternary.opacity(0.18),
            in:
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
        )
    }

    private var tuningSection:
        some View {

        MacSection(
            "チューニング",
            subtitle:
                "プリセット、弦固定、基準音"
        ) {
            VStack(
                alignment: .leading,
                spacing: 14
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
                        GuitarTuning.presets
                    ) {
                        tuning in

                        Text(tuning.name)
                            .tag(tuning.id)
                    }

                    Text("Custom")
                        .tag("custom")
                }

                Text(
                    "弦をクリックするとターゲットを固定。右クリックで基準音を再生できます。"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                ViewThatFits {
                    HStack(
                        spacing: 8
                    ) {
                        stringButtons
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(
                                .adaptive(
                                    minimum: 72
                                )
                            )
                        ],
                        spacing: 8
                    ) {
                        stringButtons
                    }
                }

                if model
                    .selectedTuning
                    .id ==
                    "custom" {
                    Divider()

                    VStack(
                        spacing: 8
                    ) {
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
                                .foregroundStyle(
                                    .secondary
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
                                .fontWeight(
                                    .semibold
                                )
                                .frame(
                                    minWidth: 44
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
            }
        }
    }

    @ViewBuilder
    private var stringButtons:
        some View {

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
                VStack(
                    spacing: 2
                ) {
                    Text(string.label)
                        .fontWeight(
                            .semibold
                        )

                    Text(
                        "\(string.stringNumber)弦"
                    )
                    .font(.caption2)
                }
                .frame(
                    minWidth: 58
                )
            }
            .buttonStyle(.bordered)
            .tint(
                model
                    .lockedStringNumber ==
                string.stringNumber
                ? Color.accentColor
                : Color.secondary
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

    private var referenceSection:
        some View {

        MacSection(
            "基準",
            subtitle:
                "基準ピッチと入力感度"
        ) {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {
                    HStack {
                        Text("A4")
                            .foregroundStyle(
                                .secondary
                            )

                        Spacer()

                        Text(
                            String(
                                format:
                                    "%.1f Hz",
                                model.a4Hz
                            )
                        )
                        .monospacedDigit()
                    }

                    Slider(
                        value:
                            $model.a4Hz,
                        in: 400...480,
                        step: 0.1
                    )

                    HStack(
                        spacing: 8
                    ) {
                        ForEach(
                            [432.0, 440.0, 442.0],
                            id: \.self
                        ) {
                            value in

                            Button(
                                String(
                                    format:
                                        "%.0f Hz",
                                    value
                                )
                            ) {
                                model.a4Hz =
                                    value
                            }
                        }
                    }
                }

                Divider()

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {
                    HStack {
                        Text(
                            "Sensitivity"
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        Spacer()

                        Text(
                            String(
                                format:
                                    "%.0f%%",
                                model
                                    .sensitivity *
                                100
                            )
                        )
                        .monospacedDigit()
                    }

                    Slider(
                        value:
                            $model.sensitivity,
                        in: 0...1
                    )
                }

                MacMetric(
                    "Mode",
                    value:
                        model
                            .lockedStringNumber
                        .map {
                            "\($0)弦固定"
                        }
                        ?? "Auto",
                    detail:
                        model
                            .selectedTuning
                            .name,
                    systemImage:
                        "tuningfork"
                )
            }
        }
    }

    private var noteText:
        String {
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
    }

    private var frequencyText:
        String {
        model.reading
            .map {
                String(
                    format:
                        "%.2f Hz",
                    $0.frequencyHz
                )
            }
        ?? "入力待ち"
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

                RoundedRectangle(
                    cornerRadius: 4
                )
                .fill(
                    Color.green
                        .opacity(0.12)
                )
                .frame(
                    width:
                        geometry
                            .size
                            .width *
                        0.1,
                    height: 28
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
                        height: 38
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
                                5
                            )
                    )
                    .animation(
                        .easeOut(
                            duration: 0.08
                        ),
                        value: cents
                    )
            }
        }
    }
}
