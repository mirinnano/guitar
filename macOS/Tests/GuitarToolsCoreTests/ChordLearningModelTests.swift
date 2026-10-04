import Foundation
import XCTest
@testable import GuitarToolsCore
@testable import GuitarToolsMacApp

@MainActor
final class ChordLearningModelTests: XCTestCase {
    func testDeckContractAndIdleGuards() async {
        XCTAssertEqual(ChordLearningDeck.allCases, [.starter, .basic, .sevenths])
        XCTAssertEqual(ChordLearningDeck.starter.symbols, ["Em", "Am", "C"])
        XCTAssertEqual(ChordLearningDeck.basic.symbols, ["Em", "Am", "C", "G", "D", "A", "E", "Dm", "F"])
        XCTAssertEqual(ChordLearningDeck.sevenths.symbols,
                       ["C7", "D7", "E7", "G7", "A7", "B7", "Am7", "Em7", "Dm7", "Cmaj7"])
        for deck in ChordLearningDeck.allCases {
            XCTAssertEqual(deck.id, deck.rawValue)
            XCTAssertFalse(deck.title.isEmpty)
            XCTAssertFalse(deck.subtitle.isEmpty)
        }
        let h = makeHarness()
        XCTAssertEqual(h.model.selectedDeck, .starter)
        XCTAssertEqual(h.model.phase, .idle)
        XCTAssertNil(h.model.currentSymbol)
        XCTAssertNil(h.model.currentVoicing)
        XCTAssertEqual(h.model.position, 0)
        XCTAssertEqual(h.model.total, 0)
        XCTAssertEqual(h.model.completedCount, 0)
        XCTAssertEqual(h.model.activeSetTitle, ChordLearningDeck.starter.title)
        XCTAssertEqual(h.model.dueCount, 0)
        XCTAssertEqual(h.model.newCount, 3)
        XCTAssertFalse(h.model.canCreditRecall)
        XCTAssertFalse(h.model.recallWasAssisted)
        XCTAssertFalse(h.model.isEarlyPractice)
        h.model.hideDiagram()
        h.model.revealAnswer()
        h.model.showHint()
        for rating in [ChordLearningModel.Rating.again, .hard, .remembered] { h.model.rate(rating) }
        XCTAssertEqual(h.model.phase, .idle)
        XCTAssertNil(h.defaults.data(forKey: ChordLearningProgressStore.storageKey))
    }

    func testFirstStudyMustAttemptOrHintBeforeRatingAndCannotEarnRecall() async throws {
        let h = makeHarness()
        h.model.startCustom(symbols: ["Em"], title: "First chord")
        XCTAssertEqual(h.model.phase, .studying)
        XCTAssertEqual(h.model.currentSymbol, "Em")
        XCTAssertEqual(h.model.position, 1)
        XCTAssertEqual(h.model.total, 1)
        XCTAssertFalse(h.model.canCreditRecall)
        for rating in [ChordLearningModel.Rating.again, .hard, .remembered] { h.model.rate(rating) }
        h.model.revealAnswer()
        XCTAssertEqual(h.model.phase, .studying)
        XCTAssertEqual(h.model.completedCount, 0)
        XCTAssertNil(h.model.progress(for: "Em"))

        h.model.hideDiagram()
        XCTAssertEqual(h.model.phase, .recalling)
        XCTAssertTrue(h.model.recallWasAssisted)
        XCTAssertFalse(h.model.canCreditRecall)
        h.model.rate(.remembered)
        XCTAssertNil(h.model.progress(for: "Em"), "A hidden diagram alone is not a completed attempt")
        h.model.revealAnswer()
        XCTAssertEqual(h.model.phase, .revealed)
        XCTAssertTrue(h.model.recallWasAssisted)
        h.model.rate(.remembered)
        let saved = try XCTUnwrap(h.model.progress(for: "Em"))
        XCTAssertEqual(saved.successfulReviews, 0)
        XCTAssertNil(saved.lastSuccessfulReviewAt)
        XCTAssertEqual(saved.lastPracticedAt, h.clock.date)
        XCTAssertEqual(saved.nextReviewAt, day(1, after: h.clock.date))
        XCTAssertEqual(h.model.phase, .completed)
        XCTAssertNil(h.model.currentSymbol)
        XCTAssertEqual(h.model.completedCount, 1)
        XCTAssertEqual(h.model.sessionRecalled, 0)
        XCTAssertEqual(h.model.sessionNeedsWork, 0)
        XCTAssertFalse(h.model.canCreditRecall)
        let payload = h.defaults.data(forKey: ChordLearningProgressStore.storageKey)
        h.model.rate(.again)
        h.model.rate(.remembered)
        h.model.hideDiagram()
        h.model.showHint()
        h.model.revealAnswer()
        XCTAssertEqual(h.model.phase, .completed)
        XCTAssertEqual(h.model.total, 1)
        XCTAssertEqual(h.defaults.data(forKey: ChordLearningProgressStore.storageKey), payload)
    }

    func testDueRevealChecksAnswerWithoutAssistingAndCreditsRecall() async throws {
        let h = makeHarness()
        let prior = try seed(h, symbol: "C", dueInDays: -1, successes: 2)
        h.model.startCustom(symbols: ["C"], title: "Review")
        XCTAssertEqual(h.model.phase, .recalling)
        XCTAssertTrue(h.model.canCreditRecall)
        XCTAssertFalse(h.model.recallWasAssisted)
        h.model.hideDiagram()
        h.model.rate(.remembered)
        XCTAssertEqual(h.model.completedCount, 0)
        XCTAssertEqual(h.model.progress(for: "C"), prior)
        h.model.revealAnswer()
        h.model.revealAnswer()
        h.model.showHint() // The answer is already revealed, not a pre-attempt hint.
        XCTAssertEqual(h.model.phase, .revealed)
        XCTAssertTrue(h.model.canCreditRecall)
        XCTAssertFalse(h.model.recallWasAssisted)
        h.model.rate(.remembered)
        let saved = try XCTUnwrap(h.model.progress(for: "C"))
        XCTAssertEqual(saved.successfulReviews, 3)
        XCTAssertEqual(saved.nextReviewAt, day(14, after: h.clock.date))
        XCTAssertEqual(saved.lastSuccessfulReviewAt, h.clock.date)
        XCTAssertEqual(h.model.sessionRecalled, 1)
        XCTAssertEqual(h.model.sessionNeedsWork, 0)
    }

    func testHintRevealsButNeverCreditsAndHardSchedulesTomorrow() async throws {
        let h = makeHarness()
        let prior = try seed(h, symbol: "C", dueInDays: -1, successes: 2)
        h.model.startCustom(symbols: ["C"], title: "Hint")
        h.model.showHint()
        XCTAssertEqual(h.model.phase, .revealed)
        XCTAssertTrue(h.model.recallWasAssisted)
        XCTAssertFalse(h.model.canCreditRecall)
        h.model.revealAnswer()
        h.model.rate(.remembered)
        let assisted = try XCTUnwrap(h.model.progress(for: "C"))
        XCTAssertEqual(assisted.successfulReviews, 2)
        XCTAssertEqual(assisted.lastSuccessfulReviewAt, prior.lastSuccessfulReviewAt)
        XCTAssertEqual(assisted.nextReviewAt, day(1, after: h.clock.date))
        XCTAssertEqual(h.model.sessionRecalled, 0)

        h.clock.date = assisted.nextReviewAt
        h.model.startSession()
        h.model.revealAnswer()
        h.model.rate(.hard)
        let hard = try XCTUnwrap(h.model.progress(for: "C"))
        XCTAssertEqual(hard.successfulReviews, 2)
        XCTAssertEqual(hard.lastSuccessfulReviewAt, prior.lastSuccessfulReviewAt)
        XCTAssertEqual(hard.nextReviewAt, day(1, after: h.clock.date))
        XCTAssertEqual(h.model.sessionRecalled, 0)
        XCTAssertEqual(h.model.sessionNeedsWork, 1)

        h.model.startCustom(symbols: ["Am"], title: "New hint")
        h.model.showHint()
        XCTAssertEqual(h.model.phase, .revealed)
        XCTAssertTrue(h.model.recallWasAssisted)
        h.model.rate(.remembered)
        XCTAssertEqual(h.model.progress(for: "Am")?.successfulReviews, 0)
    }

    func testHeuristicIntervalsRequireSeparateDueRecallDays() async throws {
        let h = makeHarness()
        h.model.startCustom(symbols: ["C"], title: "Intervals")
        studyAndRemember(h.model)
        XCTAssertEqual(h.model.progress(for: "C")?.successfulReviews, 0)
        for (index, interval) in [3, 7, 14, 30, 30, 30].enumerated() {
            h.clock.date = try XCTUnwrap(h.model.progress(for: "C")).nextReviewAt
            h.model.startSession()
            XCTAssertEqual(h.model.phase, .recalling)
            XCTAssertFalse(h.model.isEarlyPractice)
            XCTAssertTrue(h.model.canCreditRecall)
            h.model.revealAnswer()
            h.model.rate(.remembered)
            let saved = try XCTUnwrap(h.model.progress(for: "C"))
            XCTAssertEqual(saved.successfulReviews, index + 1)
            XCTAssertEqual(saved.nextReviewAt, day(interval, after: h.clock.date))
            XCTAssertEqual(h.model.sessionRecalled, 1)
        }
    }

    func testSameDayAndEarlyPracticeCannotFarmMasteryOrPostponeReview() async throws {
        let h = makeHarness()
        h.model.startCustom(symbols: ["C"], title: "Practice")
        studyAndRemember(h.model)
        let first = try XCTUnwrap(h.model.progress(for: "C"))
        for _ in 0..<4 {
            h.model.startSession()
            XCTAssertTrue(h.model.isEarlyPractice)
            XCTAssertEqual(h.model.phase, .recalling)
            XCTAssertFalse(h.model.canCreditRecall)
            h.model.revealAnswer()
            h.model.rate(.remembered)
            XCTAssertEqual(h.model.progress(for: "C")?.successfulReviews, 0)
            XCTAssertEqual(h.model.progress(for: "C")?.nextReviewAt, first.nextReviewAt)
            XCTAssertEqual(h.model.sessionRecalled, 0)
        }
        h.clock.date = first.nextReviewAt
        h.model.startSession()
        h.model.revealAnswer()
        h.model.rate(.remembered)
        h.clock.date = try XCTUnwrap(h.model.progress(for: "C")).nextReviewAt
        h.model.startSession()
        h.model.revealAnswer()
        h.model.rate(.remembered)
        let credited = try XCTUnwrap(h.model.progress(for: "C"))
        XCTAssertEqual(credited.successfulReviews, 2)
        XCTAssertEqual(credited.nextReviewAt, day(7, after: h.clock.date))
        for offset in 0...2 {
            if offset > 0 { h.clock.date = day(1, after: h.clock.date) }
            h.model.startSession()
            XCTAssertTrue(h.model.isEarlyPractice)
            XCTAssertFalse(h.model.canCreditRecall, "A different day alone does not make an early card due")
            h.model.revealAnswer()
            h.model.rate(.remembered)
            XCTAssertEqual(h.model.progress(for: "C")?.successfulReviews, 2)
            XCTAssertEqual(h.model.progress(for: "C")?.nextReviewAt, credited.nextReviewAt)
        }
        XCTAssertEqual(h.model.progress(for: "C")?.lastPracticedAt, h.clock.date)
        XCTAssertEqual(h.model.progress(for: "C")?.lastSuccessfulReviewAt, credited.lastSuccessfulReviewAt)
    }

    func testDueCardAlreadyCreditedTodayAndConcurrentWindowsCannotDoubleCredit() async throws {
        let h = makeHarness()
        let creditedToday = ChordLearningProgress(
            nextReviewAt: h.clock.date.addingTimeInterval(-3_600), successfulReviews: 1,
            lastPracticedAt: h.clock.date.addingTimeInterval(-7_200)
        )
        try save(creditedToday, in: h.store, symbol: "C")
        h.model.startCustom(symbols: ["C"], title: "Same day")
        XCTAssertEqual(h.model.phase, .recalling)
        XCTAssertFalse(h.model.isEarlyPractice)
        XCTAssertFalse(h.model.canCreditRecall)
        h.model.revealAnswer()
        h.model.rate(.remembered)
        XCTAssertEqual(h.model.progress(for: "C")?.successfulReviews, 1)
        XCTAssertEqual(h.model.sessionRecalled, 0)

        h.clock.date = day(1, after: h.clock.date)
        h.model.startSession()
        let second = h.makeModel()
        second.startCustom(symbols: ["Cmaj"], title: "Other window")
        XCTAssertTrue(h.model.canCreditRecall)
        XCTAssertTrue(second.canCreditRecall)
        h.model.revealAnswer()
        h.model.rate(.remembered)
        XCTAssertFalse(second.canCreditRecall, "Eligibility must re-check persisted credit, not just a session snapshot")
        second.revealAnswer()
        second.rate(.remembered)
        XCTAssertEqual(second.progress(for: "C/C")?.successfulReviews, 2)
        XCTAssertEqual(second.sessionRecalled, 0)
        XCTAssertEqual(second.progress(for: "C")?.nextReviewAt, day(7, after: h.clock.date))
    }

    func testLeavingAnEarlyAttemptOpenUntilDueDoesNotTurnItIntoCreditedRecall() async throws {
        let h = makeHarness()
        try seed(h, symbol: "C", dueInDays: 1, successes: 2)
        h.model.startCustom(symbols: ["C"], title: "Early")
        XCTAssertTrue(h.model.isEarlyPractice)
        h.clock.date = day(2, after: h.clock.date)
        h.model.refresh()
        XCTAssertEqual(h.model.dueCount, 1)
        XCTAssertFalse(h.model.canCreditRecall)
        h.model.revealAnswer()
        h.model.rate(.remembered)
        XCTAssertEqual(h.model.progress(for: "C")?.successfulReviews, 2)
        XCTAssertEqual(h.model.sessionRecalled, 0)
    }

    func testAgainReinsertsOnceLaterAndRetryIsAssisted() async throws {
        let h = makeHarness()
        let prior = try seed(h, symbol: "C", dueInDays: -1, successes: 2)
        h.model.startCustom(symbols: ["C", "G"], title: "Retry")
        h.model.revealAnswer()
        h.model.rate(.again)
        XCTAssertEqual(h.model.currentSymbol, "G")
        XCTAssertEqual(h.model.phase, .studying)
        XCTAssertEqual(h.model.total, 3)
        XCTAssertEqual(h.model.position, 2)
        XCTAssertEqual(h.model.completedCount, 1)
        XCTAssertEqual(h.model.sessionNeedsWork, 1)
        XCTAssertEqual(h.model.progress(for: "C")?.nextReviewAt, day(1, after: h.clock.date))
        studyAndRemember(h.model)
        XCTAssertEqual(h.model.currentSymbol, "C")
        XCTAssertEqual(h.model.position, 3)
        XCTAssertEqual(h.model.phase, .recalling)
        XCTAssertTrue(h.model.recallWasAssisted)
        XCTAssertFalse(h.model.canCreditRecall)
        h.clock.date = day(2, after: h.clock.date)
        h.model.refresh()
        XCTAssertFalse(h.model.canCreditRecall, "A retry is not fresh unassisted recall even on a later day")
        h.model.revealAnswer()
        h.model.rate(.again)
        XCTAssertEqual(h.model.phase, .completed)
        XCTAssertEqual(h.model.total, 3)
        XCTAssertEqual(h.model.completedCount, 3)
        XCTAssertEqual(h.model.sessionNeedsWork, 2)
        XCTAssertEqual(h.model.sessionRecalled, 0)
        XCTAssertEqual(h.model.progress(for: "C")?.successfulReviews, prior.successfulReviews)
        XCTAssertEqual(h.model.progress(for: "C")?.lastSuccessfulReviewAt, prior.lastSuccessfulReviewAt)
        for _ in 0..<10 { h.model.rate(.again) }
        XCTAssertEqual(h.model.total, 3)
    }

    func testEveryAgainIsBoundedToTwelveAttemptsForSixDistinctCards() async {
        let h = makeHarness()
        h.model.selectedDeck = .basic
        h.model.startSession()
        var seen: [String] = []
        for _ in 0..<12 {
            if let symbol = h.model.currentSymbol { seen.append(symbol) }
            if h.model.phase == .studying { h.model.hideDiagram() }
            h.model.revealAnswer()
            h.model.rate(.again)
        }
        let firstSix = Array(ChordLearningDeck.basic.symbols.prefix(6))
        XCTAssertEqual(seen, firstSix + firstSix)
        XCTAssertEqual(h.model.phase, .completed)
        XCTAssertEqual(h.model.total, 12)
        XCTAssertEqual(h.model.completedCount, 12)
        XCTAssertEqual(h.model.sessionNeedsWork, 12)
        XCTAssertEqual(h.model.sessionRecalled, 0)
        h.model.exitSession()
        XCTAssertEqual(h.model.phase, .idle)
        XCTAssertEqual(h.model.total, 0)
        XCTAssertEqual(h.model.completedCount, 0)
        XCTAssertEqual(h.model.sessionNeedsWork, 0)
        XCTAssertFalse(h.model.recallWasAssisted)
    }

    func testQueueUsesOldestDueThenNewAndDoesNotFillWithFutureCards() async throws {
        let h = makeHarness()
        h.model.selectedDeck = .basic
        try seed(h, symbol: "Em", dueInDays: 4)
        try seed(h, symbol: "Am", dueInDays: -1)
        try seed(h, symbol: "C", dueInDays: -2)
        h.model.refresh()
        XCTAssertEqual(h.model.dueCount, 2)
        XCTAssertEqual(h.model.newCount, 6)
        h.model.startSession()
        XCTAssertEqual(h.model.total, 6)
        XCTAssertFalse(h.model.isEarlyPractice)
        var seen: [String] = []
        for index in 0..<6 {
            seen.append(try XCTUnwrap(h.model.currentSymbol))
            XCTAssertEqual(h.model.position, index + 1)
            XCTAssertEqual(h.model.phase, index < 2 ? .recalling : .studying)
            if h.model.phase == .studying { h.model.hideDiagram() }
            h.model.revealAnswer()
            h.model.rate(.remembered)
        }
        XCTAssertEqual(seen, ["C", "Am", "G", "D", "A", "E"])
        XCTAssertEqual(h.model.phase, .completed)
        XCTAssertEqual(h.model.sessionRecalled, 2)
        XCTAssertEqual(h.model.newCount, 2)
        XCTAssertEqual(h.model.dueCount, 0)
        h.model.startSession()
        XCTAssertEqual(h.model.total, 2)
        XCTAssertEqual(h.model.currentSymbol, "Dm")
        XCTAssertFalse(h.model.isEarlyPractice)
        studyAndRemember(h.model)
        XCTAssertEqual(h.model.currentSymbol, "F")
        studyAndRemember(h.model)
        h.model.startSession()
        XCTAssertTrue(h.model.isEarlyPractice)
        XCTAssertEqual(h.model.total, 6)
        XCTAssertEqual(h.model.phase, .recalling)
        XCTAssertFalse(h.model.canCreditRecall)
    }

    func testCustomSourceFiltersUnsafeDedupeAliasesAndPreservesExactSlashBass() async throws {
        let h = makeHarness()
        let source = ["  CM \n", "C/C", "Cmaj", "Dbmaj7", "C#M7", "B♭maj7/D", "A#M7/D",
                      "C6/9", "C6/9/C", "C/D", "NC", " n.c. ", "Cunknown/E", "C/unknown",
                      "C/", "C/G/H", "C7((b9))", "C(m)(7)"]
        h.model.startCustom(symbols: source, title: "  Song chords \n")
        XCTAssertEqual(h.model.activeSetTitle, "Song chords")
        XCTAssertEqual(h.model.newCount, 5)
        XCTAssertEqual(h.model.total, 5)
        var seen: [String] = []
        for _ in 0..<5 {
            let symbol = try XCTUnwrap(h.model.currentSymbol)
            seen.append(symbol)
            let voicing = try XCTUnwrap(h.model.currentVoicing)
            let presentation = ChordFingeringPresentation(symbol: symbol)
            XCTAssertEqual(presentation.availability, .supported)
            XCTAssertEqual(voicing.shape, presentation.shape)
            XCTAssertEqual(voicing.id, GuitarChordData(symbol: symbol)?.voicings.first?.id)
            if let bass = presentation.slashBass {
                let expectedBass = try XCTUnwrap(ParsedGuitarChordSymbol("C/" + bass)?.bass)
                XCTAssertEqual(voicing.stringNotes.compactMap(\.midi).min().map(GuitarNote.fromMIDI), expectedBass)
            }
            studyAndRemember(h.model)
        }
        XCTAssertEqual(seen, ["CM", "Dbmaj7", "B♭maj7/D", "C6/9", "C/D"])
        XCTAssertEqual(h.model.progress(for: "C"), h.model.progress(for: "C/C"))
        XCTAssertEqual(h.model.progress(for: "DbM7"), h.model.progress(for: "C#maj7"))
        XCTAssertEqual(h.model.progress(for: "B♭maj7/D"), h.model.progress(for: "A#M7/D"))
        XCTAssertNil(h.model.progress(for: "C/E"), "A different sounding slash bass has separate history")
        XCTAssertNil(h.model.progress(for: "C6"))
        XCTAssertNil(h.model.progress(for: "NC"))
        XCTAssertNil(h.model.progress(for: "Cunknown/E"))
    }

    func testCustomRetainsAllEligibleCardsBeyondSixAndDeckAssignmentLeavesCustom() async {
        let h = makeHarness()
        let source = ChordLearningDeck.basic.symbols + ["CM", "C/C", "NC", "C/unknown"]
        h.model.startCustom(symbols: source, title: "All song chords")
        XCTAssertEqual(h.model.total, 6)
        XCTAssertEqual(h.model.newCount, 9)
        for _ in 0..<6 { studyAndRemember(h.model) }
        XCTAssertEqual(h.model.newCount, 3)
        h.model.exitSession()
        XCTAssertEqual(h.model.activeSetTitle, "All song chords")
        XCTAssertEqual(h.model.newCount, 3)
        h.model.startSession()
        XCTAssertEqual(h.model.activeSetTitle, "All song chords")
        XCTAssertEqual(h.model.total, 3)
        XCTAssertEqual(h.model.currentSymbol, "E")
        for _ in 0..<3 { studyAndRemember(h.model) }
        h.model.selectedDeck = .sevenths
        XCTAssertEqual(h.model.phase, .idle)
        XCTAssertEqual(h.model.activeSetTitle, ChordLearningDeck.sevenths.title)
        XCTAssertEqual(h.model.newCount, 10)
        h.model.startSession()
        XCTAssertEqual(h.model.total, 6)
        XCTAssertEqual(h.model.currentSymbol, "C7")
    }

    func testCustomOverviewRetainsActualSourceAfterCompletionAndExitUntilExplicitDeckAssignment() async {
        let h = makeHarness()
        h.model.selectedDeck = .basic
        XCTAssertFalse(h.model.hasCustomSource)
        XCTAssertEqual(h.model.sourceSymbols, ChordLearningDeck.basic.symbols)

        h.model.startCustom(symbols: ["D7", "D7/D", "G7", "NC", "Cunknown/E"], title: "Song chords")
        let eligible = ["D7", "G7"]
        XCTAssertTrue(h.model.hasCustomSource)
        XCTAssertEqual(h.model.sourceSymbols, eligible)
        for _ in eligible { studyAndRemember(h.model) }
        XCTAssertEqual(h.model.phase, .completed)
        XCTAssertTrue(h.model.hasCustomSource)
        XCTAssertEqual(h.model.sourceSymbols, eligible)
        XCTAssertEqual(h.model.activeSetTitle, "Song chords")
        XCTAssertEqual(h.model.selectedDeck, .basic)

        h.model.exitSession()
        XCTAssertEqual(h.model.phase, .idle)
        XCTAssertTrue(h.model.hasCustomSource)
        XCTAssertEqual(h.model.sourceSymbols, eligible)
        XCTAssertEqual(h.model.activeSetTitle, "Song chords")
        h.model.startSession()
        XCTAssertEqual(h.model.currentSymbol, "D7")
        XCTAssertEqual(h.model.total, 2)
        XCTAssertTrue(h.model.hasCustomSource)
        XCTAssertEqual(h.model.sourceSymbols, eligible)
        h.model.exitSession()

        // Even assigning the already selected deck explicitly leaves the custom source.
        h.model.selectedDeck = .basic
        XCTAssertEqual(h.model.phase, .idle)
        XCTAssertFalse(h.model.hasCustomSource)
        XCTAssertEqual(h.model.sourceSymbols, ChordLearningDeck.basic.symbols)
        XCTAssertEqual(h.model.activeSetTitle, ChordLearningDeck.basic.title)
        h.model.startSession()
        XCTAssertEqual(h.model.currentSymbol, "Em")
        XCTAssertEqual(h.model.total, 6)
        XCTAssertFalse(h.model.hasCustomSource)
    }

    func testRatingPersistsIncrementallyAndUnratedCardsRemainNewAfterExitAndReload() async throws {
        let h = makeHarness()
        h.model.startSession()
        studyAndRemember(h.model)
        XCTAssertEqual(h.model.currentSymbol, "Am")
        let saved = try XCTUnwrap(h.model.progress(for: "Em"))
        h.model.exitSession()
        XCTAssertEqual(h.model.phase, .idle)
        XCTAssertEqual(h.model.newCount, 2)
        XCTAssertEqual(h.model.total, 0)
        let reloaded = h.makeModel()
        XCTAssertEqual(reloaded.progress(for: "Emin"), saved)
        XCTAssertNil(reloaded.progress(for: "Am"))
        XCTAssertNil(reloaded.progress(for: "C"))
        XCTAssertEqual(reloaded.newCount, 2)
        reloaded.startSession()
        XCTAssertEqual(reloaded.total, 2)
        XCTAssertEqual(reloaded.currentSymbol, "Am")
        XCTAssertFalse(reloaded.isEarlyPractice)
    }

    func testPreviousDefaultGeometryCountsAsNewAndAlternativePreferencesAreIgnored() async throws {
        let h = makeHarness()
        let data = try XCTUnwrap(GuitarChordData(symbol: "C"))
        let defaultVoicing = try XCTUnwrap(data.voicings.first)
        // A still-valid alternative stands in for a previous release's default.
        let previousDefault = try XCTUnwrap(data.voicings.dropFirst().first)
        let old = ChordLearningProgress(nextReviewAt: h.clock.date, successfulReviews: 4,
                                        lastPracticedAt: day(-4, after: h.clock.date))
        h.store.save(old, selectionKey: data.selectionKey, voicingID: previousDefault.id)
        let preferences = ChordVoicingPreferencesStore(defaults: h.defaults)
        preferences.select(previousDefault.id, for: "CM")
        let preferencesPayload = h.defaults.data(forKey: ChordVoicingPreferencesStore.storageKey)
        h.model.startCustom(symbols: ["C"], title: "Pinned default")
        XCTAssertEqual(h.model.phase, .studying)
        XCTAssertEqual(h.model.newCount, 1)
        XCTAssertEqual(h.model.dueCount, 0)
        XCTAssertNil(h.model.progress(for: "C"))
        XCTAssertEqual(h.model.currentVoicing, defaultVoicing)
        preferences.select(data.voicings.last?.id, for: "C")
        h.model.refresh()
        XCTAssertEqual(h.model.currentVoicing, defaultVoicing)
        studyAndRemember(h.model)
        XCTAssertEqual(h.model.progress(for: "C")?.successfulReviews, 0)
        XCTAssertEqual(h.store.progress(selectionKey: data.selectionKey, voicingID: previousDefault.id), old)
        XCTAssertNotNil(preferencesPayload)
        XCTAssertNotNil(preferences.selectedID(for: "C"), "Learning must not reset user voicing preferences")
    }

    func testRefreshAndDeckChangeDoNotReplaceAnInFlightSnapshot() async throws {
        let h = makeHarness()
        try seed(h, symbol: "Em", dueInDays: -1)
        h.model.startSession()
        let voicing = h.model.currentVoicing
        let title = h.model.activeSetTitle
        let external = ChordLearningProgress(nextReviewAt: day(3, after: h.clock.date), successfulReviews: 2,
                                             lastPracticedAt: h.clock.date)
        try save(external, in: h.store, symbol: "Em")
        h.model.refresh()
        XCTAssertEqual(h.model.phase, .recalling)
        XCTAssertEqual(h.model.currentSymbol, "Em")
        XCTAssertEqual(h.model.currentVoicing, voicing)
        XCTAssertEqual(h.model.position, 1)
        XCTAssertFalse(h.model.canCreditRecall)
        XCTAssertEqual(h.model.dueCount, 0)
        h.model.selectedDeck = .sevenths
        XCTAssertEqual(h.model.phase, .recalling)
        XCTAssertEqual(h.model.currentSymbol, "Em")
        XCTAssertEqual(h.model.currentVoicing, voicing)
        XCTAssertEqual(h.model.activeSetTitle, title)
        h.model.exitSession()
        XCTAssertEqual(h.model.activeSetTitle, ChordLearningDeck.sevenths.title)
        XCTAssertEqual(h.model.newCount, 10)
    }

    func testUnavailableOnlyCustomSetNeverStartsOrPersistsAnything() async {
        let h = makeHarness()
        h.model.startCustom(symbols: ["NC", "N.C.", "Cunknown/E", "C/unknown", "C/G/H", ""], title: "")
        XCTAssertEqual(h.model.phase, .idle)
        XCTAssertNil(h.model.currentSymbol)
        XCTAssertNil(h.model.currentVoicing)
        XCTAssertEqual(h.model.total, 0)
        XCTAssertEqual(h.model.dueCount, 0)
        XCTAssertEqual(h.model.newCount, 0)
        XCTAssertFalse(h.model.canCreditRecall)
        h.model.showHint()
        h.model.rate(.remembered)
        XCTAssertNil(h.defaults.data(forKey: ChordLearningProgressStore.storageKey))
    }

    private func makeHarness() -> LearningHarness {
        let suite = "ChordLearningModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let date = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
            .addingTimeInterval(12 * 3_600)
        return LearningHarness(defaults: defaults, date: date)
    }

    @discardableResult
    private func seed(_ h: LearningHarness, symbol: String, dueInDays: Int, successes: Int = 0) throws -> ChordLearningProgress {
        let practicedAt = day(min(-10, dueInDays - 1), after: h.clock.date)
        let progress = ChordLearningProgress(nextReviewAt: day(dueInDays, after: h.clock.date),
                                             successfulReviews: successes, lastPracticedAt: practicedAt)
        try save(progress, in: h.store, symbol: symbol)
        return progress
    }

    private func save(_ progress: ChordLearningProgress, in store: ChordLearningProgressStore, symbol: String) throws {
        let data = try XCTUnwrap(GuitarChordData(symbol: symbol))
        let voicing = try XCTUnwrap(data.voicings.first)
        store.save(progress, selectionKey: data.selectionKey, voicingID: voicing.id)
    }

    private func studyAndRemember(_ model: ChordLearningModel) {
        model.hideDiagram()
        model.revealAnswer()
        model.rate(.remembered)
    }

    private func day(_ days: Int, after date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date)!
    }
}

@MainActor
private final class LearningClock {
    var date: Date
    init(date: Date) { self.date = date }
}

@MainActor
private struct LearningHarness {
    let defaults: UserDefaults
    let store: ChordLearningProgressStore
    let clock: LearningClock
    let model: ChordLearningModel

    init(defaults: UserDefaults, date: Date) {
        self.defaults = defaults
        store = ChordLearningProgressStore(defaults: defaults)
        clock = LearningClock(date: date)
        let clock = self.clock
        model = ChordLearningModel(progressStore: store, now: { clock.date })
    }

    func makeModel() -> ChordLearningModel {
        ChordLearningModel(progressStore: ChordLearningProgressStore(defaults: defaults), now: { clock.date })
    }
}
