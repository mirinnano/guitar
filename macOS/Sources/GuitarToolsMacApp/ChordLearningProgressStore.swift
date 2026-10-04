import Foundation

/// Local self-reported recall history, not an objective measure of playing ability.
struct ChordLearningProgress: Codable, Equatable {
    var nextReviewAt: Date
    var successfulReviews: Int
    var lastPracticedAt: Date
    /// Separate from practice time so hints and early practice cannot create recall credit.
    var lastSuccessfulReviewAt: Date?

    init(
        nextReviewAt: Date,
        successfulReviews: Int = 0,
        lastPracticedAt: Date,
        lastSuccessfulReviewAt: Date? = nil
    ) {
        self.nextReviewAt = nextReviewAt
        self.successfulReviews = successfulReviews
        self.lastPracticedAt = lastPracticedAt
        // Conservatively treat existing successes without an explicit credit date
        // as credited on the last practice day, rather than allowing same-day farming.
        self.lastSuccessfulReviewAt = lastSuccessfulReviewAt ??
            (successfulReviews > 0 ? lastPracticedAt : nil)
    }
}

/// Versioned, bounded JSON containing only learning progress. Reads never remove
/// user data, including corrupt payloads or data belonging to other app features.
final class ChordLearningProgressStore {
    static let storageKey = "guitar-tools.chord-learning.v1"
    static let maximumRecords = 512
    static let maximumPayloadBytes = 1_000_000
    static let maximumSuccessfulReviews = 10_000

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Both parts are required: a sounding chord cannot inherit another geometry's history.
    func progress(selectionKey: String, voicingID: String) -> ChordLearningProgress? {
        read().entries.first {
            $0.selectionKey == selectionKey && $0.voicingID == voicingID
        }?.progress
    }

    func save(_ progress: ChordLearningProgress, selectionKey: String, voicingID: String) {
        let entry = Entry(selectionKey: selectionKey, voicingID: voicingID, progress: progress)
        guard Self.isValid(entry) else { return }
        var document = read()
        document.entries.removeAll { $0.key == entry.key }
        document.entries.append(entry)
        // Keep the most recently practiced geometries, without process-randomized hashes.
        document.entries = Array(document.entries.suffix(Self.maximumRecords))
        guard let data = try? JSONEncoder().encode(document),
              data.count <= Self.maximumPayloadBytes else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private struct Document: Codable {
        var version = 1
        var entries: [Entry] = []
    }

    private struct RecordKey: Hashable {
        let selectionKey: String
        let voicingID: String
    }

    private struct Entry: Codable {
        let selectionKey: String
        let voicingID: String
        let progress: ChordLearningProgress
        var key: RecordKey { RecordKey(selectionKey: selectionKey, voicingID: voicingID) }
    }

    private static func isValid(_ entry: Entry) -> Bool {
        let progress = entry.progress
        guard (1...128).contains(entry.selectionKey.utf8.count),
              (1...512).contains(entry.voicingID.utf8.count),
              (0...maximumSuccessfulReviews).contains(progress.successfulReviews),
              progress.nextReviewAt.timeIntervalSinceReferenceDate.isFinite,
              progress.lastPracticedAt.timeIntervalSinceReferenceDate.isFinite,
              progress.nextReviewAt >= progress.lastPracticedAt else { return false }
        if let creditedAt = progress.lastSuccessfulReviewAt {
            return progress.successfulReviews > 0 &&
                creditedAt.timeIntervalSinceReferenceDate.isFinite &&
                creditedAt <= progress.lastPracticedAt
        }
        return progress.successfulReviews == 0
    }

    private func read() -> Document {
        guard let data = defaults.data(forKey: Self.storageKey),
              data.count <= Self.maximumPayloadBytes,
              let document = try? JSONDecoder().decode(Document.self, from: data),
              document.version == 1,
              document.entries.count <= Self.maximumRecords,
              Set(document.entries.map(\.key)).count == document.entries.count,
              document.entries.allSatisfy(Self.isValid) else { return Document() }
        return document
    }
}
