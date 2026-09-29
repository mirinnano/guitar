# Guitar Tools

A small Android guitar utility app built with Kotlin and Jetpack Compose.

## Current scope

The first version intentionally focuses on four tools:

- **Metronome**
  - 30–300 BPM
  - BPM slider and fine adjustments
  - Tap tempo
  - Beats per bar
  - First-beat accent
  - Low-latency `AudioTrack` playback

- **Tuner**
  - Microphone capture with source fallbacks
  - YIN pitch detection
  - Median frequency smoothing
  - Chromatic note / octave / cents display
  - Standard, Drop D, E♭ Standard, and D Standard presets
  - Automatic nearest-string target guidance
  - Adjustable A4 reference pitch
  - Noise gate and no-signal state

- **Chords**
  - Searchable common chord library
  - Major, minor, dominant 7, maj7, and m7 filters
  - Theory-derived chord tones
  - Data-driven fret and finger positions
  - Custom-drawn chord diagrams

- **Fretboard**
  - Standard tuning
  - Frets 0–12
  - Note names derived from MIDI pitch
  - Note highlighting with Material 3 filter chips
  - Custom fret/string drawing

## Architecture

The app keeps platform audio, music theory, state management, and UI separate.

```text
music/
  Note
  Pitch
  Chord
  Tuning
  Fretboard

audio/
  PcmSource
  MicrophonePcmSource
  PitchDetector
  YinPitchDetector
  MedianFrequencySmoother
  TunerReader
  TunerEngine
  MetronomePlayer
  MetronomeEngine
  TapTempoCalculator

ui/
  metronome/
  tuner/
  chords/
  fretboard/
  components/
```

UI state is exposed through `StateFlow` from ViewModels. Compose screens render state and send user events back to the ViewModels; they do not access `AudioRecord` or `AudioTrack` directly.

## UI

The interface uses Material 3 components and conventions:

- `TopAppBar`
- `NavigationBar`
- Cards
- Sliders
- Filter chips
- Dynamic color
- Edge-to-edge layout
- Semantics for custom-drawn diagrams

## Build baseline

- Android Gradle Plugin 9.1.1
- Gradle 9.3.1
- JDK 17
- compileSdk 37
- targetSdk 36
- minSdk 26
- Jetpack Compose with Material 3

CI runs:

```text
:app:testDebugUnitTest
:app:assembleDebug
```

The Gradle Wrapper binary is not committed yet, so CI currently provisions Gradle 9.3.1 through `gradle/actions/setup-gradle`.

## Status

The current development branch is `backend-foundation` and is tracked in PR #1.
