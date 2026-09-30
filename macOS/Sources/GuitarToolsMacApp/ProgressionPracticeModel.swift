import AVFoundation
import Combine
import Foundation
import GuitarToolsCore

struct ProgressionStep:
    Identifiable,
    Equatable {

    let id: UUID
    var symbol: String
    var lookupName: String
    var beats: Int

    init(
        id: UUID = UUID(),
        symbol: String,
        lookupName: String,
        beats: Int = 4
    ) {
        self.id = id
        self.symbol = symbol
        self.lookupName =
            lookupName
        self.beats =
            min(
                max(beats, 1),
                32
            )
    }
}

@MainActor
final class ProgressionPracticeModel:
    ObservableObject {

    @Published
    var title =
        "コード進行練習"

    @Published
    var artist = ""

    @Published
    var progression:
        [ProgressionStep] = [
            .init(
                symbol: "C",
                lookupName: "C"
            ),
            .init(
                symbol: "G",
                lookupName: "G"
            ),
            .init(
                symbol: "Am",
                lookupName: "Am"
            ),
            .init(
                symbol: "F",
                lookupName: "F"
            )
        ]

    @Published
    var bpm = 80

    @Published
    var beatsPerBar = 4

    @Published
    var beatUnit = 4

    @Published private(set)
    var currentStepIndex = 0

    @Published private(set)
    var beatInStep = 0

    @Published private(set)
    var isPlaying = false

    @Published
    var autoScroll = true

    @Published
    var syncBackingTrack = true

    @Published
    var syncOffsetMs:
        Int64 = 0

    @Published
    var importText = ""

    @Published
    var searchQuery = ""

    @Published private(set)
    var searchResults:
        [MacSongSearchResult] = []

    @Published private(set)
    var isSearching = false

    @Published private(set)
    var selectedSong:
        MacSongSearchResult?

    @Published private(set)
    var errorMessage: String?

    @Published private(set)
    var backingTrackURL: URL?

    @Published private(set)
    var backingTrackTitle = ""

    @Published private(set)
    var backingPositionMs:
        Int64 = 0

    @Published private(set)
    var backingDurationMs:
        Int64 = 0

    @Published private(set)
    var backingPlaying = false

    private let metronome =
        MacMetronomeEngine()

    private let songs =
        SongMetadataClient()

    private var player:
        AVPlayer?

    private var observer:
        Any?

    func addChord(
        root: GuitarNote,
        quality:
            GuitarChordQuality
    ) {
        let chord =
            GuitarChord(
                root: root,
                quality: quality
            )

        progression.append(
            ProgressionStep(
                symbol:
                    chord.name,
                lookupName:
                    chord.name
            )
        )
    }

    func removeStep(
        _ index: Int
    ) {
        guard
            progression.indices
                .contains(index)
        else {
            return
        }

        progression.remove(
            at: index
        )

        currentStepIndex =
            progression.isEmpty
            ? 0
            : min(
                currentStepIndex,
                progression.count - 1
            )

        beatInStep = 0
    }

    func setStepBeats(
        index: Int,
        beats: Int
    ) {
        guard
            progression.indices
                .contains(index)
        else {
            return
        }

        progression[index].beats =
            min(
                max(beats, 1),
                32
            )
    }

    func importChordPro() {
        let chart =
            ChordChartParser.parse(
                importText,
                fallbackTitle:
                    "Imported chart"
            )

        let steps =
            chart.lines
                .flatMap(\.segments)
                .compactMap {
                    segment
                    -> ProgressionStep? in

                    guard
                        let symbol =
                            segment.chord,
                        let normalized =
                            normalizeChordLookup(
                                symbol
                            )
                    else {
                        return nil
                    }

                    return ProgressionStep(
                        symbol: symbol,
                        lookupName:
                            normalized
                    )
                }

        guard !steps.isEmpty
        else {
            errorMessage =
                "コードを認識できませんでした"
            return
        }

        stop()

        title = chart.title
        artist = chart.artist
        progression = steps
        bpm =
            min(
                max(
                    chart.bpm
                    ?? bpm,
                    30
                ),
                300
            )

        currentStepIndex = 0
        beatInStep = 0
        errorMessage = nil
    }

    func searchSongs() {
        let value =
            searchQuery
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !value.isEmpty
        else {
            return
        }

        isSearching = true
        errorMessage = nil

        Task {
            do {
                searchResults =
                    try await songs
                        .search(
                            query: value
                        )
                isSearching = false
            } catch {
                isSearching = false
                errorMessage =
                    error.localizedDescription
            }
        }
    }

    func selectSong(
        _ song:
            MacSongSearchResult
    ) {
        selectedSong = song
        title = song.title
        artist = song.artist

        if let value =
            song.bpm {
            bpm =
                min(
                    max(
                        value,
                        30
                    ),
                    300
                )
        }

        if let meter =
            song.timeSignature {
            let parts =
                meter.split(
                    separator: "/"
                )

            if
                parts.count == 2,
                let beats =
                    Int(parts[0]),
                let unit =
                    Int(parts[1]) {
                beatsPerBar =
                    min(
                        max(
                            beats,
                            1
                        ),
                        12
                    )

                if [
                    2,
                    4,
                    8,
                    16
                ].contains(unit) {
                    beatUnit = unit
                }
            }
        }
    }

    func togglePlayback(
        syncToBackingTrack:
            Bool = false
    ) {
        isPlaying
        ? stop()
        : start(
            syncToBackingTrack:
                syncToBackingTrack
        )
    }

    func restart() {
        currentStepIndex = 0
        beatInStep = 0
    }

    func start(
        syncToBackingTrack:
            Bool = false
    ) {
        guard
            !isPlaying,
            !progression.isEmpty
        else {
            return
        }

        isPlaying = true
        beatInStep = 0

        metronome.start(
            configProvider: {
                [weak self] in

                guard let self
                else {
                    return MacMetronomeConfig()
                }

                return MacMetronomeConfig(
                    bpm:
                        self.bpm,
                    beatsPerBar:
                        self.beatsPerBar,
                    beatUnit:
                        self.beatUnit,
                    subdivision:
                        .quarter,
                    accents:
                        Array(
                            0..<self
                                .beatsPerBar
                        )
                        .map {
                            $0 == 0
                            ? .accent
                            : .normal
                        },
                    countInBars:
                        syncToBackingTrack
                        ? 0
                        : 1
                )
            },
            onBeat: {
                [weak self]
                event in

                self?.handleBeat(
                    event
                )
            }
        )
    }

    func stop() {
        metronome.stop()
        isPlaying = false
        beatInStep = 0
    }

    func loadBackingTrack(
        _ url: URL
    ) {
        if let observer,
           let player {
            player.removeTimeObserver(
                observer
            )
        }

        let item =
            AVPlayerItem(url: url)

        let player =
            AVPlayer(
                playerItem: item
            )

        self.player = player
        backingTrackURL = url
        backingTrackTitle =
            url.deletingPathExtension()
                .lastPathComponent

        observer =
            player
                .addPeriodicTimeObserver(
                    forInterval:
                        CMTime(
                            seconds: 0.1,
                            preferredTimescale:
                                600
                        ),
                    queue: .main
                ) {
                    [weak self]
                    time in

                    Task {
                        @MainActor in
                        self?
                            .updateBackingPosition(
                                time
                            )
                    }
                }

        Task {
            let duration =
                try? await item.asset
                    .load(.duration)

            backingDurationMs =
                Int64(
                    (
                        duration?
                            .seconds
                        ?? 0
                    ) *
                    1_000
                )
        }
    }

    func toggleBackingTrack() {
        guard let player
        else {
            return
        }

        if backingPlaying {
            player.pause()
            backingPlaying = false
        } else {
            player.play()
            backingPlaying = true

            if syncBackingTrack {
                syncToPlaybackPosition(
                    backingPositionMs
                )
            }
        }
    }

    func stopBackingTrack() {
        player?.pause()
        player?.seek(to: .zero)
        backingPlaying = false
        backingPositionMs = 0
    }

    func seekBackingTrack(
        milliseconds:
            Int64
    ) {
        player?.seek(
            to:
                CMTime(
                    seconds:
                        Double(
                            max(
                                milliseconds,
                                0
                            )
                        ) /
                        1_000,
                    preferredTimescale:
                        600
                )
        )

        backingPositionMs =
            max(
                milliseconds,
                0
            )

        if syncBackingTrack {
            syncToPlaybackPosition(
                backingPositionMs
            )
        }
    }

    func syncToPlaybackPosition(
        _ positionMs: Int64
    ) {
        guard
            !progression.isEmpty,
            positionMs >= 0
        else {
            return
        }

        let totalBeats =
            progression.reduce(0) {
                $0 + $1.beats
            }

        guard totalBeats > 0
        else {
            return
        }

        let adjusted =
            max(
                positionMs -
                syncOffsetMs,
                0
            )

        let absolute =
            Int(
                floor(
                    Double(adjusted) *
                    Double(bpm) /
                    60_000
                )
            ) %
            totalBeats

        var remaining =
            absolute

        for (
            index,
            step
        ) in progression
            .enumerated() {
            if remaining <
                step.beats {
                currentStepIndex =
                    index
                beatInStep =
                    remaining
                return
            }

            remaining -=
                step.beats
        }
    }

    private func handleBeat(
        _ event:
            MacBeatEvent
    ) {
        guard
            event.isMainBeat,
            !event.isCountIn,
            !progression.isEmpty
        else {
            return
        }

        let index =
            min(
                max(
                    currentStepIndex,
                    0
                ),
                progression.count - 1
            )

        let step =
            progression[index]

        let next =
            beatInStep + 1

        if next <
            step.beats {
            beatInStep = next
        } else {
            currentStepIndex =
                (
                    index + 1
                ) %
                progression.count
            beatInStep = 0
        }
    }

    private func updateBackingPosition(
        _ time: CMTime
    ) {
        backingPositionMs =
            Int64(
                max(
                    time.seconds,
                    0
                ) *
                1_000
            )

        backingPlaying =
            player?.timeControlStatus ==
            .playing

        if syncBackingTrack {
            syncToPlaybackPosition(
                backingPositionMs
            )
        }
    }

    deinit {
        if let observer,
           let player {
            player.removeTimeObserver(
                observer
            )
        }
    }
}
