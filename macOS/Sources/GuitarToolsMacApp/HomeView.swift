import SwiftUI

struct HomeView: View {
    let onNavigate: (MacTool) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacLayout.sectionSpacing) {
                MacPageHeader(
                    "はじめに",
                    subtitle: "まずは音を合わせて、好きな曲を少しずつ。"
                )

                MacSection("1. 音を合わせる", subtitle: "練習の前にチューニング") {
                    Text("ギターをMacのマイクに近づけるか、オーディオ入力につないで、チューナーで1本ずつ音を合わせましょう。標準チューニングは、太い6弦から E・A・D・G・B・E です。")
                        .foregroundStyle(.secondary)
                    Button("チューナーを開く", systemImage: "tuningfork") {
                        onNavigate(.tuner)
                    }
                }

                MacSection("2. 曲を選ぶ", subtitle: "知っている曲から始めましょう") {
                    Text("譜面で曲名やアーティスト名を検索します。最初は C・G・Am・Em など、押さえやすいコードが多い曲がおすすめです。譜面ではコードの上に押さえ方が出ます。まず指の位置を確認して、1本ずつ音を鳴らしてみましょう。")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button("譜面で曲を探す", systemImage: "music.note.list") {
                            onNavigate(.charts)
                        }
                        Button("基本コードを見る", systemImage: "guitars") {
                            onNavigate(.chords)
                        }
                    }
                }

                MacSection("3. 短く練習する", subtitle: "まずは1〜2小節だけ") {
                    Text("まずはコードが変わるたびに1回鳴らすだけで大丈夫です。難しい切替は「30秒の切替練習」へ。残せる指を確かめ、2コードだけをゆっくり反復できます。「スムーズだった」「まだ難しい」でテンポを調整し、その場所の譜面に戻って試しましょう。慣れたら「演奏判定」も使えます。")
                        .foregroundStyle(.secondary)
                    Text("演奏判定は入力音を使います。曲の音楽再生は引き継がれません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("譜面で短く練習", systemImage: "repeat") {
                        onNavigate(.charts)
                    }
                }
            }
            .padding(MacLayout.pagePadding)
            .macPageWidth(900)
        }
        .navigationTitle("はじめに")
    }
}
