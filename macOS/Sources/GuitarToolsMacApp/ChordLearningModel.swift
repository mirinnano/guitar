import Combine
import Foundation
import GuitarToolsCore

enum ChordLearningDeck: String, CaseIterable, Identifiable {
    case starter, basic, sevenths

    var id: String { rawValue }

    var title: String {
        switch self {
        case .starter: return "はじめの3コード"
        case .basic: return "基本コード"
        case .sevenths: return "セブンスコード"
        }
    }

    var subtitle: String {
        switch self {
        case .starter: return "Em・Am・Cから始める"
        case .basic: return "よく使う9コード"
        case .sevenths: return "7th・m7・maj7の10コード"
        }
    }

    var symbols: [String] {
        switch self {
        case .starter: return ["Em", "Am", "C"]
        case .basic: return ["Em", "Am", "C", "G", "D", "A", "E", "Dm", "F"]
        case .sevenths: return ["C7", "D7", "E7", "G7", "A7", "B7", "Am7", "Em7", "Dm7", "Cmaj7"]
        }
    }
}

/// Explicit study / attempt / answer / self-rating steps. No audio, networking,
/// click transport or timers are started by this model.
@MainActor
final class ChordLearningModel: ObservableObject {
    enum Phase: Equatable {
        case idle, studying, recalling, revealed, completed
    }

    enum Rating: Equatable {
        case again, hard, remembered
    }

    /// Indexed by credited recall count: first exposure is tomorrow; the first
    /// delayed success advances to three days. Adjustable, not scientifically optimal.
    private static let recallIntervalsInDays = [1, 3, 7, 14, 30]
    private static let sessionCardLimit = 6

    @Published var selectedDeck: ChordLearningDeck = .starter {
        didSet {
            // Assigning a deck explicitly leaves a retained custom source. An
            // in-flight session, including its title and shapes, remains pinned.
            customSource = nil
            if !isSessionInProgress {
                clearSession()
                loadSource()
            }
            refresh()
        }
    }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var currentSymbol: String?
    @Published private(set) var position = 0
    /// Attempt count, including at most one additional retry per selected card.
    @Published private(set) var total = 0
    @Published private(set) var completedCount = 0
    /// Only due, unassisted, separately dated successful recall is counted here.
    @Published private(set) var sessionRecalled = 0
    @Published private(set) var sessionNeedsWork = 0
    @Published private(set) var activeSetTitle = ChordLearningDeck.starter.title
    /// Counts cover the complete eligible source, not just the six selected cards.
    @Published private(set) var dueCount = 0
    @Published private(set) var newCount = 0
    @Published private(set) var recallWasAssisted = false
    /// Lets the UI label an all-future session explicitly as early practice.
    @Published private(set) var isEarlyPractice = false

    private let store: ChordLearningProgressStore
    private let now: () -> Date
    private let calendar = Calendar.current
    private var customSource: Source?
    private var sourceCards: [Card] = []
    private var queue: [Attempt] = []
    private var sessionIndex = 0
    private var retriedVoicingIDs: Set<String> = []

    private struct Source {
        let symbols: [String]
        let title: String
    }

    private struct Card {
        let symbol: String
        let selectionKey: String
        /// Full fret, finger, barre and base-fret identity of the default shape.
        let voicing: GuitarChordVoicing
    }

    private enum AttemptKind: Equatable {
        case new, due, early, retry
    }

    private struct Attempt {
        let card: Card
        let kind: AttemptKind
    }

    init(
        progressStore: ChordLearningProgressStore? = nil,
        now: @escaping () -> Date = { Date() }
    ) {
        store = progressStore ?? ChordLearningProgressStore()
        self.now = now
        loadSource()
        refresh()
    }

    /// Complete eligible source, including a custom set retained after completion or exit.
    var sourceSymbols: [String] { sourceCards.map(\.symbol) }

    var hasCustomSource: Bool { customSource != nil }

    /// The immutable default-shape snapshot, never the user's alternative choice.
    var currentVoicing: GuitarChordVoicing? { currentAttempt?.card.voicing }

    var canCreditRecall: Bool {
        guard phase == .recalling || phase == .revealed,
              let attempt = currentAttempt else { return false }
        return canCredit(attempt, progress: savedProgress(for: attempt.card), at: now())
    }

    /// Restarts the entire retained custom source, or the currently selected deck.
    /// Due cards precede new cards; future cards are used only if neither exists.
    func startSession() {
        clearSession()
        loadSource()
        let date = now()
        var due: [(index: Int, card: Card, progress: ChordLearningProgress)] = []
        var new: [Card] = []
        var future: [(index: Int, card: Card, progress: ChordLearningProgress)] = []
        for (index, card) in sourceCards.enumerated() {
            if let progress = savedProgress(for: card) {
                if progress.nextReviewAt <= date {
                    due.append((index, card, progress))
                } else {
                    future.append((index, card, progress))
                }
            } else {
                new.append(card)
            }
        }
        due.sort { left, right in
            if left.progress.nextReviewAt == right.progress.nextReviewAt { return left.index < right.index }
            return left.progress.nextReviewAt < right.progress.nextReviewAt
        }
        let eligible = due.map { Attempt(card: $0.card, kind: .due) } +
            new.map { Attempt(card: $0, kind: .new) }
        if eligible.isEmpty && !future.isEmpty {
            future.sort { left, right in
                if left.progress.nextReviewAt == right.progress.nextReviewAt { return left.index < right.index }
                return left.progress.nextReviewAt < right.progress.nextReviewAt
            }
            queue = Array(future.prefix(Self.sessionCardLimit)).map { Attempt(card: $0.card, kind: .early) }
            isEarlyPractice = true
        } else {
            queue = Array(eligible.prefix(Self.sessionCardLimit))
        }
        total = queue.count
        if !queue.isEmpty { showCurrent() }
        refresh(at: date)
    }

    func startCustom(symbols: [String], title: String) {
        let writtenTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        customSource = Source(symbols: symbols, title: writtenTitle.isEmpty ? "選択したコード" : writtenTitle)
        startSession()
    }

    func hideDiagram() {
        guard phase == .studying else { return }
        // A first exposure followed by an immediate attempt is useful practice,
        // but is not a delayed, unassisted recall.
        recallWasAssisted = true
        phase = .recalling
    }

    func revealAnswer() {
        guard phase == .recalling else { return }
        // Checking an answer after an attempt is not a pre-attempt hint.
        phase = .revealed
    }

    func showHint() {
        guard phase == .studying || phase == .recalling else { return }
        recallWasAssisted = true
        phase = .revealed
    }

    func rate(_ rating: Rating) {
        guard phase == .revealed, let attempt = currentAttempt else { return }
        let date = now()
        let prior = savedProgress(for: attempt.card)
        let credited = rating == .remembered && canCredit(attempt, progress: prior, at: date)
        var progress = prior ?? ChordLearningProgress(nextReviewAt: tomorrow(after: date), lastPracticedAt: date)
        var nextReview = tomorrow(after: date)
        if credited {
            progress.successfulReviews = min(progress.successfulReviews + 1,
                                              ChordLearningProgressStore.maximumSuccessfulReviews)
            progress.lastSuccessfulReviewAt = date
            let intervalIndex = min(progress.successfulReviews, Self.recallIntervalsInDays.count - 1)
            nextReview = adding(days: Self.recallIntervalsInDays[intervalIndex], to: date)
            sessionRecalled += 1
        } else if rating == .remembered, !recallWasAssisted,
                  let prior, prior.nextReviewAt > date {
            // An early, unassisted repeat must not push the scheduled review out.
            // Assisted/first-study answers, again and hard still schedule tomorrow.
            nextReview = prior.nextReviewAt
        }
        // A clock moving backwards must not produce invalid persisted chronology.
        progress.lastPracticedAt = max(date, progress.lastPracticedAt)
        progress.nextReviewAt = max(nextReview, progress.lastPracticedAt)
        store.save(progress, selectionKey: attempt.card.selectionKey, voicingID: attempt.card.voicing.id)

        if rating == .again {
            sessionNeedsWork += 1
            if retriedVoicingIDs.insert(attempt.card.voicing.id).inserted {
                // Later than all currently queued cards. The retry itself cannot
                // earn credit, even if the session is left open overnight.
                queue.append(Attempt(card: attempt.card, kind: .retry))
                total = queue.count
            }
        } else if rating == .hard {
            sessionNeedsWork += 1
        }
        completedCount += 1
        sessionIndex += 1
        if sessionIndex < queue.count {
            showCurrent()
        } else {
            currentSymbol = nil
            position = 0
            recallWasAssisted = false
            phase = .completed
        }
        refresh(at: date)
    }

    func exitSession() {
        clearSession()
        loadSource()
        refresh()
    }

    /// Re-read external progress / the injected clock without restarting an attempt.
    func refresh() {
        refresh(at: now())
    }

    func progress(for symbol: String) -> ChordLearningProgress? {
        let presentation = ChordFingeringPresentation(symbol: symbol)
        guard presentation.availability == .supported,
              let key = GuitarChordData.selectionKey(for: presentation.symbol) else { return nil }
        if let card = sourceCards.first(where: { $0.selectionKey == key }) {
            return savedProgress(for: card)
        }
        guard let voicing = GuitarChordData(symbol: presentation.symbol)?.voicings.first else { return nil }
        return store.progress(selectionKey: key, voicingID: voicing.id)
    }

    private var isSessionInProgress: Bool {
        phase == .studying || phase == .recalling || phase == .revealed
    }

    private var currentAttempt: Attempt? {
        guard isSessionInProgress, queue.indices.contains(sessionIndex) else { return nil }
        return queue[sessionIndex]
    }

    private func canCredit(_ attempt: Attempt, progress: ChordLearningProgress?, at date: Date) -> Bool {
        guard attempt.kind == .due, !recallWasAssisted,
              let progress, progress.nextReviewAt <= date else { return false }
        if let lastCredit = progress.lastSuccessfulReviewAt {
            return date > lastCredit && !calendar.isDate(date, inSameDayAs: lastCredit)
        }
        return true
    }

    private func savedProgress(for card: Card) -> ChordLearningProgress? {
        store.progress(selectionKey: card.selectionKey, voicingID: card.voicing.id)
    }

    private func loadSource() {
        let source = customSource ?? Source(symbols: selectedDeck.symbols, title: selectedDeck.title)
        sourceCards = Self.cards(for: source.symbols)
        activeSetTitle = source.title
        if customSource != nil {
            // Retain every eligible source card, not the truncated session queue.
            customSource = Source(symbols: sourceCards.map(\.symbol), title: source.title)
        }
    }

    private static func cards(for symbols: [String]) -> [Card] {
        var seen: Set<String> = []
        var cards: [Card] = []
        for symbol in symbols {
            let presentation = ChordFingeringPresentation(symbol: symbol)
            guard presentation.availability == .supported,
                  let key = GuitarChordData.selectionKey(for: presentation.symbol),
                  seen.insert(key).inserted,
                  let voicing = GuitarChordData(symbol: presentation.symbol)?.voicings.first else { continue }
            cards.append(Card(symbol: presentation.symbol, selectionKey: key, voicing: voicing))
        }
        return cards
    }

    private func showCurrent() {
        let attempt = queue[sessionIndex]
        currentSymbol = attempt.card.symbol
        position = sessionIndex + 1
        recallWasAssisted = attempt.kind == .new || attempt.kind == .retry
        phase = attempt.kind == .new ? .studying : .recalling
    }

    private func clearSession() {
        queue = []
        retriedVoicingIDs = []
        sessionIndex = 0
        currentSymbol = nil
        position = 0
        total = 0
        completedCount = 0
        sessionRecalled = 0
        sessionNeedsWork = 0
        recallWasAssisted = false
        isEarlyPractice = false
        phase = .idle
    }

    private func refresh(at date: Date) {
        var due = 0
        var new = 0
        for card in sourceCards {
            if let progress = savedProgress(for: card) {
                if progress.nextReviewAt <= date { due += 1 }
            } else {
                new += 1
            }
        }
        dueCount = due
        newCount = new
    }

    private func tomorrow(after date: Date) -> Date { adding(days: 1, to: date) }

    private func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ??
            date.addingTimeInterval(Double(days) * 86_400)
    }
}
