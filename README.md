# Guitar Tools

Kotlin + Jetpack Compose / Material 3 で作るAndroid向けギター練習ツールです。

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

## 楽曲データ

曲検索のProviderはコード譜Providerから分離しています。

- **MusicBrainz**
  - APIキーなしの曲/アーティスト検索
- **GetSongBPM**
  - APIキーがある場合にBPM・キー・拍子を取得
  - 結果には元データへのリンクを残します
- **ChordPro**
  - ユーザー自身が作成した、または利用許諾のあるコード譜をimport
- **U-FRET / ChordWiki**
  - アプリ内に無断複製せず、該当曲を探す外部リンクとして扱います

公開サイトのコード譜を一括スクレイピングして再配布する設計にはしていません。
将来、利用許諾のあるChord Providerを追加できるよう、曲メタデータ・練習進行・押さえ方を分離しています。

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
- Media3 1.9.4

```text
:app:testDebugUnitTest
:app:assembleDebug
```

`main`のCIではdebug APKをArtifactとして生成します。
`release/vX.Y.Z`ブランチまたは`vX.Y.Z`タグでは署名済みAPKをGitHub Releasesへ公開します。
