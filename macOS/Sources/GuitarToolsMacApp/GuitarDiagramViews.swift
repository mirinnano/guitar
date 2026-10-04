import GuitarToolsCore
import SwiftUI

/// A right-handed player's look down at the neck, not a rotated front view.
struct ChordShapeDiagram: View {
    let shape: GuitarChordShape

    var compact = false
    var inline = false
    var displayName: String? = nil
    var fixedFingers: Set<Int> = []

    var body: some View {
        VStack(spacing: inline ? 2 : 5) {
            Text(displayName ?? shape.name)
                .font(inline ? .caption2 : compact ? .headline : .title3)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                // The existing 20-point ellipsis belongs in this title corner.
                .padding(.horizontal, PlayerChordDiagramLayout.titleCornerWidth)
                .frame(height: PlayerChordDiagramLayout.titleHeight(compact: compact, inline: inline))

            Canvas { context, size in
                drawDiagram(context: &context, size: size)
            }
            .frame(height: PlayerChordDiagramLayout.canvasHeight(compact: compact, inline: inline))

            if !compact && !inline {
                Text("上1弦／下6弦（手前）、左ヘッド側")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func drawDiagram(context: inout GraphicsContext, size: CGSize) {
        let layout = PlayerChordDiagramLayout(size: size, compact: compact, inline: inline)

        // Five vertical cells. Only the left boundary at fret 1 is the nut.
        for boundary in 0...PlayerChordDiagramGeometry.fretCellCount {
            let x = layout.fretBoundaryX(boundary)
            let isNut = boundary == 0 && shape.baseFret == 1
            var line = Path()
            line.move(to: CGPoint(x: x, y: layout.grid.minY))
            line.addLine(to: CGPoint(x: x, y: layout.grid.maxY))
            context.stroke(
                line,
                with: .color(Color.primary.opacity(isNut ? 0.9 : 0.28)),
                lineWidth: isNut ? 3 : 0.8
            )
        }

        // Six horizontal strings: thin high e at the top, thick low E at the bottom.
        for stringNumber in 1...PlayerChordDiagramGeometry.stringCount {
            guard let row = PlayerChordDiagramGeometry.row(forStringNumber: stringNumber) else { continue }
            let y = layout.stringY(row)
            var line = Path()
            line.move(to: CGPoint(x: layout.grid.minX, y: y))
            line.addLine(to: CGPoint(x: layout.grid.maxX, y: y))
            context.stroke(
                line,
                with: .color(Color.primary.opacity(0.65)),
                lineWidth: layout.stringLineWidth(forStringNumber: stringNumber)
            )
            context.draw(
                Text("\(stringNumber)")
                    .font(.system(size: layout.rowLabelFontSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.primary),
                at: CGPoint(x: layout.rowLabelX, y: y)
            )
        }

        for (column, fret) in PlayerChordDiagramGeometry.visibleFrets(baseFret: shape.baseFret).enumerated() {
            context.draw(
                Text("\(fret)")
                    .font(.system(size: layout.fretLabelFontSize, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.primary),
                at: CGPoint(x: layout.fretCenterX(column), y: layout.fretLabelY)
            )
        }

        // Barre metadata uses string numbers, not array indices. Vertical connectors
        // are drawn behind the opaque, colored dots and their finger numbers.
        for barre in shape.barres {
            guard let column = PlayerChordDiagramGeometry.column(forFret: barre.fret, baseFret: shape.baseFret),
                  let fromRow = PlayerChordDiagramGeometry.row(forStringNumber: barre.fromString),
                  let toRow = PlayerChordDiagramGeometry.row(forStringNumber: barre.toString) else { continue }
            let x = layout.fretCenterX(column)
            var connector = Path()
            connector.move(to: CGPoint(x: x, y: layout.stringY(fromRow)))
            connector.addLine(to: CGPoint(x: x, y: layout.stringY(toRow)))
            context.stroke(
                connector,
                with: .color(ChordFingerStyle.color(for: barre.finger).opacity(0.85)),
                style: StrokeStyle(lineWidth: inline ? 6 : 9, lineCap: .round)
            )
        }

        for stringNumber in 1...PlayerChordDiagramGeometry.stringCount {
            guard let row = PlayerChordDiagramGeometry.row(forStringNumber: stringNumber),
                  let arrayIndex = PlayerChordDiagramGeometry.arrayIndex(forStringNumber: stringNumber),
                  shape.frets.indices.contains(arrayIndex) else { continue }
            // Read both arrays at their original 6...1 index. Never reverse either.
            let fret = shape.frets[arrayIndex]
            let y = layout.stringY(row)
            if fret <= 0 {
                context.draw(
                    Text(fret < 0 ? "×" : "○")
                        .font(.system(size: layout.markerFontSize, weight: .medium))
                        .foregroundStyle(Color.primary),
                    at: CGPoint(x: layout.markerX, y: y)
                )
                continue
            }
            guard let column = PlayerChordDiagramGeometry.column(forFret: fret, baseFret: shape.baseFret) else { continue }
            let x = layout.fretCenterX(column)
            let finger = shape.fingers.indices.contains(arrayIndex) ? shape.fingers[arrayIndex] : nil

            if let finger, fixedFingers.contains(finger) {
                let ring = Path(ellipseIn: CGRect(
                    x: x - layout.haloRadius, y: y - layout.haloRadius,
                    width: layout.haloRadius * 2, height: layout.haloRadius * 2
                ))
                context.stroke(ring, with: .color(.green),
                               style: StrokeStyle(lineWidth: 1.8, dash: [3, 2]))
            }
            let dot = Path(ellipseIn: CGRect(
                x: x - layout.dotRadius, y: y - layout.dotRadius,
                width: layout.dotRadius * 2, height: layout.dotRadius * 2
            ))
            context.fill(dot, with: .color(ChordFingerStyle.color(for: finger)))
            if let finger {
                context.draw(
                    Text("\(finger)")
                        .font(.system(size: layout.fingerFontSize, weight: .bold))
                        .foregroundStyle(Color.white),
                    at: CGPoint(x: x, y: y)
                )
            }
        }

        // Kept inside the canvas so compact and 104 x 132 inline diagrams also
        // disclose the player's orientation without adding to their footprint.
        context.draw(
            Text("←ヘッド　6弦＝手前")
                .font(.system(size: layout.legendFontSize, weight: .medium))
                .foregroundStyle(Color.secondary),
            at: CGPoint(x: size.width / 2, y: layout.legendY)
        )
    }
}

/// Shared canvas measurements, separately testable without opening a window.
struct PlayerChordDiagramLayout {
    static let titleCornerWidth: CGFloat = 24

    let grid: CGRect
    let rowLabelX: CGFloat = 5.5
    let markerX: CGFloat
    let fretLabelY: CGFloat
    let legendY: CGFloat
    let dotRadius: CGFloat
    let haloRadius: CGFloat
    let fingerFontSize: CGFloat
    let rowLabelFontSize: CGFloat
    let fretLabelFontSize: CGFloat
    let markerFontSize: CGFloat
    let legendFontSize: CGFloat

    init(size: CGSize, compact: Bool, inline: Bool) {
        let left: CGFloat = inline ? 28 : compact ? 30 : 34
        let right: CGFloat = inline ? 8 : compact ? 10 : 12
        let top: CGFloat = inline ? 19 : compact ? 24 : 28
        let bottom: CGFloat = inline ? 20 : compact ? 24 : 27
        grid = CGRect(x: left, y: top,
                      width: max(0, size.width - left - right),
                      height: max(0, size.height - top - bottom))
        markerX = inline ? 17.5 : compact ? 18 : 21
        fretLabelY = inline ? 6 : compact ? 8 : 9
        legendY = size.height - (inline ? 6 : compact ? 7 : 8)
        dotRadius = inline ? 5 : compact ? 6 : 7
        haloRadius = dotRadius + (inline ? 2.5 : 3)
        fingerFontSize = inline ? 9 : compact ? 10 : 11
        rowLabelFontSize = inline ? 9 : compact ? 10 : 11
        fretLabelFontSize = inline ? 9 : compact ? 10 : 11
        markerFontSize = inline ? 11 : compact ? 12 : 13
        legendFontSize = inline ? 9 : compact ? 10 : 11
    }

    static func canvasHeight(compact: Bool, inline: Bool) -> CGFloat {
        inline ? 92 : compact ? 118 : 155
    }

    static func titleHeight(compact: Bool, inline: Bool) -> CGFloat {
        inline || compact ? 20 : 24
    }

    var stringGap: CGFloat {
        grid.height / CGFloat(PlayerChordDiagramGeometry.stringCount - 1)
    }

    var fretGap: CGFloat {
        grid.width / CGFloat(PlayerChordDiagramGeometry.fretCellCount)
    }

    func stringY(_ row: Int) -> CGFloat {
        grid.minY + CGFloat(row) * stringGap
    }

    func fretBoundaryX(_ boundary: Int) -> CGFloat {
        grid.minX + CGFloat(boundary) * fretGap
    }

    func fretCenterX(_ column: Int) -> CGFloat {
        grid.minX + (CGFloat(column) + 0.5) * fretGap
    }

    func stringLineWidth(forStringNumber stringNumber: Int) -> CGFloat {
        0.55 + CGFloat(stringNumber) * 0.2
    }
}

private enum ChordFingerStyle {
    static func color(for finger: Int?) -> Color {
        switch finger {
        case 1: Color(red: 0.12, green: 0.40, blue: 0.72)
        case 2: Color(red: 0.00, green: 0.45, blue: 0.38)
        case 3: Color(red: 0.68, green: 0.31, blue: 0.08)
        case 4: Color(red: 0.53, green: 0.29, blue: 0.63)
        default: Color(white: 0.30)
        }
    }
}

struct ChordFingerLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    fingerLabels
                    Text("○ 開放弦　× 弾かない")
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 14) { fingerLabels }
                    Text("○ 開放弦　× 弾かない")
                }
            }
            Text("縦線はバレー：同じ番号の弦を1本の指で押さえます")
            Text("右利きで見下ろす向き：上1弦／下6弦（手前）、左ヘッド側")
            Text("1弦は細い e、6弦は太い E。フレットは右へ増えます（標準チューニング・カポなし）")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var fingerLabels: some View {
        ForEach(Array(["人差し指", "中指", "薬指", "小指"].enumerated()), id: \.offset) { index, name in
            HStack(spacing: 4) {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(ChordFingerStyle.color(for: index + 1), in: Circle())
                Text(name)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// Uses the source spelling, not the library's enharmonic/canonical shape name.
@MainActor
struct ChordFingeringView: View {
    let symbol: String
    var compact = false
    var inline = false
    var fixedFingers: Set<Int> = []
    private let previousSymbol: String?
    private let voicingIDOverride: String?
    private let selectionEnabled: Bool
    @ObservedObject private var preferences: ChordVoicingPreferencesStore
    @State private var pickerPresented = false

    init(symbol: String, compact: Bool = false, inline: Bool = false,
         fixedFingers: Set<Int> = [], previousSymbol: String? = nil,
         voicingIDOverride: String? = nil, selectionEnabled: Bool = true,
         preferences: ChordVoicingPreferencesStore? = nil) {
        self.symbol = symbol
        self.compact = compact
        self.inline = inline
        self.fixedFingers = fixedFingers
        self.previousSymbol = previousSymbol
        self.voicingIDOverride = voicingIDOverride
        self.selectionEnabled = selectionEnabled
        self.preferences = preferences ?? .shared
    }

    private var presentation: ChordFingeringPresentation {
        ChordFingeringPresentation(symbol: symbol, voicingID: voicingIDOverride ?? (selectionEnabled ? preferences.selectedID(for: symbol) : nil))
    }

    var body: some View {
        let value = presentation
        VStack(spacing: inline ? 2 : 5) {
            if let shape = value.shape {
                ChordShapeDiagram(
                    shape: shape,
                    compact: compact,
                    inline: inline,
                    displayName: value.symbol,
                    fixedFingers: fixedFingers
                )
                if value.isSimplified {
                    Text("省略音：" + value.omittedNotes.map(\.displayName).joined(separator: "・"))
                        .font(inline ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(value.symbol)
                    .font(inline ? .caption2 : .headline)
                    .fontWeight(.semibold)
                Text(value.availability == .noChord ? "コードなし" : "押さえ方未対応")
                    .font(inline ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription(for: value))
        .overlay(alignment: .topTrailing) {
            if selectionEnabled && value.availability == .supported {
                Button { pickerPresented = true } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: inline ? 11 : 14))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(symbol)の押さえ方とコードデータを選ぶ")
                .help("別の押さえ方を選ぶ／構成音などのデータを見る")
                .popover(isPresented: $pickerPresented) {
                    ChordVoicingPickerView(symbol: symbol, previousSymbol: previousSymbol, preferences: preferences)
                }
            }
        }
    }

    private func accessibilityDescription(for value: ChordFingeringPresentation) -> String {
        switch value.availability {
        case .noChord:
            return "\(value.symbol)、コードなし"
        case .unavailable:
            return "\(value.symbol)、押さえ方未対応"
        case .supported:
            let simplification = value.isSimplified
                ? "。省略音は" + value.omittedNotes.map(\.displayName).joined(separator: "、") : ""
            let barres = value.shape?.barres.map {
                "\($0.fret)フレット、\($0.fromString)弦から\($0.toString)弦を\($0.finger)番の指でバレー"
            }.joined(separator: "。") ?? ""
            let bass = value.slashBass.map { "。最低音は\($0)" } ?? ""
            let positions = value.shape.map { shape in
                shape.frets.enumerated().map { index, fret in
                    let string = "\(6 - index)弦は"
                    if fret < 0 { return string + "弾かない" }
                    if fret == 0 { return string + "開放弦" }
                    let finger = shape.fingers.indices.contains(index) ? shape.fingers[index] : nil
                    return string + "\(fret)フレット" + (finger.map { "を\($0)番の指" } ?? "")
                }.joined(separator: "。")
            } ?? ""
            let fixed = fixedFingers.isEmpty ? "" : "。輪のついた" + fixedFingers.sorted().map(String.init).joined(separator: "、") + "番の指はそのまま残せます"
            return "\(value.symbol)の押さえ方。カポなし\(bass)\(simplification)\(fixed)"
                + (positions.isEmpty ? "" : "。\(positions)")
                + (barres.isEmpty ? "" : "。\(barres)")
                + "。右利きで見下ろす向き。上1弦／下6弦（手前）、左ヘッド側。フレットは右へ増えます。番号は1が人差し指、2が中指、3が薬指、4が小指"
        }
    }
}

/// The chart's diagrams always refer to standard tuning without a capo.
struct ChartFingeringContext: View {
    let chart: ChordChart

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let warning = chart.capoDirectiveWarning {
                Text(warning).foregroundStyle(.orange)
            } else {
                Text(chart.sourceCapo > 0
                     ? "カポなし・標準チューニング（元譜面のカポ\(chart.sourceCapo)指定を実音に変換）"
                     : "カポなし・標準チューニング")
                    .foregroundStyle(.secondary)
            }
            if !chart.unconvertedChordSymbols.isEmpty {
                Text("実音へ変換できないコード：" + chart.unconvertedChordSymbols.joined(separator: "・") + "（図は表示しません）")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct InlineChordFingering: View {
    static let width: CGFloat = 104
    // Includes any explicitly disclosed optional-note omissions.
    static let height: CGFloat = 132

    let chord: String
    var previousSymbol: String? = nil

    var body: some View {
        ChordFingeringView(symbol: chord, inline: true, previousSymbol: previousSymbol)
            .frame(width: Self.width, height: Self.height, alignment: .top)
    }
}
