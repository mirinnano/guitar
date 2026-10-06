import GuitarToolsCore
import SwiftUI

struct TunerView:
    View {

    @ObservedObject
    var audio: AudioInputModel

    @StateObject
    private var model:
        TunerModel

    @ObservedObject private var output: AudioOutputModel

    @State private var inspectorPresented = false

    init(
        audio: AudioInputModel,
        output: AudioOutputModel,
        preferencesStore:
            AppPreferencesStore
    ) {
        self.audio = audio
        self.output = output
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
                spacing: MacLayout.sectionSpacing
            ) {
                MacPageHeader("チューナー") {
                    tuningStatus
                }

                if let error = audio.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                tunerHero
                tuningSection
                routingSection

                if !audio.isRunning {
                    HStack {
                        Button(audio.isStartRequested ? "開始をキャンセル" : "入力開始", systemImage: audio.isStartRequested ? "stop.fill" : "waveform", action: toggleInput)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(MacLayout.pagePadding)
            .macPageWidth(1_080)
        }
        .navigationTitle(
            "チューナー"
        )
        .toolbar {
            ToolbarItemGroup(
                placement:
                    .primaryAction
            ) {
                Button(action: toggleInput) {
                    Label(
                        audio.isStartRequested
                        ? (audio.isRunning ? "入力停止" : "開始をキャンセル")
                        : "入力開始",
                        systemImage:
                            audio.isStartRequested
                            ? "waveform.slash"
                            : "waveform"
                    )
                }
                .help(
                    audio.isStartRequested
                    ? "オーディオ入力を停止・開始予約をキャンセル"
                    : "オーディオ入力を開始"
                )

                Button("設定", systemImage: "slider.horizontal.3") {
                    inspectorPresented.toggle()
                }
                .help("入力と基準音の設定")
            }
        }
        .inspector(isPresented: $inspectorPresented) {
            ScrollView {
                VStack(spacing: 16) {
                    audioInputSection
                    referenceSection
                }
                .padding(16)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .inspectorColumnWidth(min: 300, ideal: 340, max: 400)
        }
        .onReceive(NotificationCenter.default.publisher(for: .practiceToggleInspector)) { _ in
            inspectorPresented.toggle()
        }
        .onAppear {
            model.start(requestInput: false)
        }
        .onDisappear {
            model.stop()
            output.stopReference()
        }
    }

    private var routingSection: some View {
        AudioRoutingSection(audio: audio, output: output)
    }

    @ViewBuilder
    private var tuningStatus:
        some View {

        if !audio.isRunning {
            MacStatusPill(
                text: audio.isStartRequested ? "入力開始待ち" : "入力停止中",
                systemImage:
                    "waveform.slash",
                role: .neutral
            )
        } else if isInTune {
            MacStatusPill(
                text: "合っています",
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
                    ? "高め"
                    : "低め",
                systemImage:
                    cents > 0
                    ? "arrow.up"
                    : "arrow.down",
                role: .neutral
            )
        }
    }

    private var tunerHero: some View {
        VStack(spacing: 26) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 36) {
                    detectedNote
                    tuningGauge
                }
                VStack(spacing: 24) {
                    detectedNote
                    tuningGauge
                }
            }

            Divider()

            HStack(spacing: 20) {
                MacAudioLevelMeter(levelDBFS: audio.levelDBFS, clipping: audio.clipping)
                    .frame(maxWidth: 360)

                if !audio.isRunning {
                    Button(audio.isStartRequested ? "開始をキャンセル" : "入力開始", systemImage: audio.isStartRequested ? "stop.fill" : "waveform", action: toggleInput)
                        .buttonStyle(.borderedProminent)
                }

                if let string = model.targetString, let frequency = model.targetFrequencyHz {
                    Spacer(minLength: 12)
                    MacMetric(
                        "目標の音",
                        value: string.label,
                        detail: String(format: "%.2f Hz", frequency),
                        systemImage: "scope"
                    )
                }
            }
        }
        .padding(32)
        .macContentSurface(radius: MacLayout.heroRadius)
    }

    private var detectedNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(noteText)
                .font(.system(size: 96, weight: .light, design: .rounded))
                .contentTransition(.numericText())

            Text(frequencyText)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 150, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var tuningGauge: some View {
        VStack(spacing: 12) {
            Text(targetText)
                .font(.headline)

            TunerNeedle(cents: model.target?.centsFromTarget)
                .frame(minWidth: 180, maxWidth: 620, minHeight: 54, maxHeight: 54)
                .accessibilityLabel("音程のずれ")
                .accessibilityValue(centsText)

            HStack {
                Text("−50")
                Spacer()
                Text(centsText)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(isInTune ? .green : .primary)
                Spacer()
                Text("+50")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var audioInputSection:
        some View {

        MacSection("オーディオ入力") {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                AudioInputDevicePicker(
                    audio: audio
                )

                MacAudioLevelMeter(
                    levelDBFS:
                        audio.levelDBFS,
                    clipping:
                        audio.clipping
                )
            }
        }
    }

    private var tuningSection:
        some View {

        MacSection("チューニング") {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                Picker(
                    "チューニング",
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

                    Text("カスタム")
                        .tag("custom")
                }

                Text(
                    "左が6弦（太い）、右が1弦（細い）。弦を選ぶと、その弦に合わせて調整できます。"
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

                HStack(spacing: 12) {
                    if let string = model.selectedTuning.strings.first(where: {
                        $0.stringNumber == (model.lockedStringNumber ?? 6)
                    }) {
                        Button("\(string.stringNumber)弦 \(string.label)の基準音を聴く", systemImage: "speaker.wave.2") {
                            output.playReference(frequency: GuitarNote.frequency(forMIDI: string.midi, a4Hz: model.a4Hz))
                        }
                    }
                    if model.lockedStringNumber != nil {
                        Button("自動判定に戻す") { model.setLockedString(nil) }
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
                    $0.stringNumber >
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
                    output
                        .playReference(
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

        MacSection("基準音と入力感度") {
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
                            "検出感度"
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
                    Text("小さい音を検出しやすくする設定です。入力音量は変わりません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                MacMetric(
                    "弦の選択",
                    value:
                        model
                            .lockedStringNumber
                        .map {
                            "\($0)弦固定"
                        }
                        ?? "自動",
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
        guard let string = model.targetString else { return "対象の弦 —" }
        return "対象の弦 \(string.label)"
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

    private func toggleInput() {
        model.start(requestInput: false)
        audio.toggle()
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

    let cents: Double?

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

                if let cents {
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
}
