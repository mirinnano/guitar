import AppKit
import SwiftUI
import XCTest
@testable import GuitarToolsCore
@testable import GuitarToolsMacApp

@MainActor
final class PlayerChordDiagramLayoutTests: XCTestCase {
    private typealias Geometry = PlayerChordDiagramGeometry

    private var configurations: [(name: String, width: CGFloat, compact: Bool, inline: Bool)] {
        [("inline", 104, false, true), ("compact", 160, true, false), ("full", 260, false, false)]
    }

    func testExistingCanvasHeightsAndInlineFootprintArePreserved() {
        XCTAssertEqual(InlineChordFingering.width, 104)
        XCTAssertEqual(InlineChordFingering.height, 132)
        XCTAssertEqual(PlayerChordDiagramLayout.canvasHeight(compact: false, inline: true), 92)
        XCTAssertEqual(PlayerChordDiagramLayout.canvasHeight(compact: true, inline: true), 92)
        XCTAssertEqual(PlayerChordDiagramLayout.canvasHeight(compact: true, inline: false), 118)
        XCTAssertEqual(PlayerChordDiagramLayout.canvasHeight(compact: false, inline: false), 155)
    }

    func testEveryModeReservesTheExistingEllipsisTitleCorner() {
        XCTAssertGreaterThanOrEqual(PlayerChordDiagramLayout.titleCornerWidth, 20)
        for value in configurations {
            XCTAssertGreaterThanOrEqual(PlayerChordDiagramLayout.titleHeight(compact: value.compact, inline: value.inline), 20)
            XCTAssertGreaterThan(value.width - PlayerChordDiagramLayout.titleCornerWidth * 2, 0)
        }
        let inlineContentHeight = PlayerChordDiagramLayout.titleHeight(compact: false, inline: true)
            + 2 + PlayerChordDiagramLayout.canvasHeight(compact: false, inline: true)
        // Leave room for the existing optional-note disclosure below the canvas.
        XCTAssertLessThan(inlineContentHeight, InlineChordFingering.height)
    }

    func testAllModesUseSixHorizontalStringRowsAndFiveVerticalFretCells() throws {
        for value in configurations {
            let size = CGSize(width: value.width,
                              height: PlayerChordDiagramLayout.canvasHeight(compact: value.compact, inline: value.inline))
            let layout = PlayerChordDiagramLayout(size: size, compact: value.compact, inline: value.inline)
            XCTAssertGreaterThan(layout.grid.width, 0, value.name)
            XCTAssertGreaterThan(layout.grid.height, 0, value.name)
            XCTAssertEqual(layout.fretBoundaryX(0), layout.grid.minX, accuracy: 0.001)
            XCTAssertEqual(layout.fretBoundaryX(5), layout.grid.maxX, accuracy: 0.001)
            XCTAssertEqual(layout.stringY(0), layout.grid.minY, accuracy: 0.001)
            XCTAssertEqual(layout.stringY(5), layout.grid.maxY, accuracy: 0.001)
            XCTAssertLessThan(layout.rowLabelX, layout.markerX)
            XCTAssertLessThan(layout.markerX, layout.grid.minX)
            XCTAssertGreaterThanOrEqual(layout.stringGap, layout.dotRadius * 2)
            // Actual two-digit fret labels still fit the inline cells.
            XCTAssertGreaterThanOrEqual(layout.fretGap, layout.fretLabelFontSize * 1.2)
            for stringNumber in 1...6 {
                let row = try XCTUnwrap(Geometry.row(forStringNumber: stringNumber))
                if stringNumber < 6 {
                    XCTAssertLessThan(layout.stringY(row), layout.stringY(row + 1))
                    XCTAssertLessThan(layout.stringLineWidth(forStringNumber: stringNumber),
                                      layout.stringLineWidth(forStringNumber: stringNumber + 1))
                }
            }
            XCTAssertGreaterThan(layout.stringLineWidth(forStringNumber: 6),
                                 layout.stringLineWidth(forStringNumber: 1) * 2)
            for column in 0..<5 {
                XCTAssertGreaterThan(layout.fretCenterX(column), layout.fretBoundaryX(column))
                XCTAssertLessThan(layout.fretCenterX(column), layout.fretBoundaryX(column + 1))
            }
        }
    }

    func testDotsAndGreenFixedFingerHalosFitBetweenLabelsAndLegend() {
        for value in configurations {
            let size = CGSize(width: value.width,
                              height: PlayerChordDiagramLayout.canvasHeight(compact: value.compact, inline: value.inline))
            let layout = PlayerChordDiagramLayout(size: size, compact: value.compact, inline: value.inline)
            let outerRadius = layout.haloRadius + 1.8 / 2
            XCTAssertGreaterThan(layout.haloRadius, layout.dotRadius)
            XCTAssertGreaterThan(layout.stringY(0) - outerRadius,
                                 layout.fretLabelY + layout.fretLabelFontSize / 2, value.name)
            XCTAssertLessThan(layout.stringY(5) + outerRadius,
                              layout.legendY - layout.legendFontSize / 2, value.name)
            for column in 0..<5 {
                XCTAssertGreaterThanOrEqual(layout.fretCenterX(column) - outerRadius, 0)
                XCTAssertLessThanOrEqual(layout.fretCenterX(column) + outerRadius, size.width)
            }
        }
    }

    func testCIndexMiddleAndRingFingersMoveRightAndTowardPlayerWithoutChangingArrays() throws {
        let shape = try XCTUnwrap(CommonGuitarChords.shape(named: "C"))
        for value in configurations {
            let size = CGSize(width: value.width,
                              height: PlayerChordDiagramLayout.canvasHeight(compact: value.compact, inline: value.inline))
            let layout = PlayerChordDiagramLayout(size: size, compact: value.compact, inline: value.inline)
            let expected: [(string: Int, finger: Int, row: Int, column: Int)] = [
                (2, 1, 1, 0), (4, 2, 3, 1), (5, 3, 4, 2)
            ]
            var points: [CGPoint] = []
            for item in expected {
                let index = try XCTUnwrap(Geometry.arrayIndex(forStringNumber: item.string))
                let row = try XCTUnwrap(Geometry.row(forStringNumber: item.string))
                let column = try XCTUnwrap(Geometry.column(forFret: shape.frets[index], baseFret: shape.baseFret))
                XCTAssertEqual(shape.fingers[index], item.finger)
                XCTAssertEqual(row, item.row)
                XCTAssertEqual(column, item.column)
                points.append(CGPoint(x: layout.fretCenterX(column), y: layout.stringY(row)))
            }
            XCTAssertLessThan(points[0].x, points[1].x)
            XCTAssertLessThan(points[1].x, points[2].x)
            XCTAssertLessThan(points[0].y, points[1].y)
            XCTAssertLessThan(points[1].y, points[2].y)
            let highEIndex = try XCTUnwrap(Geometry.arrayIndex(forStringNumber: 1))
            let lowEIndex = try XCTUnwrap(Geometry.arrayIndex(forStringNumber: 6))
            XCTAssertEqual(shape.frets[highEIndex], 0)
            XCTAssertEqual(shape.frets[lowEIndex], -1)
        }
    }

    func testBarresHaveVerticalEndpointsAtTheActualFretColumnInEveryMode() throws {
        let barres: [(barre: GuitarBarre, base: Int)] = [
            (GuitarBarre(fret: 1, fromString: 6, toString: 1, finger: 1), 1),
            (GuitarBarre(fret: 2, fromString: 5, toString: 3, finger: 2), 1),
            (GuitarBarre(fret: 12, fromString: 5, toString: 1, finger: 1), 10)
        ]
        for value in configurations {
            let size = CGSize(width: value.width,
                              height: PlayerChordDiagramLayout.canvasHeight(compact: value.compact, inline: value.inline))
            let layout = PlayerChordDiagramLayout(size: size, compact: value.compact, inline: value.inline)
            for item in barres {
                let column = try XCTUnwrap(Geometry.column(forFret: item.barre.fret, baseFret: item.base))
                let fromRow = try XCTUnwrap(Geometry.row(forStringNumber: item.barre.fromString))
                let toRow = try XCTUnwrap(Geometry.row(forStringNumber: item.barre.toString))
                let from = CGPoint(x: layout.fretCenterX(column), y: layout.stringY(fromRow))
                let to = CGPoint(x: layout.fretCenterX(column), y: layout.stringY(toRow))
                XCTAssertEqual(from.x, to.x)
                XCTAssertGreaterThan(from.y, to.y)
                XCTAssertEqual(from.y, layout.stringY(item.barre.fromString - 1))
                XCTAssertEqual(to.y, layout.stringY(item.barre.toString - 1))
                XCTAssertTrue(layout.grid.contains(CGPoint(x: from.x, y: (from.y + to.y) / 2)))
            }
        }
    }

    // Headless render coverage is intentionally defined here, not run by this task.
    func testSharedDiagramRendersOpenChordsBarresAndHighFretsInLightAndDarkWithoutWindows() throws {
        let c = try XCTUnwrap(CommonGuitarChords.shape(named: "C"))
        let f = GuitarChordShape(
            chord: GuitarChord(root: .f, quality: .major),
            frets: [1, 3, 3, 2, 1, 1], fingers: [1, 3, 4, 2, 1, 1],
            barres: [GuitarBarre(fret: 1, fromString: 6, toString: 1, finger: 1)], baseFret: 1
        )
        let highF = GuitarChordShape(
            chord: f.chord,
            frets: [13, 15, 15, 14, 13, 13], fingers: f.fingers,
            barres: [GuitarBarre(fret: 13, fromString: 6, toString: 1, finger: 1)], baseFret: 13
        )
        for value in configurations {
            for shape in [c, f, highF] {
                for scheme in [ColorScheme.light, .dark] {
                    let root = ChordShapeDiagram(shape: shape, compact: value.compact, inline: value.inline,
                                                 fixedFingers: [1])
                        .environment(\.colorScheme, scheme)
                        .background(Color(nsColor: .controlBackgroundColor))
                    let host = NSHostingView(rootView: root)
                    host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                    let height: CGFloat = value.inline ? InlineChordFingering.height : value.compact ? 155 : 220
                    host.frame = NSRect(x: 0, y: 0, width: value.width, height: height)
                    host.layoutSubtreeIfNeeded()
                    XCTAssertLessThanOrEqual(host.fittingSize.width, value.width + 0.5)
                    XCTAssertLessThanOrEqual(host.fittingSize.height, height + 0.5)
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    XCTAssertGreaterThan(png.count, 200)
                }
            }
        }
    }

    func testInlineSourceSpellingsSelectionButtonAndOmissionDisclosureFitExistingFootprint() throws {
        let suiteName = "player-chord-layout-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = ChordVoicingPreferencesStore(defaults: defaults)
        for symbol in ["C", "Db", "B♭maj7/D", "C6/9/G", "C13", "N.C."] {
            let view = ChordFingeringView(symbol: symbol, inline: true, fixedFingers: [1], preferences: preferences)
            XCTAssertEqual(view.symbol, symbol)
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(x: 0, y: 0, width: InlineChordFingering.width, height: InlineChordFingering.height)
            host.layoutSubtreeIfNeeded()
            XCTAssertLessThanOrEqual(host.fittingSize.width, InlineChordFingering.width + 0.5, symbol)
            XCTAssertLessThanOrEqual(host.fittingSize.height, InlineChordFingering.height + 0.5, symbol)
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            XCTAssertNotNil(bitmap.representation(using: .png, properties: [:]))
        }
    }
}
