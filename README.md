# Guitar Tools

Android版（Kotlin + Jetpack Compose / Material 3）を中心に開発しているギター練習ツールです。macOS版はSwiftUIで、Android版の機能を引き継ぎつつオーディオインターフェース入力を活用するネイティブアプリとして開発予定です。

## 機能

### メトロノーム

- 30–300 BPM
- Tap tempo / ±1 / ±5 BPM
- 4/4・3/4・6/8・2/4
- 4分・8分・3連・16分
- 拍ごとの Accent / Normal / Mute
- Digital / Wood / Hi-hat クリック
- カウントイン
- 拍フラッシュ
- Speed Trainer
- 画面消灯中もWakeLockで継続
- Bluetooth音声接続時の遅延警告

### チューナー

- YINピッチ検出
- ±50 centsの針式メーター
- ±5 centsのIn Tuneゾーン
- Auto弦判定 / 弦固定
- 各弦の基準音再生
- Standard / Drop D / Drop C# / Drop C
- E♭ Standard / D Standard / Open G / DADGAD
- Custom tuning
- A4 = 432 / 440 / 442 Hz + 手動調整
- 入力感度
- 音程が合ったときのハプティクス

### コード

- C → C# → … → B の12ルート
- 16種類 × 12ルート = 192コード
- Major / minor / 5 / 6 / m6
- 7 / maj7 / m7
- 9 / maj9 / m9
- sus2 / sus4 / add9 / dim / aug
- 2列カタログで押さえ方を常時表示
- オープン/ミュート、指番号、バレー表示

### ChordWiki Viewer

- ChordWiki内を曲名/アーティストで検索
- WebViewを使わず、公開されているChordProソースを必要時だけ取得
- コードを歌詞の直上に配置したネイティブCompose表示
- 曲内で使うコードの押さえ方を横スクロール一覧で表示
- 既存の192コードと一致する場合はオープン/ミュート、指番号、バレーも表示
- 未登録の複雑なコードは譜面上のコード名を保持し、勝手に別コードへ置換しない
- Key / BPMがChordPro内にある場合はヘッダーに表示
- 元のChordWikiページへのリンクを保持
- Material 3ベースのプレイヤーUI / sticky transport dock
- 小節線と行構造から曲内コード位置を拍単位で推定
- BPM連動の連続自動スクロール
- 現在行・現在コード・小節位置をリアルタイム強調
- メトロノームを現在拍の位相へ同期
- 譜面内にYouTubeリンクがある場合は埋め込み小窓を表示
- YouTube再生位置 → 譜面タイムライン同期、シーク、前奏オフセット調整
- 高精度同期: 譜面コードを動画時刻へアンカーし、1点=オフセット補正 / 2点=全体テンポ補正 / 3点以上=区間ごとのpiecewise time-warp
- アンカーは曲ごとに保存され、±50ms微調整・削除・リセットに対応
- YouTube再生速度を追跡し、33ms補間で譜面スクロールと局所BPMメトロノームを追従

### 指板

- 0〜24フレット
- 単音 / スケール / コード表示
- Major / Minor / Pentatonic / Blues / Dorian / Mixolydian
- ルート音強調
- 音名 / 度数表示
- チューニング変更
- 左利き表示
- ズーム

### コード進行練習

- コードごとの拍数設定
- メトロノーム同期
- 現在コードと押さえ方を大きく表示
- 自動スクロール
- ChordPro貼り付け/import
- 曲名/アーティスト検索
- BPM/キー/拍子メタデータ取得
- バッキング音源のバックグラウンド再生
- 音源再生位置 + BPMからコード位置を同期

## macOS 開発目標

macOS版は **SwiftUI** で開発し、Android版の延長線に置きます。

- Android版のメトロノーム / チューナー / コード / ChordWiki / 指板 / 練習機能をMacへ展開
- デスクトップ向けのNavigationSplitView・リサイズ可能な譜面レイアウト
- オーディオインターフェースからギター入力
- AVAudioEngineを第一候補に、入力レベル・チューナー・オンセット検出へ利用
- 高精度同期アンカー / piecewise time-warpをMacでも利用
- 将来的に「弾いた瞬間が何ms早い/遅いか」を表示するタイミング練習
- 必要に応じてコード内容の判定も追加

**DAW化はしません。** 録音編集、マルチトラック、ミキサー、プラグインホスト、アンプシム、IR、MIDIシーケンサ等は対象外です。オーディオインターフェースは主に練習解析の入力源として扱います。

詳細: `docs/macos-roadmap.md`

### macOS 実装済み

Android版の現行ユーザー機能をSwiftUIへ移植済みです。

- **Metronome**: 30–300 BPM、1–12拍子、4分/8分/3連/16分、Accent/Normal/Mute、Digital/Wood/Hi-Hat、count-in、Tap Tempo、Speed Trainer
- **Tuner**: YIN pitch detection、Standard / Drop D / Drop C# / Drop C / E♭ Standard / D Standard / Open G / DADGAD / Custom、A4 400–480 Hz、感度、弦ロック、基準音
- **Chords**: 12 root × 16 quality = 192コード、検索、押さえ方図
- **ChordWiki**: 検索、ネイティブ譜面表示、押さえ方、BPM自動スクロール、現在コード、小節表示、YouTube小窓、アンカー同期、piecewise time-warp、同期メトロノーム、アンカー永続化
- **Fretboard**: Note / Scale / Chord、Major / Minor / Pentatonic / Blues / Dorian / Mixolydian、interval表示、各種tuning、12–24 frets、左利き
- **Practice**: コード進行編集、各step拍数、ChordPro import、MusicBrainz曲検索、ローカルbacking track、再生位置同期、offset
- **Mac extension**: CoreAudio入力デバイス/チャンネル選択、ホットプラグ追従、入力レイテンシ表示、リアルタイムコード判定、オンセット時刻、期待コード比較、早い/遅いms評価、セッション統計
- **Persistence**: メトロノーム / チューナー / 入力デバイス / チャンネル / 練習設定を保持し、練習セッションをversioned JSONで保存

Mac版は録音・ミキサー・アンプシム等を持たず、オーディオ入力を練習解析へ使います。

### macOS Release

- 現在のmacOS版: **v0.2.1**
- 対応OS: macOS 14+
- Release assetはDMGで配布し、DMG内の `Guitar Tools.app` をApplicationsへコピーします
- CIでは `Guitar Tools.app` bundleをそのままArtifactとして保持します
- 現在はad-hoc署名で、Developer ID notarizationは未対応です


## 楽曲データ

曲検索のProviderはコード譜Providerから分離しています。

- **MusicBrainz**
  - APIキーなしの曲/アーティスト検索
- **GetSongBPM**
  - APIキーがある場合にBPM・キー・拍子を取得
  - 結果には元データへのリンクを残します
- **ChordPro**
  - ユーザー自身が作成した、または利用許諾のあるコード譜をimport
- **ChordWiki**
  - 専用Viewerからサイト内検索し、選択した曲だけChordProソースをオンデマンド取得します
  - WebViewではなく、アプリ側でコード位置を保ったままCompose描画します
  - 元ページURLを保持します
- **U-FRET**
  - 練習画面では該当曲を探す外部リンクとして扱います

ChordWiki全体のミラーや一括収集は行わず、ユーザーが開いた譜面だけを都度取得する設計です。
譜面タイミングは、明示された小節線を優先し、小節線がない場合は1行を1小節としてコード数で拍を均等配分する推定値です。BPMとYouTube開始オフセットをUIから調整できます。
さらに高精度同期モードでは、動画のコード開始瞬間に譜面上のコードをタップしてアンカーを作成します。アンカー間は線形補間し、複数区間を独立に補正するため、前奏長・実テンポ差・テンポ揺れ・編集差によるドリフトを局所的に吸収できます。
曲メタデータ・コード譜・練習進行・押さえ方は分離しています。

## GetSongBPM

GetSongBPMを有効にする場合はビルド時に:

```bash
export GETSONGBPM_API_KEY="..."
```

Release workflowではGitHub Actions Secret:

```text
GETSONGBPM_API_KEY
```

を同名の環境変数へ渡します。

キー未設定でもアプリはビルドでき、その場合はMusicBrainzへフォールバックします。

## バッキング音源

端末内の音声ファイルを選択するとMedia3の`MediaSessionService`で再生します。

- 通知から再生/一時停止
- 画面を離れてもバックグラウンド再生
- URI権限を保持
- 再生位置を練習画面へ同期

ストリーミングサービスの音源をアプリ内で直接再生する場合は、各サービスの公式SDK・認証・利用許諾を別途使用します。

## 主な構成

```text
music/
  Note.kt
  Pitch.kt
  Chord.kt
  ChordLibrary.kt
  ChordSymbol.kt
  Scale.kt
  Tuning.kt
  Fretboard.kt

audio/
  MetronomeConfig.kt
  MetronomePlayer.kt
  MetronomeEngine.kt
  ScreenOffMetronomePlayer.kt
  ReferenceTonePlayer.kt
  TunerEngine.kt
  ...

practice/
  ChordProgression.kt
  ChordProParser.kt
  PracticeUiState.kt
  PracticeViewModel.kt
  PracticeScreen.kt

chordwiki/
  ChordWikiModels.kt
  ChordWikiParser.kt
  ChordWikiClient.kt
  ChordWikiViewModel.kt

ui/chordwiki/
  ChordWikiScreen.kt

song/
  SongCatalog.kt
  SongCatalogRepository.kt
  MusicBrainzSongProvider.kt
  ExternalChordLinks.kt

playback/
  PlaybackService.kt
  PlaybackViewModel.kt
```

## Build

- Android Gradle Plugin 9.1.1
- Gradle 9.3.1
- JDK 17
- compileSdk 37
- targetSdk 36
- minSdk 26
- Media3 1.11.1

```text
:app:testDebugUnitTest
:app:assembleDebug
```

`main`のCIではdebug APKをArtifactとして生成します。
`release/vX.Y.Z`ブランチまたは`vX.Y.Z`タグでは署名済みAPKをGitHub Releasesへ公開します。
