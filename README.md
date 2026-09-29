# Guitar Tools

Kotlin + Jetpack Compose で作る、軽量なAndroid向けギターツールです。

## 4つの機能

- **メトロノーム**
  - 30–300 BPM
  - ±1 / ±5 BPM
  - Tap tempo
  - 拍数設定
  - 1拍目アクセント
  - `AudioTrack`によるPCM再生

- **チューナー**
  - YINピッチ検出
  - ノイズゲートと中央値平滑化
  - Standard / Drop D / E♭ Standard / D Standard
  - 最寄り弦とcent差を表示
  - A4基準ピッチ調整

- **コード**
  - Major / minor / 5 / 7 / maj7 / m7
  - sus2 / sus4 / add9 / dim / aug
  - オープンコードとバレーコード
  - コード構成音
  - 指番号とバレーを描画するコード図

- **指板**
  - Standard tuning
  - 0〜12フレット
  - 音名ハイライト

## 読みやすい構成

```text
music/
  Note.kt           音名と周波数
  Pitch.kt          周波数→音程
  Chord.kt          コードのモデル
  ChordLibrary.kt   実際に収録する押さえ方
  Tuning.kt         チューニング
  Fretboard.kt      指板計算

audio/
  MetronomePlayer.kt
  MetronomeEngine.kt
  TapTempoCalculator.kt
  PcmSource.kt
  MicrophonePcmSource.kt
  PitchDetector.kt
  YinPitchDetector.kt
  MedianFrequencySmoother.kt
  TunerReader.kt
  TunerEngine.kt

ui/
  metronome/
  tuner/
  chords/
  fretboard/
  components/
```

UIはViewModelの`StateFlow`を表示するだけにし、`AudioTrack`や`AudioRecord`は`audio/`から外へ漏らさない構成です。

## コードを追加する

コード形は`music/ChordLibrary.kt`だけを編集します。

たとえば新しいコードを追加する場合:

```kotlin
shape(
    Note.F,
    ChordQuality.MAJOR,
    1, 3, 3, 2, 1, 1,
    fingers = listOf(1, 3, 4, 2, 1, 1),
    barres = listOf(
        Barre(
            fret = 1,
            fromString = 6,
            toString = 1
        )
    )
)
```

フレット値は**6弦（Low E）→1弦（High E）**の順です。

- `-1`: ミュート
- `0`: 開放弦
- `1以上`: フレット番号

音楽理論側のコード種類を増やす場合だけ`ChordQuality`へintervalを追加します。

## UI

Material 3をベースにしています。

- Center-aligned top app bar
- Navigation bar
- Tonal cards
- Sliders / filter chips / switches
- Dynamic color
- Edge-to-edge
- 日本語UI
- Adaptive / themed launcher icon

## Build

- Android Gradle Plugin 9.1.1
- Gradle 9.3.1
- JDK 17
- compileSdk 37
- targetSdk 36
- minSdk 26

CI:

```text
:app:testDebugUnitTest
:app:assembleDebug
```

mainのCIではdebug APKをArtifactとして出力します。
`vX.Y.Z`タグでは署名済みrelease APKをGitHub Releasesへ公開します。
