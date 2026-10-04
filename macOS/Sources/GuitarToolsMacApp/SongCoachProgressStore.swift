import Foundation
import GuitarToolsCore

/// Locally remembered tempo and self-reports; never an objective performance score.
struct SongCoachProgress: Codable, Equatable {
    var bpm: Int
    var comfortableRounds: Int
    var totalRounds: Int

    init(bpm: Int, comfortableRounds: Int = 0, totalRounds: Int = 0) {
        self.bpm = min(max(bpm, 40), 300)
        self.totalRounds = max(totalRounds, 0)
        self.comfortableRounds = min(max(comfortableRounds, 0), self.totalRounds)
    }
}

/// Versioned JSON, bounded to the last 50 songs and 128 pairs per song.
/// Uses explicit strings rather than Swift's process-randomized hash values.
final class SongCoachProgressStore {
    static let storageKey = "song-coach-progress.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func progress(chart: ChordChart, transitionID: String) -> SongCoachProgress? {
        read().songs.first { $0.key == Self.songKey(chart) }?
            .pairs.first { $0.id == transitionID }?.progress
    }

    func selectedTransitionID(chart: ChordChart) -> String? {
        read().songs.first { $0.key == Self.songKey(chart) }?.selectedID
    }

    func save(_ progress: SongCoachProgress, chart: ChordChart, transitionID: String) {
        guard !transitionID.isEmpty else { return }
        var document = read()
        let key = Self.songKey(chart)
        var song = document.songs.first { $0.key == key }
            ?? Song(key: key, selectedID: nil, pairs: [])
        document.songs.removeAll { $0.key == key }
        song.pairs.removeAll { $0.id == transitionID }
        song.pairs.append(Pair(id: transitionID, progress: SongCoachProgress(
            bpm: progress.bpm,
            comfortableRounds: progress.comfortableRounds,
            totalRounds: progress.totalRounds
        )))
        song.pairs = Array(song.pairs.suffix(128))
        song.selectedID = transitionID
        document.songs.append(song)
        document.songs = Array(document.songs.suffix(50))
        guard let data = try? JSONEncoder().encode(document) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    static func songKey(_ chart: ChordChart) -> String {
        if let url = chart.sourceURL { return "url:" + url.absoluteString }
        let title = (chart.title.isEmpty ? chart.sourceTitle : chart.title)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = chart.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return "title:\(title.utf8.count):\(title)artist:\(artist.utf8.count):\(artist)"
    }

    private struct Document: Codable {
        var version = 1
        var songs: [Song] = []
    }

    private struct Song: Codable {
        let key: String
        var selectedID: String?
        var pairs: [Pair]
    }

    private struct Pair: Codable {
        let id: String
        let progress: SongCoachProgress
    }

    private func read() -> Document {
        guard let data = defaults.data(forKey: Self.storageKey),
              data.count <= 8_000_000,
              let document = try? JSONDecoder().decode(Document.self, from: data),
              document.version == 1,
              document.songs.count <= 50,
              Set(document.songs.map(\.key)).count == document.songs.count,
              document.songs.allSatisfy({ song in
                  song.pairs.count <= 128 &&
                  Set(song.pairs.map(\.id)).count == song.pairs.count &&
                  song.pairs.allSatisfy { pair in
                      !pair.id.isEmpty && (40...300).contains(pair.progress.bpm) &&
                      pair.progress.totalRounds >= 0 && pair.progress.comfortableRounds >= 0 &&
                      pair.progress.comfortableRounds <= pair.progress.totalRounds
                  }
              }) else { return Document() }
        return document
    }
}
