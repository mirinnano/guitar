import Combine
import Foundation
import GuitarToolsCore

/// A chosen verified fingering is remembered by sounding chord identity, not by spelling.
@MainActor
final class ChordVoicingPreferencesStore: ObservableObject {
    static let shared = ChordVoicingPreferencesStore()
    static let storageKey = "guitar-tools.chord-voicings.v1"
    @Published private(set) var selections: [String: String]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey), data.count <= 1_000_000,
           let saved = try? JSONDecoder().decode([String: String].self, from: data),
           saved.count <= 1_000, saved.allSatisfy({ !$0.key.isEmpty && !$0.value.isEmpty }) {
            selections = saved
        } else {
            selections = [:]
        }
    }

    func selectedID(for symbol: String) -> String? {
        GuitarChordData.selectionKey(for: symbol).flatMap { selections[$0] }
    }

    func presentation(for symbol: String) -> ChordFingeringPresentation {
        ChordFingeringPresentation(symbol: symbol, voicingID: selectedID(for: symbol))
    }

    func select(_ voicingID: String?, for symbol: String) {
        guard let key = GuitarChordData.selectionKey(for: symbol) else { return }
        if let voicingID {
            guard let data = GuitarChordData(symbol: symbol), data.voicings.contains(where: { $0.id == voicingID }) else { return }
        }
        var copy = selections
        if let voicingID { copy[key] = voicingID }
        else { copy.removeValue(forKey: key) }
        while copy.count > 1_000 {
            guard let victim = copy.keys.filter({ $0 != key }).sorted().first else { break }
            copy.removeValue(forKey: victim)
        }
        guard copy != selections else { return }
        selections = copy
        if let data = try? JSONEncoder().encode(copy) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
