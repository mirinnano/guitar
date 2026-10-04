import GuitarToolsCore
import SwiftUI

/// A song-specific practice desk: pick one change, learn the movement, rehearse, return to the song.
struct SongCoachView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var model: SongCoachModel
    private let onReturnToChart: (Double, Double) -> Void

    init(chart: ChordChart, sourceBPM: Int, initialBeat: Double,
         onReturnToChart: @escaping (Double, Double) -> Void) {
        // Keep practice geometry and finger guidance fixed for this desk's
        // lifetime, even if global fingering preferences subsequently change.
        let voicingSelections = ChordVoicingPreferencesStore.shared.selections
        _model = StateObject(wrappedValue: SongCoachModel(
            chart: chart, sourceBPM: sourceBPM, initialBeat: initialBeat,
            voicingSelections: voicingSelections
        ))
        self.onReturnToChart = onReturnToChart
    }

    var body: some View {
        GeometryReader { geometry in
            let short = geometry.size.height < 700
            VStack(spacing: 0) {
                header(compact: short)
                Divider()
                if let transition = model.selectedTransition {
                    if geometry.size.width >= 920 {
                        HStack(alignment: .top, spacing: 0) {
                            ScrollView { candidateList.padding(20) }
                                .frame(width: 245)
                            Divider()
                            practiceDesk(transition, compact: short)
                        }
                    } else {
                        VStack(spacing: 0) {
                            compactCandidatePicker.padding(.horizontal, 22).padding(.vertical, short ? 8 : 12)
                            Divider()
                            practiceDesk(transition, compact: short)
                        }
                    }
                    Divider()
                    controls(transition)
                } else {
                    emptyPlan
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(minWidth: 700, idealWidth: 1_040, minHeight: 600, idealHeight: 740)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear { model.stop() }
    }

    private func header(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("この曲のための、30秒。")
                    .font(.system(size: compact ? 21 : 26, weight: .bold, design: .rounded))
                    .accessibilityAddTraits(.isHeader)
                Text(model.chart.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("切替トレーナー · カポなし · マイク不要")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("閉じる", systemImage: "xmark") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(compact ? 16 : 22)
    }

    private var candidateList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("曲から見つけた切替")
                .font(.headline)
            Text("バレー・指の移動・登場回数をもとにした練習候補です。難しさは人によって違います。")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(model.plan.transitions) { transition in
                Button { model.select(transition.id) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(transition.fromSymbol) → \(transition.toSymbol)")
                            .font(.headline)
                        Text("曲中\(transition.occurrenceBeats.count)か所 · \(transition.movingFingerCount)本の指を持ち替え")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(model.selectedID == transition.id ? Color.accentColor.opacity(0.12) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(model.selectedID == transition.id ? Color.accentColor : .clear, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.selectedID == transition.id ? .isSelected : [])
                .disabled(model.isActive)
            }
            unsupportedNotice
        }
    }

    private var compactCandidatePicker: some View {
        Picker("練習する切替", selection: Binding(
            get: { model.selectedID ?? "" },
            set: model.select
        )) {
            ForEach(model.plan.transitions) { transition in
                Text("\(transition.fromSymbol) → \(transition.toSymbol)（曲中\(transition.occurrenceBeats.count)か所）")
                    .tag(transition.id)
            }
        }
        .disabled(model.isActive)
    }

    private func practiceDesk(_ transition: SongChordTransition, compact: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? 12 : 22) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(statusTitle)
                            .font(compact ? .headline : .title2.weight(.bold))
                        Text("1コードを\(model.beatsPerChord)拍ずつ。切替の最初に1回鳴らすだけでも大丈夫です。")
                            .font(compact ? .caption : .callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 10)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(Int(ceil(model.secondsRemaining)))")
                            .font(.system(size: 38, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("残り秒")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                if !transition.fixedFingers.isEmpty {
                    Label(transition.fixedFingers.map { "\($0.finger)番" }.joined(separator: "・") + "の指はそのまま。図の輪が目印です。", systemImage: "pin")
                        .font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
                }

                HStack(alignment: .center, spacing: 12) {
                    chordCard(transition.fromSymbol, shape: transition.fromShape, index: 0, compact: compact)
                    Image(systemName: model.activeChordIndex == 1 && model.isActive ? "arrow.left" : "arrow.right")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    chordCard(transition.toSymbol, shape: transition.toShape, index: 1, compact: compact)
                }
                beatStrip
                movementGuide(transition)
                ChordFingerLegend()
                unsupportedNotice
            }
            .padding(compact ? 16 : 22)
        }
        .frame(minHeight: 0, maxHeight: .infinity)
    }

    private func chordCard(_ symbol: String, shape: GuitarChordShape, index: Int, compact: Bool) -> some View {
        let active = model.activeChordIndex == index && model.isActive
        let voicingID = GuitarChordData(symbol: symbol)?.voicings.first { $0.shape == shape }?.id
        return VStack(spacing: 8) {
            Text(active ? (model.phase == .countIn ? "準備するコード" : "いま弾く") : (index == 0 ? "はじめに" : "次に"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(active ? Color.accentColor : .secondary)
            ChordFingeringView(
                symbol: symbol, compact: compact,
                fixedFingers: Set(model.selectedTransition?.fixedFingers.map(\.finger) ?? []),
                voicingIDOverride: voicingID, selectionEnabled: false
            )
                .frame(maxWidth: 205)
        }
        .padding(compact ? 10 : 14)
        .frame(maxWidth: .infinity)
        .background(active ? Color.accentColor.opacity(0.09) : Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(active ? Color.accentColor : Color.primary.opacity(0.07), lineWidth: active ? 2 : 1)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: active)
    }

    private var beatStrip: some View {
        HStack(spacing: 10) {
            ForEach(0..<model.beatsPerChord, id: \.self) { beat in
                Text("\(beat + 1)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(model.isActive && model.beatInChord == beat ? Color.white : .secondary)
                    .background(model.isActive && model.beatInChord == beat ? Color.accentColor : Color.secondary.opacity(0.10), in: Circle())
            }
            Spacer(minLength: 0)
            Text("\(model.bpm) BPM")
                .font(.callout.monospacedDigit().weight(.semibold))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.isActive ? "\(model.beatInChord + 1)拍目、\(model.bpm) BPM" : "練習テンポ\(model.bpm) BPM")
    }

    private func movementGuide(_ transition: SongChordTransition) -> some View {
        let reverse = model.activeChordIndex == 1 && model.isActive
        let source = reverse ? transition.toShape : transition.fromShape
        let target = reverse ? transition.fromShape : transition.toShape
        let fixedIDs = Set(transition.fixedFingers.map(\.finger))
        let usedIDs = Set((source.fingers + target.fingers).compactMap { $0 }).subtracting(fixedIDs).sorted()
        return VStack(alignment: .leading, spacing: 14) {
            Text("指の動きを小さくする")
                .font(.headline)
            if transition.fixedFingers.isEmpty {
                Text("この2つの図では、同じ位置に残せる指はありません。いったん力を抜き、次の形をゆっくり作りましょう。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("輪のついた指は、そのまま残せます。")
                    .font(.callout.weight(.semibold))
                ForEach(transition.fixedFingers, id: \.finger) { anchor in
                    Label("\(anchor.finger)番の指は " + anchor.positions.map { "\($0.stringNumber)弦\($0.fret)フレット" }.joined(separator: "・") + "のまま",
                          systemImage: "pin")
                        .font(.callout)
                }
            }
            if !usedIDs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("次は \(reverse ? transition.fromSymbol : transition.toSymbol)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(usedIDs, id: \.self) { finger in
                        Text("\(finger)番：\(positionsDescription(shape: source, finger: finger)) → \(positionsDescription(shape: target, finger: finger))")
                            .font(.caption)
                    }
                }
            }
            Text("指番号はこの図での目安です。無理に指を残さず、まずは1弦ずつきれいに鳴ることを優先してください。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .macContentSurface(radius: 16)
    }

    private func positionsDescription(shape: GuitarChordShape, finger: Int) -> String {
        let positions = shape.fingers.enumerated().compactMap { index, assigned -> String? in
            guard assigned == finger else { return nil }
            return "\(6 - index)弦\(shape.frets[index])F"
        }
        return positions.isEmpty ? "離す" : positions.joined(separator: "・")
    }

    private func controls(_ transition: SongChordTransition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView(value: (30 - model.secondsRemaining) / 30)
                .tint(.accentColor)
                .accessibilityLabel("30秒練習の進み具合")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { sessionControls }
                VStack(alignment: .leading, spacing: 12) { sessionControls }
            }
            if let error = model.soundError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
            if let message = model.feedbackMessage {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { feedbackControls(transition) }
                VStack(alignment: .leading, spacing: 12) { feedbackControls(transition) }
            }
            if model.progress.totalRounds > 0 {
                Text("練習 \(model.progress.totalRounds)回 · 自己チェック「スムーズ」\(model.progress.comfortableRounds)回。テンポはこの曲の切替ごとに保存されます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var sessionControls: some View {
        Group {
            Button(model.isActive ? "一時停止" : (model.phase == .paused && model.canRate ? "続きを練習" : "30秒だけ練習"),
                   systemImage: model.isActive ? "pause.fill" : "play.fill") {
                if model.isActive { model.pause() } else { model.start() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Stepper("\(model.bpm) BPM", value: Binding(get: { model.bpm }, set: model.setBPM), in: 40...300, step: 5)
                .frame(width: 170)
                .disabled(model.isActive)
            Text("譜面のテンポ：\(model.goalBPM) BPM\nクリック音だけ。マイク入力は不要です。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func feedbackControls(_ transition: SongChordTransition) -> some View {
        Button(model.bpm < model.goalBPM ? "スムーズだった · 少し速く" : "スムーズだった", systemImage: "checkmark", action: model.rateComfortable)
            .disabled(!model.canRate)
        Button("まだ難しい · ゆっくり", systemImage: "tortoise", action: model.rateDifficult)
            .disabled(!model.canRate)
        let bar = Int(floor((transition.occurrenceBeats.first ?? 0) / Double(model.chart.beatsPerBar))) + 1
        Button("\(bar)小節目を譜面で試す", systemImage: "arrow.uturn.backward") {
            model.stop()
            onReturnToChart(transition.occurrenceBeats.first ?? 0, transition.endBeat)
            dismiss()
        }
    }

    private var statusTitle: String {
        switch model.phase {
        case .ready: "2コードだけ、今はそれでいい。"
        case .countIn: "あと\(model.countInRemaining ?? model.beatsPerChord)拍で開始"
        case .playing: "拍に合わせて、ゆっくり切替。"
        case .paused: "ひと息ついて大丈夫。"
        case .completed: "30秒、おつかれさま。"
        }
    }

    @ViewBuilder
    private var unsupportedNotice: some View {
        if !model.plan.unavailableSymbols.isEmpty {
            Text("今回の候補から除外：" + model.plan.unavailableSymbols.joined(separator: "・") + "（安全に押さえ方を表示できないコード）")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyPlan: some View {
        VStack(spacing: 18) {
            ContentUnavailableView("練習できる切替がありません", systemImage: "guitars",
                                   description: Text("同じコードだけの譜面、または押さえ方が未対応の譜面です。通常の譜面で練習するか、別の曲を選んでください。"))
            unsupportedNotice
            Button("譜面に戻る") { dismiss() }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
