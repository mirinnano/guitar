# macOS Development Target

## Positioning

Guitar Tools will add a native macOS application built with **SwiftUI**.

The Mac app is an extension of the Android app, not a DAW.

The core product remains:

- metronome
- tuner
- chord catalog / fingering
- fretboard
- ChordWiki viewer
- high-precision chart synchronization
- auto-scroll
- practice mode

The Mac version adds desktop ergonomics and direct guitar input through an audio interface.

## Explicit non-goals

Do **not** turn Guitar Tools into a DAW.

The following are intentionally outside scope:

- multitrack recording
- timeline audio editing
- waveform editing
- mixer / channel-strip UI
- insert effect chains
- plugin hosting (AU / VST)
- amp simulation
- cabinet simulation / IR loader
- re-amping
- MIDI sequencing
- piano roll
- automation lanes
- mastering tools
- project/session management comparable to Logic, Ableton, Cubase, etc.

If a feature already belongs naturally in a DAW, Guitar Tools should normally integrate with the user's existing setup instead of rebuilding it.

## Intended Mac setup

\`\`\`text
Guitar
  ↓
Audio Interface
  ↓
Mac
  ↓
Guitar Tools
  ├─ tuner
  ├─ input level
  ├─ onset / timing analysis
  ├─ chord-follow practice
  ├─ metronome
  └─ synchronized chord chart
\`\`\`

The audio interface is primarily an **input source for practice analysis**.

Monitoring should normally be handled by the audio interface's direct-monitor function or the user's DAW/audio setup. Guitar Tools does not need to become the monitoring/mixing center.

## UI

### Technology

- Swift
- SwiftUI
- AppKit only where SwiftUI does not provide the required macOS behavior
- WKWebView only where the official YouTube embed requires it

The UI should follow macOS conventions rather than copying Material 3 literally.

### Desktop layout

The Android information architecture remains recognizable, but the Mac layout can use more screen space.

Suggested structure:

\`\`\`text
NavigationSplitView

Sidebar
  Metronome
  Tuner
  Chords
  Charts
  Fretboard
  Practice

Detail
  selected tool

Optional Inspector
  audio input
  sync state
  practice details
\`\`\`

For chart practice:

\`\`\`text
┌────────────────────────────────────────────────────┐
│ Song / artist / key / BPM                          │
├───────────────────────────────┬────────────────────┤
│                               │ YouTube / controls │
│ Chord chart                   │ Sync calibration   │
│                               │ Current chord      │
│ auto-scroll                   │ Fingering          │
│ active chord highlight        │ Input status       │
│                               │                    │
├───────────────────────────────┴────────────────────┤
│ Transport / metronome / progress                  │
└────────────────────────────────────────────────────┘
\`\`\`

Window resizing should be first-class.

## Android feature parity

The first Mac milestone should reproduce the useful Android behavior before adding Mac-only features.

### Metronome

- BPM control
- tap tempo
- time signature
- subdivision
- accents
- count-in
- speed trainer
- synchronized chart playback

### Tuner

- chromatic tuning
- string target mode
- alternate tunings
- A4 reference adjustment
- cents display
- sensitivity / noise gate

### Chords

- chord search
- existing chord library
- fingering diagrams
- barre/open/mute display

### ChordWiki

- search
- native chart rendering
- chord fingering
- current chord highlight
- auto-scroll
- YouTube mini-player
- high-precision sync anchors
- piecewise time-warp
- calibrated seeking
- sync persistence

### Fretboard

- note / scale / chord modes
- root highlighting
- interval labels
- alternate tunings
- left-handed display

### Practice

- chord progression practice
- metronome sync
- large current-chord display
- auto-scroll
- ChordPro import
- backing-track position sync where applicable

## Audio interface support

### MVP

The first audio-interface milestone should stay narrow.

Required:

- receive guitar audio from the selected Mac input
- work with USB audio interfaces
- input level meter
- clipping indication
- tuner input
- onset detection input
- input channel selection where practical
- sample-rate awareness
- clean handling when the interface disconnects

Not required:

- recording
- software monitoring
- routing matrix
- mixer
- effects

### Implementation direction

Use **AVAudioEngine** for the first implementation unless a concrete limitation requires lower-level CoreAudio access.

The initial path:

\`\`\`text
Audio Interface
  ↓
AVAudioEngine inputNode
  ↓
installTap
  ↓
PCM buffers
  ├─ level meter
  ├─ tuner
  └─ onset detector
\`\`\`

If explicit per-device selection, hardware timestamps, or latency measurement cannot be implemented robustly enough through AVAudioEngine alone, add a small CoreAudio layer for those specific responsibilities.

Do not introduce low-level CoreAudio complexity before it is needed.

## Live practice analysis

This is the main Mac-specific extension beyond Android.

### Onset timing

Detect when the user actually picks or strums.

Compare:

\`\`\`text
expected chord onset
        vs
detected guitar onset
\`\`\`

Output should be practical:

\`\`\`text
G
+34 ms late
\`\`\`

or

\`\`\`text
Am
-21 ms early
\`\`\`

This is practice feedback, not audio editing.

### Chord-follow practice

Use the existing synchronized chart timeline.

For each expected chord:

1. determine expected chart beat
2. convert chart beat to song time through the existing sync map
3. listen for the user's guitar onset
4. optionally estimate pitch classes / chord content
5. display timing feedback
6. advance practice state

Timing and harmonic correctness should remain separate measurements.

A player can be rhythmically correct while fingering the wrong chord, and vice versa.

## High-precision sync on Mac

Reuse the Android synchronization model:

- 0 anchors: BPM estimate
- 1 anchor: offset lock
- 2 anchors: global warp
- 3+ anchors: piecewise warp

Mac can improve the calibration workflow through:

- keyboard shortcuts
- larger chart layout
- finer ±10 ms / ±50 ms adjustment controls
- optional audio-onset assisted snapping later

The anchor model remains authoritative.

Automatic detection should assist calibration, not silently overwrite it.

## Shared logic

The Mac implementation is native SwiftUI, but the behavioral model should stay aligned with Android.

Keep equivalent models for:

- note / pitch
- chord symbols
- tunings
- ChordPro parsing
- ChordWiki parsing
- chart timeline
- sync anchors
- piecewise time mapping
- practice events

Do not force Kotlin Multiplatform into the project just to share code.

First keep the algorithms well specified and tested on both platforms. Code sharing can be reconsidered only if duplication becomes expensive.

## Milestones

### M0 — SwiftUI shell ✅ started

- SwiftPM-based native macOS executable packaged as `.app`
- SwiftUI `NavigationSplitView`
- resize-aware desktop layout
- ad-hoc signed CI artifact
- microphone/audio-input entitlement

### M1 — Android feature parity

- metronome
- tuner
- chords
- ChordWiki viewer
- high-precision sync
- fretboard
- practice

### M2 — Audio Interface MVP 🚧 in progress

- AVAudioEngine input ✅
- input level / clipping indication ✅
- input channel selection ✅
- real-time chord-content detection ✅ first implementation
- tuner from interface
- disconnect/reconnect behavior

### M3 — Timing Practice

- onset detection
- expected vs actual timing
- latency compensation
- early/late feedback
- session statistics

### M4 — Chord-follow Practice 🚧 foundation implemented

- 12-class chroma extraction ✅
- major/minor/5/7/maj7/m7/dim/aug/sus2/sus4 template matching ✅
- multi-frame stabilization ✅
- onset + pitch-class analysis
- expected chord comparison
- current chord follow mode
- timing and fingering/harmony feedback

### M5 — Sync assistance

- optional onset-assisted anchor snapping
- finer anchor adjustment
- local tempo visualization

## Principle

The Mac app should answer:

> "What helps me practice guitar better on a Mac with an audio interface?"

It should not answer:

> "How can we recreate Logic Pro inside Guitar Tools?"
