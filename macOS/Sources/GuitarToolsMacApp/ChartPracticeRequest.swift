import Foundation
import GuitarToolsCore

/// A snapshot of the displayed chart and practice position, with one-shot identity.
struct ChartPracticeRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let chart: ChordChart
    let beat: Double
    let bpm: Int

    init(chart: ChordChart, beat: Double, bpm: Int) {
        self.id = UUID()
        self.chart = chart
        self.beat = beat
        self.bpm = bpm
    }
}
