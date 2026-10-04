import GuitarToolsCore
import SwiftUI

/// An instrument-first recall desk. Ratings are deliberately self-reported, not audio scores.
struct ChordLearningView: View {
    @ObservedObject var model: ChordLearningModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if model.phase == .idle || model.phase == .completed {
                    if model.phase == .completed { sessionResult }
                    overview
                } else {
                    practiceDesk
                }
            }
            .padding(MacLayout.pagePadding)
            .macPageWidth(1_000)
        }
        .onAppear { model.refresh() }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("コード名だけで、手が動くように。")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("定番の形を見て弾く。図を隠して思い出す。翌日も弾けるか確かめる。")
                    .foregroundStyle(.secondary)
            }
            if model.hasCustomSource {
                HStack {
                    Text(model.activeSetTitle).font(.headline)
                    Spacer()
                    Button("基本セットへ戻る") {
                        let deck = model.selectedDeck
                        model.selectedDeck = deck
                    }
                        .buttonStyle(.bordered)
                }
            } else {
                Picker("覚えるセット", selection: $model.selectedDeck) {
                    ForEach(ChordLearningDeck.allCases) { deck in
                        Text(deck.title).tag(deck)
                    }
                }
                .pickerStyle(.segmented)
                Text(model.selectedDeck.subtitle).font(.callout).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                MacStatusPill(text: "未練習 \(model.newCount)", systemImage: "sparkle", role: .neutral)
                MacStatusPill(text: "今日の復習 \(model.dueCount)", systemImage: "arrow.clockwise", role: .neutral)
            }
            Button(startLabel, systemImage: "guitars") { model.startSession() }
                .buttonStyle(.borderedProminent).controlSize(.large)
            if model.newCount == 0 && model.dueCount == 0 {
                Text("今は復習予定日前です。練習はできますが、予定前の反復では図なし復習の記録を増やしません。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            MacSection("覚えるコード") {
                ForEach(model.sourceSymbols, id: \.self) { symbol in
                    HStack(spacing: 14) {
                        Text(symbol).font(.system(.title3, design: .rounded).weight(.bold))
                            .frame(width: 72, alignment: .leading)
                        if let progress = model.progress(for: symbol) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("図なし復習 \(progress.successfulReviews)回（自己確認）")
                                Text("次の復習：" + progress.nextReviewAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("まずは形を見て覚える").foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button("練習", systemImage: "play") {
                            model.startCustom(symbols: [symbol], title: "\(symbol)を覚える")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 5)
                }
            }
            Text("復習間隔は目安です。図なしで再現したかは自己確認で記録します。痛みやしびれがあれば中断してください。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var startLabel: String {
        if model.dueCount > 0 { return "今日の復習を始める" }
        if model.newCount > 0 { return "見て覚える練習を始める" }
        return "予定前にもう一度練習する"
    }

    private var practiceDesk: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.activeSetTitle).font(.headline).lineLimit(2)
                    Text(phaseTitle).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(model.position) / \(model.total)").monospacedDigit().foregroundStyle(.secondary)
                Button("練習を終了") { model.exitSession() }.buttonStyle(.bordered)
            }
            ProgressView(value: Double(model.completedCount), total: Double(max(1, model.total)))
                .accessibilityLabel("この回の練習の進み具合")
            if let symbol = model.currentSymbol {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(symbol).font(.system(size: 58, weight: .bold, design: .rounded))
                        Spacer()
                        Text("標準チューニング・カポなし").font(.caption).foregroundStyle(.secondary)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 28) {
                            fingering(symbol).frame(width: 340)
                            instructions.frame(minWidth: 230, maxWidth: .infinity, alignment: .leading)
                        }
                        VStack(alignment: .leading, spacing: 20) {
                            fingering(symbol).frame(maxWidth: 420)
                            instructions
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .macContentSurface(radius: MacLayout.heroRadius)
                if model.phase != .recalling {
                    ChordFingerLegend()
                }
            }
            actions
            Text("音声による自動採点はしません。鳴らす弦を1本ずつ確かめ、図と自分の指を比べてください。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func fingering(_ symbol: String) -> some View {
        if model.phase == .recalling {
            VStack(spacing: 12) {
                Image(systemName: "guitars").font(.system(size: 36)).foregroundStyle(.secondary)
                Text("図は隠しています").font(.headline)
                Text("コード名だけで押さえて、鳴らす弦を1本ずつ弾いてみましょう。")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 210)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ChordFingeringView(symbol: symbol, voicingIDOverride: model.currentVoicing?.id,
                                   selectionEnabled: false)
                Text(model.currentVoicing?.isConventional == true
                     ? "定番フォームで練習しています" : "構成音を確認した参考フォームです")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 210)
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.phase == .recalling ? "まずは思い出して弾く" : "音と手の形を確認")
                .font(.title3.weight(.semibold))
            Text("1. 鳴らす弦が、それぞれ明瞭に鳴る")
            Text("2. ×の弦は鳴らさない")
            Text("3. 無理な力や痛みがない")
            if model.phase == .revealed {
                Divider()
                Text("弾く前に図を見たか、見ずに思い出せたかを分けて記録します。速さは競いません。")
                    .font(.callout).foregroundStyle(.secondary)
                if !model.canCreditRecall {
                    Text(model.recallWasAssisted
                         ? "今回は図を見た練習です。後日の図なし復習とは分けて保存します。"
                         : "予定前の再確認です。練習は保存しますが復習段階は進めません。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var actions: some View {
        switch model.phase {
        case .studying:
            Button("図を隠して、弾いてみる", systemImage: "eye.slash") { model.hideDiagram() }
                .buttonStyle(.borderedProminent).controlSize(.large)
        case .recalling:
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { recallButtons }
                VStack(alignment: .leading, spacing: 12) { recallButtons }
            }
        case .revealed:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                ratingButton("もう一度練習したい", icon: "arrow.counterclockwise", rating: .again)
                ratingButton("迷いながら弾けた", icon: "questionmark.circle", rating: .hard)
                ratingButton(model.canCreditRecall ? "図なしで弾けた" : model.recallWasAssisted
                             ? "形を練習できた" : "形を再確認できた",
                             icon: "checkmark", rating: .remembered)
            }
        case .idle, .completed:
            EmptyView()
        }
    }

    @ViewBuilder
    private var recallButtons: some View {
        Button("弾いたので、答え合わせ", systemImage: "eye") { model.revealAnswer() }
            .buttonStyle(.borderedProminent).controlSize(.large)
        Button("思い出せない：図を見る") { model.showHint() }
            .buttonStyle(.bordered).controlSize(.large)
    }

    private func ratingButton(_ title: String, icon: String, rating: ChordLearningModel.Rating) -> some View {
        Button { model.rate(rating) } label: {
            Label(title, systemImage: icon).frame(maxWidth: .infinity).padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }

    private var phaseTitle: String {
        switch model.phase {
        case .studying: "見て、形と音を覚える"
        case .recalling: "図なしで、押さえ方を思い出す"
        case .revealed: "図と照らし合わせて、自己確認"
        case .idle, .completed: "少しずつ、翌日にも復習"
        }
    }

    private var sessionResult: some View {
        MacSection("\(model.activeSetTitle)の練習結果") {
            HStack(spacing: 20) {
                Label("図なし復習 \(model.sessionRecalled)回", systemImage: "checkmark.circle")
                Label("もう一度確認 \(model.sessionNeedsWork)回", systemImage: "arrow.clockwise")
            }
            Text("自己確認を保存しました。同じ日に何度も成功しても、後日の復習と同じ扱いにはしません。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
