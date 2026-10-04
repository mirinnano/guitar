import XCTest
@testable import GuitarToolsCore

final class ChordPracticeLoopTests: XCTestCase {
    private let timeline = ChordTimeline(beatsPerBar: 4, totalBeats: 34, events: [])

    func testFourBarsStartAtContainingBar() throws {
        let range = try XCTUnwrap(ChordPracticeLoop.bars(startingAt: 5.5, timeline: timeline))
        XCTAssertEqual(range.startBeat, 4)
        XCTAssertEqual(range.endBeat, 20)
        XCTAssertTrue(range.contains(4))
        XCTAssertFalse(range.contains(20))
    }

    func testLastPartialBarIsClampedAndCanBeSelectedAtSongEnd() throws {
        let range = try XCTUnwrap(ChordPracticeLoop.bars(startingAt: 34, timeline: timeline))
        XCTAssertEqual(range.startBeat, 32)
        XCTAssertEqual(range.endBeat, 34)
    }

    func testWrapRetainsElapsedFraction() throws {
        let range = try XCTUnwrap(ChordPracticeLoop(startBeat: 4, endBeat: 20, totalBeats: 34))
        XCTAssertEqual(range.wrappedBeat(20), 4)
        XCTAssertEqual(range.wrappedBeat(37.5), 5.5)
        XCTAssertEqual(range.wrappedBeat(-1), 4)
    }

    func testInvalidAndNonFiniteRangesAreRejected() {
        XCTAssertNil(ChordPracticeLoop(startBeat: 10, endBeat: 4, totalBeats: 34))
        XCTAssertNil(ChordPracticeLoop(startBeat: 0, endBeat: 0, totalBeats: 34))
        XCTAssertNil(ChordPracticeLoop(startBeat: .nan, endBeat: 4, totalBeats: 34))
        XCTAssertNil(ChordPracticeLoop.bars(startingAt: .infinity, timeline: timeline))
        XCTAssertNil(ChordPracticeLoop.bars(startingAt: 0, count: 0, timeline: timeline))
    }
}
