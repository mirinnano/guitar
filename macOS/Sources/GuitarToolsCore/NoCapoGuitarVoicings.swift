import Foundation

/// Verified concert-pitch voicings in standard EADGBE tuning, with no capo shift.
/// Search is bounded to fret 15 and five displayed frets (fretted span <= 4).
/// Results, including failures, are cached by root/quality/actual bass. This does
/// not consult CommonGuitarChords.all, avoiding catalog initialization recursion.
public enum NoCapoGuitarVoicings {
    private struct Key: Hashable {
        let chord: GuitarChord
        let bass: GuitarNote
    }
    private static let lock = NSLock()
    private static var cache: [Key: GuitarChordShape] = [:]
    private static var unavailable: Set<Key> = []
    private static let tuning = [40, 45, 50, 55, 59, 64]
    // A separate lazy cache: building the 444-entry default catalog never runs
    // variant searches. Never call resolve while either search lock is held.
    private static let variantsLock = NSLock()
    private static var variantsCache: [Key: [GuitarChordShape]] = [:]

    static func variants(chord: GuitarChord, bass: GuitarNote? = nil) -> [GuitarChordShape] {
        let key = Key(chord: chord, bass: bass ?? chord.root)
        guard let standard = resolve(chord: chord, bass: key.bass) else { return [] }
        variantsLock.lock()
        defer { variantsLock.unlock() }
        if let result = variantsCache[key] { return result }
        let result = findVariants(chord: chord, bass: key.bass, standard: standard)
        variantsCache[key] = result
        return result
    }

    /// Keep a small best-of-window pool, then spread alternatives across neck
    /// positions. All returned shapes go through the same pitch/bass/finger
    /// validator as the default, and fret arrays (not just IDs) are distinct.
    private static func findVariants(chord: GuitarChord, bass: GuitarNote,
                                     standard: GuitarChordShape) -> [GuitarChordShape] {
        let curated = ConventionalGuitarFingerings.shapes(chord: chord, bass: bass)
        var result = [standard]
        var seen: Set<[Int]> = [standard.frets]
        for shape in curated where result.count < 18 {
            if seen.insert(shape.frets).inserted { result.append(shape) }
        }
        if result.count == 18 { return result }
        let curatedFrets = Set(curated.map(\.frets))
        let allowed = Set(chord.notes).union([bass])
        let optional = optionalNotes(chord).subtracting([bass]).sorted { $0.rawValue < $1.rawValue }
        let wantedSets = (0..<(1 << optional.count)).compactMap { subset -> Set<GuitarNote>? in
            let omitted = Set(optional.enumerated().compactMap { index, note in
                subset & (1 << index) == 0 ? nil : note
            })
            let wanted = allowed.subtracting(omitted)
            return wanted.count <= 6 ? wanted : nil
        }
        var pool: [(shape: GuitarChordShape, score: Int)] = []
        for low in 1...15 {
            let high = min(15, low + 4)
            var best: [(shape: GuitarChordShape, score: Int)] = []
            for wanted in wantedSets {
                let wantedMask = mask(wanted)
                let omissionPenalty = allowed.subtracting(wanted).count * 10_000
                let options: [[Int]] = tuning.map { midi in
                    var choices = [-1]
                    if low == 1, wanted.contains(GuitarNote.fromMIDI(midi)) { choices.append(0) }
                    for fret in low...high where wanted.contains(GuitarNote.fromMIDI(midi + fret)) {
                        choices.append(fret)
                    }
                    return choices
                }
                var remaining = [Int](repeating: 0, count: 7)
                var remainingBass = [Int](repeating: Int.max, count: 7)
                for index in (0..<6).reversed() {
                    let pitches = options[index].filter { $0 >= 0 }.map { tuning[index] + $0 }
                    remaining[index] = remaining[index + 1] | pitches.reduce(0) { $0 | (1 << ($1 % 12)) }
                    remainingBass[index] = min(remainingBass[index + 1],
                                              pitches.filter { $0 % 12 == bass.rawValue }.min() ?? Int.max)
                }
                guard remaining[0] & wantedMask == wantedMask else { continue }
                var frets = [Int](repeating: -1, count: 6)
                func visit(_ index: Int, _ sounded: Int, _ minimum: Int) {
                    if (sounded | remaining[index]) & wantedMask != wantedMask { return }
                    if (wantedMask & ~sounded).nonzeroBitCount > 6 - index { return }
                    if minimum != Int.max, minimum % 12 != bass.rawValue,
                       remainingBass[index] >= minimum { return }
                    if index == 6 {
                        guard sounded == wantedMask, minimum % 12 == bass.rawValue,
                              frets != standard.frets, !curatedFrets.contains(frets) else { return }
                        let positive = frets.filter { $0 > 0 }
                        let sounding = frets.indices.filter { frets[$0] >= 0 }
                        let internalMuted = sounding.first.flatMap { first in
                            sounding.last.map { last in (first..<last).filter { frets[$0] < 0 }.count }
                        } ?? 0
                        let preliminary = omissionPenalty + (positive.max() ?? 0) * 100 +
                            frets.filter { $0 < 0 }.count * 12 + internalMuted * 160 +
                            (positive.max() ?? 0) - (positive.min() ?? 0) + positive.reduce(0, +)
                        // Finger cost is nonnegative, so reject candidates that
                        // cannot improve the bounded three-entry window pool.
                        if best.count == 3, preliminary > best[2].score { return }
                        guard let shape = checked(chord: chord, frets: frets, bass: bass,
                                                  allowed: wanted, required: wanted),
                              !best.contains(where: { $0.shape.frets == frets }) else { return }
                        let score = preliminary + Set(shape.fingers.compactMap { $0 }).count * 5
                        best.append((shape, score))
                        best.sort { $0.score == $1.score ? fretOrder($0.shape, $1.shape) : $0.score < $1.score }
                        if best.count > 3 { best.removeLast() }
                        return
                    }
                    for fret in options[index] {
                        frets[index] = fret
                        let midi = tuning[index] + fret
                        visit(index + 1, fret < 0 ? sounded : sounded | (1 << (midi % 12)),
                              fret < 0 ? minimum : min(minimum, midi))
                    }
                }
                visit(0, 0, Int.max)
            }
            pool.append(contentsOf: best)
        }
        pool.sort { $0.score == $1.score ? fretOrder($0.shape, $1.shape) : $0.score < $1.score }
        var positions = Set(result.map(\.baseFret))
        // First pass gives each available neck position a representative. Second
        // pass adds useful variations, keeping a predictable maximum of 18.
        func appendChoices(from entries: [(shape: GuitarChordShape, score: Int)]) {
            for entry in entries where !positions.contains(entry.shape.baseFret) {
                guard result.count < 18 else { break }
                if seen.insert(entry.shape.frets).inserted {
                    result.append(entry.shape)
                    positions.insert(entry.shape.baseFret)
                }
            }
            for entry in entries {
                guard result.count < 18 else { break }
                if seen.insert(entry.shape.frets).inserted { result.append(entry.shape) }
            }
        }
        if chord.quality == .dominant7, bass != chord.root {
            // The open-C7 exception must not make an uncurated inversion prefer
            // an omitted fifth merely to offer another neck position. Complete
            // generated choices precede every optional-fifth fallback here.
            let completeMask = mask(allowed)
            var complete: [(shape: GuitarChordShape, score: Int)] = []
            var omitted: [(shape: GuitarChordShape, score: Int)] = []
            for entry in pool {
                let sounded = zip(tuning, entry.shape.frets).reduce(0) { value, pair in
                    pair.1 < 0 ? value : value | (1 << ((pair.0 + pair.1) % 12))
                }
                if sounded == completeMask { complete.append(entry) } else { omitted.append(entry) }
            }
            appendChoices(from: complete)
            appendChoices(from: omitted)
        } else {
            appendChoices(from: pool)
        }
        return result
    }

    private static func fretOrder(_ lhs: GuitarChordShape, _ rhs: GuitarChordShape) -> Bool {
        lhs.frets.lexicographicallyPrecedes(rhs.frets)
    }

    public static func resolve(chord: GuitarChord, bass: GuitarNote? = nil) -> GuitarChordShape? {
        let key = Key(chord: chord, bass: bass ?? chord.root)
        // Hold the lock through the bounded first search, preventing duplicate UI
        // work. Subsequent lookups are dictionary accesses, not fret searches.
        lock.lock()
        defer { lock.unlock() }
        if let result = cache[key] { return result }
        if unavailable.contains(key) { return nil }
        let result = find(chord: chord, bass: key.bass)
        if let result { cache[key] = result } else { unavailable.insert(key) }
        return result
    }

    /// The only permitted omissions. Never omit root, third, seventh, suspension,
    /// extension or alteration (including an altered fifth). The perfect fifth
    /// is optional in plain dominant7, accommodating the standard open C7, and
    /// in extended chords. Natural 11 is additionally optional in dominant13
    /// (third/11 clash). All callers exclude the requested bass from omissions.
    static func optionalNotes(_ chord: GuitarChord) -> Set<GuitarNote> {
        var intervals: [Int] = []
        if chord.quality == .dominant7 ||
            (chord.quality.intervals.count >= 5 && chord.quality.intervals.contains(7)) {
            intervals.append(7)
        }
        if chord.quality == .dominant13 { intervals.append(17) }
        return Set(intervals.map { GuitarNote.fromMIDI(chord.root.rawValue + $0) })
    }

    private static func mask(_ notes: Set<GuitarNote>) -> Int {
        notes.reduce(0) { $0 | (1 << $1.rawValue) }
    }

    private static func find(chord: GuitarChord, bass: GuitarNote) -> GuitarChordShape? {
        let notes = Set(chord.notes)
        let allowed = notes.union([bass])
        let optional = optionalNotes(chord)
        // Familiar grips (including the declared fifth-omitting open C7) outrank
        // low-fret fragments. Validate curated metadata as supplied, never
        // reconstructing it and then calling it common.
        if let shape = ConventionalGuitarFingerings.shapes(chord: chord, bass: bass).first {
            return shape
        }

        // Prefer all written tones; only fall back to the documented optional
        // omissions when no exact playable voicing fits the diagram/search bound.
        let optionalArray = optional.sorted { $0.rawValue < $1.rawValue }
        let subsets = (0..<(1 << optionalArray.count)).sorted {
            $0.nonzeroBitCount == $1.nonzeroBitCount ? $0 < $1 : $0.nonzeroBitCount < $1.nonzeroBitCount
        }
        for subset in subsets {
            let omissions = Set(optionalArray.enumerated().compactMap { index, note in
                subset & (1 << index) == 0 ? nil : note
            }).subtracting([bass])
            let wanted = allowed.subtracting(omissions)
            guard wanted.count <= 6 else { continue }
            if let shape = search(chord: chord, bass: bass, wanted: wanted) { return shape }
        }
        return nil
    }

    private static func search(chord: GuitarChord, bass: GuitarNote, wanted: Set<GuitarNote>) -> GuitarChordShape? {
        let wantedMask = mask(wanted)
        var best: GuitarChordShape?
        var bestScore = Int.max
        // Windows include open strings only when all fretted notes fit the
        // nut-position diagram. High-fret open notes otherwise disappear in the
        // fixed five-fret diagram, so such combinations are deliberately rejected.
        for low in 1...15 {
            let high = min(15, low + 4)
            if high > 5, best != nil, low * 100 > bestScore { break }
            let options: [[Int]] = tuning.map { midi in
                var choices = [-1]
                if low == 1, wanted.contains(GuitarNote.fromMIDI(midi)) { choices.append(0) }
                for fret in low...high where wanted.contains(GuitarNote.fromMIDI(midi + fret)) {
                    choices.append(fret)
                }
                return choices
            }
            var remaining = [Int](repeating: 0, count: 7)
            for index in (0..<6).reversed() {
                remaining[index] = remaining[index + 1] | options[index].filter { $0 >= 0 }.reduce(0) {
                    $0 | (1 << ((tuning[index] + $1) % 12))
                }
            }
            guard remaining[0] & wantedMask == wantedMask else { continue }
            var frets = [Int](repeating: -1, count: 6)
            func visit(_ index: Int, _ sounded: Int, _ minimumMIDI: Int) {
                if (sounded | remaining[index]) & wantedMask != wantedMask { return }
                if (wantedMask & ~sounded).nonzeroBitCount > 6 - index { return }
                if index == 6 {
                    guard sounded == wantedMask, minimumMIDI % 12 == bass.rawValue,
                          let shape = checked(chord: chord, frets: frets, bass: bass,
                                              allowed: wanted, required: wanted) else { return }
                    let positive = frets.filter { $0 > 0 }
                    let muted = frets.filter { $0 < 0 }.count
                    let soundingIndices = frets.indices.filter { frets[$0] >= 0 }
                    let internalMuted = soundingIndices.first.flatMap { first in
                        soundingIndices.last.map { last in
                            (first..<last).filter { frets[$0] < 0 }.count
                        }
                    } ?? 0
                    // Prefer conventional contiguous strumming shapes over a
                    // slightly lower fret with awkward internally muted strings.
                    // All score terms remain nonnegative, so low * 100 is still
                    // a safe lower bound for pruning subsequent fret windows.
                    let score = (positive.max() ?? 0) * 100 + muted * 12 + internalMuted * 160 +
                        Set(shape.fingers.compactMap { $0 }).count * 5 +
                        (positive.max() ?? 0) - (positive.min() ?? 0) + positive.reduce(0, +)
                    if score < bestScore { best = shape; bestScore = score }
                    return
                }
                for fret in options[index] {
                    frets[index] = fret
                    let midi = tuning[index] + fret
                    visit(index + 1, fret < 0 ? sounded : sounded | (1 << (midi % 12)),
                          fret < 0 ? minimumMIDI : min(minimumMIDI, midi))
                }
            }
            visit(0, 0, Int.max)
        }
        return best
    }

    /// Catalog candidates receive the same tone, actual-bass and diagram checks
    /// as search results, plus verification of their supplied finger/barre data.
    /// No resolve/cache calls here: catalog lookup and classification cannot recurse.
    static func checkedCandidate(_ candidate: GuitarChordShape, bass: GuitarNote) -> GuitarChordShape? {
        let allowed = Set(candidate.chord.notes).union([bass])
        let required = allowed.subtracting(optionalNotes(candidate.chord).subtracting([bass]))
        guard hasValidFingering(frets: candidate.frets, fingers: candidate.fingers, barres: candidate.barres),
              let verified = checked(chord: candidate.chord, frets: candidate.frets, bass: bass,
                                     allowed: allowed, required: required),
              candidate.baseFret == verified.baseFret else { return nil }
        return candidate
    }

    /// Independently validate supplied metadata; minimum-finger grouping is not
    /// necessarily the most practical beginner fingering for a familiar open chord.
    static func hasValidFingering(frets: [Int], fingers: [Int?], barres: [GuitarBarre]) -> Bool {
        guard frets.count == 6, fingers.count == 6,
              frets.allSatisfy({ (-1...15).contains($0) }) else { return false }
        var fingerFrets: [Int: Int] = [:]
        var fingerIndices: [Int: [Int]] = [:]
        for index in frets.indices {
            let fret = frets[index]
            if fret <= 0 {
                guard fingers[index] == nil else { return false }
            } else {
                guard let finger = fingers[index], (1...4).contains(finger) else { return false }
                if let previous = fingerFrets[finger], previous != fret { return false }
                fingerFrets[finger] = fret
                fingerIndices[finger, default: []].append(index)
            }
        }
        for barre in barres {
            guard (1...6).contains(barre.toString), (1...6).contains(barre.fromString),
                  barre.fromString > barre.toString, barre.fret > 0,
                  fingerFrets[barre.finger] == barre.fret else { return false }
            let covered = barre.toString...barre.fromString
            let anchors = fingerIndices[barre.finger, default: []].filter { covered.contains(6 - $0) }
            guard !anchors.isEmpty else { return false }
            for string in covered {
                let index = 6 - string
                guard frets[index] < 0 || frets[index] >= barre.fret else { return false }
                if frets[index] == barre.fret, fingers[index] != barre.finger { return false }
            }
        }
        for (finger, indices) in fingerIndices where indices.count > 1 {
            guard barres.contains(where: { barre in
                barre.finger == finger && indices.allSatisfy { (barre.toString...barre.fromString).contains(6 - $0) }
            }) else { return false }
        }
        return true
    }

    private static func checked(chord: GuitarChord, frets: [Int], bass: GuitarNote,
                                allowed: Set<GuitarNote>, required: Set<GuitarNote>) -> GuitarChordShape? {
        guard frets.count == 6, frets.allSatisfy({ (-1...15).contains($0) }) else { return nil }
        let midis = zip(tuning, frets).compactMap { midi, fret in fret < 0 ? nil : midi + fret }
        guard let minimum = midis.min(), GuitarNote.fromMIDI(minimum) == bass else { return nil }
        let sounded = Set(midis.map(GuitarNote.fromMIDI))
        guard sounded.isSubset(of: allowed), required.isSubset(of: sounded) else { return nil }
        let positive = frets.filter { $0 > 0 }
        let base = frets.contains(0) ? 1 : positive.min() ?? 1
        guard (positive.max() ?? base) - base <= 4 else { return nil }

        // Minimal safe grouping at each fret: same-fret notes may share a finger
        // iff no intervening sounding string is open or fretted below the barre.
        // Muted strings may be crossed; higher-fretted strings sit above it.
        var groups: [(fret: Int, indices: [Int])] = []
        for fret in Set(positive).sorted() {
            var group: [Int] = []
            for index in 0..<6 where frets[index] == fret {
                if let last = group.last,
                   ((last + 1)..<index).contains(where: { frets[$0] >= 0 && frets[$0] < fret }) {
                    groups.append((fret, group))
                    group = []
                }
                group.append(index)
            }
            if !group.isEmpty { groups.append((fret, group)) }
        }
        guard groups.count <= 4 else { return nil }
        var fingers = [Int?](repeating: nil, count: 6)
        var barres: [GuitarBarre] = []
        for (offset, group) in groups.enumerated() {
            let finger = offset + 1
            for index in group.indices { fingers[index] = finger }
            if group.indices.count > 1 {
                barres.append(GuitarBarre(fret: group.fret, fromString: 6 - group.indices.first!,
                                         toString: 6 - group.indices.last!, finger: finger))
            }
        }
        return GuitarChordShape(chord: chord, frets: frets, fingers: fingers, barres: barres, baseFret: base)
    }
}
