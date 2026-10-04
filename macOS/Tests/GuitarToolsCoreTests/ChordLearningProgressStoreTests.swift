import Foundation
import GuitarToolsCore
import XCTest
@testable import GuitarToolsMacApp

final class ChordLearningProgressStoreTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    func testVersionedRoundTripRequiresBothSoundingIdentityAndFullGeometry() throws {
        let defaults = isolatedDefaults()
        let store = ChordLearningProgressStore(defaults: defaults)
        let c = try XCTUnwrap(GuitarChordData(symbol: "C"))
        let defaultVoicing = try XCTUnwrap(c.voicings.first)
        let progress = ChordLearningProgress(nextReviewAt: date.addingTimeInterval(3 * 86_400),
                                             successfulReviews: 2, lastPracticedAt: date,
                                             lastSuccessfulReviewAt: date.addingTimeInterval(-86_400))
        store.save(progress, selectionKey: c.selectionKey, voicingID: defaultVoicing.id)
        let reloaded = ChordLearningProgressStore(defaults: defaults)
        XCTAssertEqual(reloaded.progress(selectionKey: c.selectionKey, voicingID: defaultVoicing.id), progress)
        XCTAssertNil(reloaded.progress(selectionKey: c.selectionKey, voicingID: c.voicings[1].id))
        let slash = try XCTUnwrap(GuitarChordData.selectionKey(for: "C/E"))
        XCTAssertNil(reloaded.progress(selectionKey: slash, voicingID: defaultVoicing.id))
        XCTAssertEqual(GuitarChordData.selectionKey(for: "Cmaj/C"), c.selectionKey)
        let payload = try XCTUnwrap(defaults.data(forKey: ChordLearningProgressStore.storageKey))
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        XCTAssertEqual(document["version"] as? Int, 1)
        let entries = try XCTUnwrap(document["entries"] as? [[String: Any]])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?["selectionKey"] as? String, c.selectionKey)
        XCTAssertEqual(entries.first?["voicingID"] as? String, defaultVoicing.id)
        XCTAssertTrue(defaultVoicing.id.contains("|"), "Persist the full geometry ID, not the chord-only shape ID")
    }

    func testStudyWithoutCreditedRecallRoundTripsAndLegacyInitializerIsConservative() throws {
        let defaults = isolatedDefaults()
        let store = ChordLearningProgressStore(defaults: defaults)
        let c = try XCTUnwrap(GuitarChordData(symbol: "C"))
        let voicing = try XCTUnwrap(c.voicings.first)
        let studied = ChordLearningProgress(nextReviewAt: date.addingTimeInterval(86_400), lastPracticedAt: date)
        store.save(studied, selectionKey: c.selectionKey, voicingID: voicing.id)
        let read = store.progress(selectionKey: c.selectionKey, voicingID: voicing.id)
        XCTAssertEqual(read, studied)
        XCTAssertNil(read?.lastSuccessfulReviewAt)
        let priorSuccess = ChordLearningProgress(nextReviewAt: date.addingTimeInterval(86_400),
                                                 successfulReviews: 1, lastPracticedAt: date)
        XCTAssertEqual(priorSuccess.lastSuccessfulReviewAt, date)
        store.save(priorSuccess, selectionKey: c.selectionKey, voicingID: voicing.id)
        XCTAssertEqual(store.progress(selectionKey: c.selectionKey, voicingID: voicing.id), priorSuccess)
    }

    func testCorruptWrongVersionAndSemanticallyInvalidDocumentsAreHarmlessAndNotCleared() throws {
        let defaults = isolatedDefaults()
        let store = ChordLearningProgressStore(defaults: defaults)
        defaults.set("keep other feature data", forKey: "unrelated-feature")
        let c = try XCTUnwrap(GuitarChordData(symbol: "C"))
        let voicing = try XCTUnwrap(c.voicings.first)
        let progress = ChordLearningProgress(nextReviewAt: date.addingTimeInterval(86_400), lastPracticedAt: date)
        store.save(progress, selectionKey: c.selectionKey, voicingID: voicing.id)
        let validData = try XCTUnwrap(defaults.data(forKey: ChordLearningProgressStore.storageKey))
        let valid = try XCTUnwrap(JSONSerialization.jsonObject(with: validData) as? [String: Any])
        let entry = try XCTUnwrap((valid["entries"] as? [[String: Any]])?.first)

        var invalidPayloads = [Data("not JSON".utf8), Data("{}".utf8),
                               Data("{\"version\":99,\"entries\":[]}".utf8)]
        invalidPayloads.append(try JSONSerialization.data(withJSONObject: ["version": 1, "entries": [entry, entry]]))
        for replacement in [
            ["successfulReviews": -1],
            ["successfulReviews": ChordLearningProgressStore.maximumSuccessfulReviews + 1],
            ["successfulReviews": 1], // Credit date is required in stored JSON, unlike the convenience initializer.
            ["lastSuccessfulReviewAt": date.timeIntervalSinceReferenceDate], // No successful recalls.
            ["nextReviewAt": date.timeIntervalSinceReferenceDate - 1],
            ["lastPracticedAt": "not a date"]
        ] as [[String: Any]] {
            var changedEntry = entry
            var changedProgress = try XCTUnwrap(entry["progress"] as? [String: Any])
            changedProgress.merge(replacement) { _, replacement in replacement }
            changedEntry["progress"] = changedProgress
            invalidPayloads.append(try JSONSerialization.data(withJSONObject: ["version": 1, "entries": [changedEntry]]))
        }
        var tooMany = valid
        tooMany["entries"] = Array(repeating: entry, count: ChordLearningProgressStore.maximumRecords + 1)
        invalidPayloads.append(try JSONSerialization.data(withJSONObject: tooMany))
        invalidPayloads.append(Data(repeating: 32, count: ChordLearningProgressStore.maximumPayloadBytes + 1))
        for payload in invalidPayloads {
            defaults.set(payload, forKey: ChordLearningProgressStore.storageKey)
            XCTAssertNil(store.progress(selectionKey: c.selectionKey, voicingID: voicing.id))
            XCTAssertEqual(defaults.data(forKey: ChordLearningProgressStore.storageKey), payload,
                           "A harmless read must not clear even this feature's corrupt payload")
            XCTAssertEqual(defaults.string(forKey: "unrelated-feature"), "keep other feature data")
        }
        store.save(progress, selectionKey: c.selectionKey, voicingID: voicing.id)
        XCTAssertEqual(store.progress(selectionKey: c.selectionKey, voicingID: voicing.id), progress)
        XCTAssertEqual(defaults.string(forKey: "unrelated-feature"), "keep other feature data")
    }

    func testInvalidSavesCannotReplaceValidProgress() throws {
        let defaults = isolatedDefaults()
        let store = ChordLearningProgressStore(defaults: defaults)
        let c = try XCTUnwrap(GuitarChordData(symbol: "C"))
        let voicing = try XCTUnwrap(c.voicings.first)
        let good = ChordLearningProgress(nextReviewAt: date.addingTimeInterval(86_400), lastPracticedAt: date)
        store.save(good, selectionKey: c.selectionKey, voicingID: voicing.id)
        let payload = defaults.data(forKey: ChordLearningProgressStore.storageKey)
        let invalid = [
            ChordLearningProgress(nextReviewAt: date.addingTimeInterval(-1), lastPracticedAt: date),
            ChordLearningProgress(nextReviewAt: date, successfulReviews: -1, lastPracticedAt: date),
            ChordLearningProgress(nextReviewAt: date, successfulReviews: Int.max, lastPracticedAt: date),
            ChordLearningProgress(nextReviewAt: Date(timeIntervalSinceReferenceDate: .nan), lastPracticedAt: date),
            ChordLearningProgress(nextReviewAt: date.addingTimeInterval(86_400), successfulReviews: 1,
                                  lastPracticedAt: date, lastSuccessfulReviewAt: date.addingTimeInterval(1)),
            ChordLearningProgress(nextReviewAt: date, lastPracticedAt: date, lastSuccessfulReviewAt: date)
        ]
        for progress in invalid {
            store.save(progress, selectionKey: c.selectionKey, voicingID: voicing.id)
            XCTAssertEqual(defaults.data(forKey: ChordLearningProgressStore.storageKey), payload)
        }
        for identity in [("", voicing.id), (c.selectionKey, ""),
                         (String(repeating: "x", count: 129), voicing.id),
                         (c.selectionKey, String(repeating: "x", count: 513))] {
            store.save(good, selectionKey: identity.0, voicingID: identity.1)
            XCTAssertEqual(defaults.data(forKey: ChordLearningProgressStore.storageKey), payload)
        }
        XCTAssertEqual(store.progress(selectionKey: c.selectionKey, voicingID: voicing.id), good)
    }

    func testStorageBoundsAndRecentUpdatesRetainOnlyThisFeaturesRecords() throws {
        let defaults = isolatedDefaults()
        defaults.set("unchanged", forKey: "other-data")
        let store = ChordLearningProgressStore(defaults: defaults)
        let c = try XCTUnwrap(GuitarChordData(symbol: "C"))
        let defaultID = try XCTUnwrap(c.voicings.first?.id)
        let progress = ChordLearningProgress(nextReviewAt: date.addingTimeInterval(86_400), lastPracticedAt: date)
        // Store-level fixtures need not resolve guitar geometry; the model only
        // ever requests the exact verified default ID supplied by the core.
        func id(_ index: Int) -> String { defaultID + "|test-geometry-\(index)" }
        for index in 0..<(ChordLearningProgressStore.maximumRecords + 2) {
            store.save(progress, selectionKey: c.selectionKey, voicingID: id(index))
        }
        XCTAssertNil(store.progress(selectionKey: c.selectionKey, voicingID: id(0)))
        XCTAssertNil(store.progress(selectionKey: c.selectionKey, voicingID: id(1)))
        XCTAssertEqual(store.progress(selectionKey: c.selectionKey, voicingID: id(2)), progress)
        store.save(progress, selectionKey: c.selectionKey, voicingID: id(2))
        store.save(progress, selectionKey: c.selectionKey, voicingID: id(ChordLearningProgressStore.maximumRecords + 2))
        XCTAssertNil(store.progress(selectionKey: c.selectionKey, voicingID: id(3)))
        XCTAssertEqual(store.progress(selectionKey: c.selectionKey, voicingID: id(2)), progress)
        let payload = try XCTUnwrap(defaults.data(forKey: ChordLearningProgressStore.storageKey))
        XCTAssertLessThanOrEqual(payload.count, ChordLearningProgressStore.maximumPayloadBytes)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        XCTAssertEqual((document["entries"] as? [Any])?.count, ChordLearningProgressStore.maximumRecords)
        XCTAssertEqual(defaults.string(forKey: "other-data"), "unchanged")
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "ChordLearningProgressStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return defaults
    }
}
