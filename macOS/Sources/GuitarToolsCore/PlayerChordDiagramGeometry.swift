/// Right-handed player's view while looking down at the neck:
/// the headstock is left, frets increase right, and string 6 is nearest the player.
/// This maps drawing coordinates only; shape arrays remain in string order 6...1.
public enum PlayerChordDiagramGeometry {
    public static let stringCount = 6
    public static let fretCellCount = 5

    /// Top-to-bottom row: thin high e (string 1) is 0, thick low E (string 6) is 5.
    public static func row(forStringNumber stringNumber: Int) -> Int? {
        guard (1...stringCount).contains(stringNumber) else { return nil }
        return stringNumber - 1
    }

    /// Index into the unchanged fret/finger arrays, which are stored from 6 to 1.
    public static func arrayIndex(forStringNumber stringNumber: Int) -> Int? {
        guard (1...stringCount).contains(stringNumber) else { return nil }
        return stringCount - stringNumber
    }

    /// Left-to-right, zero-based cell within the five-fret window.
    /// Open/muted strings and invalid or out-of-window frets have no cell.
    public static func column(forFret fret: Int, baseFret: Int) -> Int? {
        guard isValidBaseFret(baseFret), fret >= baseFret else { return nil }
        let column = fret - baseFret
        return column < fretCellCount ? column : nil
    }

    /// Actual fret numbers, not relative cell numbers. An invalid window is empty.
    public static func visibleFrets(baseFret: Int) -> [Int] {
        guard isValidBaseFret(baseFret) else { return [] }
        return (0..<fretCellCount).map { baseFret + $0 }
    }

    private static func isValidBaseFret(_ baseFret: Int) -> Bool {
        baseFret >= 1 && baseFret <= Int.max - (fretCellCount - 1)
    }
}
