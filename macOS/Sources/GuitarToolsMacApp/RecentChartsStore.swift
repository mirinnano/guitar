import Foundation

/// Remembers links explicitly opened by the user; chart contents are fetched only when selected.
@MainActor
final class RecentChartsStore {
    static let storageKey = "guitar-tools.recent-charts.v1"
    static let limit = 12
    private let defaults: UserDefaults
    private(set) var entries: [ChordWikiSearchResult]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey), data.count <= 100_000,
           let saved = try? JSONDecoder().decode([ChordWikiSearchResult].self, from: data) {
            var seen = Set<String>()
            entries = Array(saved.filter { Self.isValid($0) && seen.insert($0.id).inserted }.prefix(Self.limit))
        } else {
            entries = []
        }
    }

    func record(_ result: ChordWikiSearchResult) {
        guard Self.isValid(result) else { return }
        entries.removeAll { $0.id == result.id }
        entries.insert(result, at: 0)
        entries = Array(entries.prefix(Self.limit))
        save()
    }

    func remove(_ result: ChordWikiSearchResult) {
        entries.removeAll { $0.id == result.id }
        save()
    }

    private static func isValid(_ result: ChordWikiSearchResult) -> Bool {
        !result.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && result.url.scheme == "https" && ChordChartSource(url: result.url) != nil
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
