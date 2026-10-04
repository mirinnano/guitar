import XCTest
@testable import GuitarToolsCore

final class SongTransitionPlanTests: XCTestCase {
    func testEmptySingleAndRepeatedSameVoicingHaveNoTransitions() {
        for symbols in [[], ["C"], ["C", "C", "CM", "C/C"], ["NC"], ["Cunknown"]] {
            let plan = SongTransitionPlan(chart: chart(symbols))
            XCTAssertTrue(plan.transitions.isEmpty, "\(symbols)")
            XCTAssertEqual(plan.unavailableSymbols, symbols == ["Cunknown"] ? ["Cunknown"] : [])
        }
    }

    func testGroupsVerifiedAliasesAndKeepsFirstWrittenSpelling() throws {
        let plan = SongTransitionPlan(chart: chart(["D♭", "Am", "C#", "Amin", "Db", "Am"]))
        XCTAssertEqual(plan.transitions.count, 2)
        let forward = try XCTUnwrap(plan.transitions.first { $0.fromSymbol == "D♭" })
        XCTAssertEqual(forward.toSymbol, "Am")
        XCTAssertEqual(forward.fromShape.name, "C#")
        XCTAssertEqual(forward.occurrenceBeats, [0, 8, 16])
        XCTAssertEqual(forward.endBeat, 8)
        let reverse = try XCTUnwrap(plan.transitions.first { $0.fromSymbol == "Am" })
        XCTAssertEqual(reverse.toSymbol, "C#")
        XCTAssertEqual(reverse.occurrenceBeats, [4, 12])
        XCTAssertEqual(reverse.endBeat, 12)
        XCTAssertNotEqual(forward.id, reverse.id)
        XCTAssertTrue(plan.unavailableSymbols.isEmpty)

        let respelled = try XCTUnwrap(SongTransitionPlan(chart: chart(["C#", "Amin"])).transitions.first)
        XCTAssertEqual(respelled.id, forward.id)
        XCTAssertEqual(respelled.fromShape, forward.fromShape)
        XCTAssertEqual(respelled.toShape, forward.toShape)
    }

    func testSlashBassChangesVoicingAndIdentityButRootSlashAliasGroups() throws {
        let plan = SongTransitionPlan(chart: chart(["C", "Am", "NC", "C/E", "Am", "NC", "C/C", "Am"]))
        XCTAssertEqual(plan.transitions.count, 2)
        let root = try XCTUnwrap(plan.transitions.first { $0.fromSymbol == "C" })
        let inversion = try XCTUnwrap(plan.transitions.first { $0.fromSymbol == "C/E" })
        XCTAssertEqual(root.occurrenceBeats, [0, 24])
        XCTAssertEqual(root.endBeat, 8)
        XCTAssertEqual(inversion.occurrenceBeats, [12])
        XCTAssertEqual(inversion.endBeat, 20)
        XCTAssertNotEqual(root.id, inversion.id)
        XCTAssertEqual(root.fromShape.frets, [-1, 3, 2, 0, 1, 0])
        XCTAssertEqual(inversion.fromShape.frets, [0, 3, 2, 0, 1, 0])
        XCTAssertEqual(lowestNote(inversion.fromShape), .e)
        XCTAssertEqual(lowestNote(root.fromShape), .c)

        let bassAliases = SongTransitionPlan(chart: chart(["D♭/F", "Am", "NC", "C#/F", "Am"]))
        XCTAssertEqual(bassAliases.transitions.count, 1)
        let alias = try XCTUnwrap(bassAliases.transitions.first)
        XCTAssertEqual(alias.fromSymbol, "D♭/F")
        XCTAssertEqual(alias.occurrenceBeats, [0, 12])
        XCTAssertEqual(lowestNote(alias.fromShape), .f)
    }

    func testNCAndMalformedOrUnsupportedEventsAreBarriersNotSkippedChords() {
        let symbols = ["C", "C/Unknown", "G", "NC", "Am", "Cunknown", "F", "N.C.", "Dm"]
        let plan = SongTransitionPlan(chart: chart(symbols))
        XCTAssertTrue(plan.transitions.isEmpty)
        XCTAssertEqual(plan.unavailableSymbols, ["C/Unknown", "Cunknown"])

        let parsed = ChordChartParser.parse(
            "[C][Cunknown][G][NC][Am][Cunknown][F][N.C.][Dm]", fallbackTitle: "Barriers"
        )
        let parsedPlan = SongTransitionPlan(chart: parsed)
        XCTAssertTrue(parsedPlan.transitions.isEmpty)
        XCTAssertEqual(parsedPlan.unavailableSymbols, ["Cunknown"])
    }

    func testUnsafeTimingSlotWithOtherwiseSupportedSymbolNeverResolvesOrBridges() {
        let value = ChordChart(sourceTitle: "Unsafe", title: "Unsafe", lines: [
            ChartLine(segments: [
                ChartSegment(chord: "Am", text: ""),
                ChartSegment(text: "[C]", timingChord: "C"),
                ChartSegment(chord: "G", text: ""),
                ChartSegment(chord: "NC", text: ""),
                ChartSegment(text: "[C]", timingChord: "C")
            ])
        ], unconvertedChordSymbols: ["C", "OriginalUnknown", "C", "NC"])
        let events = ChordTimelineBuilder.build(chart: value).events
        XCTAssertFalse(events[1].isPlayable)
        XCTAssertFalse(events[4].isPlayable)
        let plan = SongTransitionPlan(chart: value)
        XCTAssertTrue(plan.transitions.isEmpty)
        XCTAssertEqual(plan.unavailableSymbols, ["C", "OriginalUnknown"])
    }

    func testInconsistentDisplayedChordAndTimingOriginalAreBarrier() {
        let value = ChordChart(sourceTitle: "Inconsistent", title: "Inconsistent", lines: [
            ChartLine(segments: [
                ChartSegment(chord: "Am", text: ""),
                ChartSegment(chord: "D", text: "", timingChord: "C"),
                ChartSegment(chord: "G", text: "")
            ])
        ])
        XCTAssertTrue(ChordTimelineBuilder.build(chart: value).events[1].isPlayable)
        let plan = SongTransitionPlan(chart: value)
        XCTAssertTrue(plan.transitions.isEmpty)
        XCTAssertEqual(plan.unavailableSymbols, ["C"])
    }

    func testUnsupportedCapoConversionSlotsRetainOriginalSummaryAndBlockPairs() {
        let value = ChordChartParser.parse("{capo: 2}\n[C][Cunknown][G]", fallbackTitle: "Capo")
        XCTAssertEqual(value.unconvertedChordSymbols, ["Cunknown"])
        XCTAssertEqual(ChordTimelineBuilder.build(chart: value).events.map(\.symbol), ["D", "Cunknown", "A"])
        let plan = SongTransitionPlan(chart: value)
        XCTAssertTrue(plan.transitions.isEmpty)
        XCTAssertEqual(plan.unavailableSymbols, ["Cunknown"])

        let unsafe = ChordChartParser.parse("{capo: invalid}\n[C][Am][C]", fallbackTitle: "Unsafe capo")
        XCTAssertTrue(ChordTimelineBuilder.build(chart: unsafe).events.allSatisfy { !$0.isPlayable })
        XCTAssertTrue(SongTransitionPlan(chart: unsafe).transitions.isEmpty)
        XCTAssertEqual(SongTransitionPlan(chart: unsafe).unavailableSymbols, ["C", "Am"])
    }

    func testUnsupportedSummaryIsStableUniqueAndDoesNotFallBackToRoot() {
        let plan = SongTransitionPlan(chart: chart(["Cunknown", "Cunknown/E", "Cunknown", "", "NC", "Cunknown/E"]))
        XCTAssertTrue(plan.transitions.isEmpty)
        XCTAssertEqual(plan.unavailableSymbols, ["Cunknown", "Cunknown/E", ""])
    }

    func testCommonCAmKeepsIndexAndMiddleFingersAndMovesOnlyRingFinger() throws {
        for symbols in [["C", "Am"], ["Am", "C"]] {
            let transition = try XCTUnwrap(SongTransitionPlan(chart: chart(symbols)).transitions.first)
            XCTAssertEqual(transition.fixedFingers, [
                ChordFingerAnchor(finger: 1, positions: [ChordFingerPosition(stringNumber: 2, fret: 1)]),
                ChordFingerAnchor(finger: 2, positions: [ChordFingerPosition(stringNumber: 4, fret: 2)])
            ])
            XCTAssertEqual(transition.movingFingerCount, 1)
            XCTAssertEqual(transition.difficultyScore, 14)
            XCTAssertTrue(transition.fixedFingers.flatMap(\.positions).allSatisfy { $0.fret > 0 })
        }
    }

    func testSelectedAlternativeChangesPlanGeometryIdentityAndFixedFingerGuidance() throws {
        let value = chart(["C", "Am"])
        let standard = try XCTUnwrap(SongTransitionPlan(chart: value).transitions.first)
        let data = try XCTUnwrap(GuitarChordData(symbol: "C"))
        let alternative = try XCTUnwrap(data.voicings.first { $0.shape.baseFret > 5 })
        let selections = [data.selectionKey: alternative.id]
        let plan = SongTransitionPlan(chart: value, voicingSelections: selections)
        let selected = try XCTUnwrap(plan.transitions.first)

        XCTAssertEqual(selected.fromShape, alternative.shape)
        XCTAssertEqual(selected.toShape, standard.toShape)
        XCTAssertNotEqual(selected.fromShape.frets, standard.fromShape.frets)
        XCTAssertNotEqual(selected.id, standard.id)
        XCTAssertEqual(standard.fixedFingers.map(\.finger), [1, 2])
        XCTAssertTrue(selected.fixedFingers.isEmpty, "High-position C cannot retain open Am's fret-1/2 fingers")
        let used = Set(footprints(selected.fromShape).keys).union(footprints(selected.toShape).keys)
        XCTAssertEqual(selected.movingFingerCount, used.count)
        XCTAssertGreaterThan(selected.difficultyScore, standard.difficultyScore)
        XCTAssertEqual(selected.occurrenceBeats, standard.occurrenceBeats)
        XCTAssertEqual(selected.endBeat, standard.endBeat)
        XCTAssertEqual(SongTransitionPlan(chart: value, voicingSelections: selections), plan)

        // The diagram can recover exactly the pinned plan geometry, not the
        // current global preference, including the original finger assignment.
        let pinnedID = try XCTUnwrap(data.voicings.first { $0.shape == selected.fromShape }?.id)
        XCTAssertEqual(ChordFingeringPresentation(symbol: selected.fromSymbol, voicingID: pinnedID).shape,
                       selected.fromShape)
    }

    func testSelectedChoicesUseCanonicalAliasKeysAndKeepActualSlashBass() throws {
        let data = try XCTUnwrap(GuitarChordData(symbol: "Db/F"))
        let alternative = try XCTUnwrap(data.voicings.first { $0.shape != data.voicings[0].shape })
        let plan = SongTransitionPlan(chart: chart(["D♭/F", "Am", "NC", "C#/F", "Amin"]),
                                      voicingSelections: [data.selectionKey: alternative.id])
        XCTAssertEqual(plan.transitions.count, 1)
        let selected = try XCTUnwrap(plan.transitions.first)
        XCTAssertEqual(selected.fromSymbol, "D♭/F")
        XCTAssertEqual(selected.fromShape, alternative.shape)
        XCTAssertEqual(selected.occurrenceBeats, [0, 12])
        XCTAssertEqual(lowestNote(selected.fromShape), .f)
        XCTAssertTrue(plan.unavailableSymbols.isEmpty)

        let c = try XCTUnwrap(GuitarChordData(symbol: "C"))
        let highC = try XCTUnwrap(c.voicings.first { $0.shape.baseFret > 5 })
        let aliases = SongTransitionPlan(chart: chart(["C", "Am", "NC", "CM", "Amin", "NC", "C/C", "Am"]),
                                         voicingSelections: [c.selectionKey: highC.id])
        XCTAssertEqual(aliases.transitions.count, 1)
        XCTAssertEqual(aliases.transitions.first?.fromShape, highC.shape)
        XCTAssertEqual(aliases.transitions.first?.occurrenceBeats, [0, 12, 24])
    }

    func testStaleForeignAndWrongBassSelectionsFallBackWithoutRemovingBarriers() throws {
        let value = chart(["C", "Am", "NC", "C/E", "Am", "Cunknown", "G"])
        let c = try XCTUnwrap(GuitarChordData(symbol: "C"))
        let amKey = try XCTUnwrap(GuitarChordData.selectionKey(for: "Am"))
        let inversionKey = try XCTUnwrap(GuitarChordData.selectionKey(for: "C/E"))
        let selections = [
            c.selectionKey: "stale-voicing", amKey: c.voicings[0].id,
            inversionKey: c.voicings[0].id, "Cunknown": c.voicings[0].id
        ]
        XCTAssertEqual(SongTransitionPlan(chart: value, voicingSelections: selections),
                       SongTransitionPlan(chart: value))
        XCTAssertEqual(SongTransitionPlan(chart: value, voicingSelections: [:]), SongTransitionPlan(chart: value))
    }

    func testEveryReportedAnchorHasEntireMatchingFootprintAndBarreMetadata() {
        let symbols = ["C", "Am", "F", "Fm", "G", "Em", "A", "Dm", "D", "B♭maj7/D",
                       "Db/F", "C6/9", "C/E", "C", "C13", "G/B", "G#m/B", "Bm", "B", "E"]
        let plan = SongTransitionPlan(chart: chart(symbols))
        XCTAssertEqual(plan.transitions.count, symbols.count - 1)
        for transition in plan.transitions {
            XCTAssertFalse(transition.occurrenceBeats.isEmpty)
            XCTAssertNotEqual(transition.fromShape.frets, transition.toShape.frets)
            let from = footprints(transition.fromShape)
            let to = footprints(transition.toShape)
            let eligible = Set(from.keys).intersection(to.keys).filter { finger in
                from[finger] == to[finger] &&
                    Set(transition.fromShape.barres.filter { $0.finger == finger }) ==
                    Set(transition.toShape.barres.filter { $0.finger == finger })
            }
            XCTAssertEqual(Set(transition.fixedFingers.map(\.finger)), Set(eligible), transition.id)
            XCTAssertEqual(transition.fixedFingers.map(\.finger), eligible.sorted())
            for anchor in transition.fixedFingers {
                XCTAssertFalse(anchor.positions.isEmpty)
                XCTAssertEqual(anchor.positions, from[anchor.finger])
                XCTAssertEqual(anchor.positions, to[anchor.finger])
                XCTAssertTrue(anchor.positions.allSatisfy { $0.fret > 0 })
            }
            XCTAssertEqual(transition.movingFingerCount,
                           Set(from.keys).union(to.keys).count - transition.fixedFingers.count)
            XCTAssertGreaterThanOrEqual(transition.movingFingerCount, 0)
            XCTAssertEqual(transition.fromShape, ChordFingeringPresentation(symbol: transition.fromSymbol).shape)
            XCTAssertEqual(transition.toShape, ChordFingeringPresentation(symbol: transition.toSymbol).shape)
        }
    }

    func testRepeatedChordUpdatesImmediateFromBeatAndUsesTimelineDurations() throws {
        let parsed = ChordChartParser.parse("[C][C][Am] | [C][Am]", fallbackTitle: "Timing")
        let timeline = ChordTimelineBuilder.build(chart: parsed)
        let transition = try XCTUnwrap(SongTransitionPlan(chart: parsed).transitions.first { $0.fromSymbol == "C" })
        XCTAssertEqual(transition.occurrenceBeats, [timeline.events[1].startBeat, timeline.events[3].startBeat])
        XCTAssertEqual(transition.endBeat, timeline.events[2].startBeat + timeline.events[2].durationBeats)
        XCTAssertEqual(transition.endBeat, 4)
    }

    func testScoreOrderIDsAndPlansAreDeterministicAndRecurrenceAffectsPriority() throws {
        // Both directions have the same geometry score; first occurrence breaks the tie.
        let tied = SongTransitionPlan(chart: chart(["C", "Am", "C"]))
        XCTAssertEqual(tied.transitions.map(\.fromSymbol), ["C", "Am"])
        XCTAssertEqual(tied.transitions.map(\.difficultyScore), [14, 14])
        let repeated = SongTransitionPlan(chart: chart(["C", "Am", "C", "NC", "Am", "C"]))
        XCTAssertEqual(repeated.transitions.map(\.fromSymbol), ["Am", "C"])
        XCTAssertEqual(repeated.transitions.first?.occurrenceBeats, [4, 16])

        let value = chart(["C", "Am", "G", "F", "C", "Am", "G", "F", "C", "Am"])
        let plan = SongTransitionPlan(chart: value)
        XCTAssertEqual(Set(plan.transitions.map(\.id)).count, plan.transitions.count)
        for _ in 0..<10 { XCTAssertEqual(SongTransitionPlan(chart: value), plan) }
        for transition in plan.transitions {
            let changed = zip(transition.fromShape.frets, transition.toShape.frets).filter { $0 != $1 }.count
            let barres = Set(transition.fromShape.barres).symmetricDifference(Set(transition.toShape.barres)).count
            XCTAssertEqual(transition.difficultyScore,
                           10 * transition.movingFingerCount + 2 * changed + 4 * barres +
                           abs(transition.fromShape.baseFret - transition.toShape.baseFret))
        }
        for (lhs, rhs) in zip(plan.transitions, plan.transitions.dropFirst()) {
            let leftPriority = lhs.difficultyScore + 6 * (lhs.occurrenceBeats.count - 1)
            let rightPriority = rhs.difficultyScore + 6 * (rhs.occurrenceBeats.count - 1)
            XCTAssertGreaterThanOrEqual(leftPriority, rightPriority)
        }
    }

    func testInvalidMeterDoesNotEmitZeroOrNegativeLengthPractice() {
        for meter in [0, -4] {
            let value = ChordChart(sourceTitle: "Invalid", title: "Invalid", beatsPerBar: meter,
                                   lines: [ChartLine(segments: [ChartSegment(chord: "C", text: ""),
                                                               ChartSegment(chord: "Am", text: "")])])
            XCTAssertTrue(SongTransitionPlan(chart: value).transitions.isEmpty)
        }
    }

    private func chart(_ symbols: [String]) -> ChordChart {
        ChordChart(sourceTitle: "Test", title: "Test", lines: symbols.map {
            ChartLine(segments: [ChartSegment(chord: $0, text: "")])
        })
    }

    private func lowestNote(_ shape: GuitarChordShape) -> GuitarNote? {
        zip([40, 45, 50, 55, 59, 64], shape.frets)
            .compactMap { midi, fret in fret < 0 ? nil : midi + fret }.min().map(GuitarNote.fromMIDI)
    }

    private func footprints(_ shape: GuitarChordShape) -> [Int: [ChordFingerPosition]] {
        var result: [Int: [ChordFingerPosition]] = [:]
        for index in 0..<6 where shape.frets[index] > 0 {
            if let finger = shape.fingers[index] {
                result[finger, default: []].append(
                    ChordFingerPosition(stringNumber: 6 - index, fret: shape.frets[index])
                )
            }
        }
        return result.mapValues { $0.sorted { $0.stringNumber < $1.stringNumber } }
    }
}
