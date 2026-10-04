import Foundation

/// A string in standard EADGBE tuning; muted strings have neither MIDI nor note.
public struct GuitarStringTone: Sendable, Equatable {
    public let stringNumber: Int
    public let fret: Int
    public let midi: Int?
    public var note: GuitarNote? { midi.map(GuitarNote.fromMIDI) }
}

/// A verified fingering. Identity includes the canonical chord/bass and all
/// fret, finger and barre geometry, rather than GuitarChordShape's chord-only ID.
public struct GuitarChordVoicing: Identifiable, Sendable, Equatable {
    public let id: String
    public let shape: GuitarChordShape
    /// True only for a verified curated chord/bass and complete fret/finger/barre
    /// geometry match. Playable generated fallbacks are not teaching conventions.
    /// Classification is metadata and is deliberately not part of the stable ID.
    public let isConventional: Bool
    public let openStringCount: Int
    public let barreCount: Int
    /// Lowest positive fret (0 for a shape with no fretted strings).
    public let lowestFret: Int
    public let maxFret: Int
    public let omittedNotes: [GuitarNote]
    /// Ordered from string 6 (low E) to string 1 (high E), including muted strings.
    public let stringNotes: [GuitarStringTone]

    init(shape: GuitarChordShape, selectionKey: String) {
        self.shape = shape
        isConventional = ConventionalGuitarFingerings.contains(shape)
        openStringCount = shape.frets.filter { $0 == 0 }.count
        barreCount = shape.barres.count
        lowestFret = shape.frets.filter { $0 > 0 }.min() ?? 0
        maxFret = shape.frets.filter { $0 >= 0 }.max() ?? 0
        stringNotes = zip(GuitarTuning.standard.strings, shape.frets).map { string, fret in
            GuitarStringTone(stringNumber: string.stringNumber, fret: fret,
                             midi: fret < 0 ? nil : string.midi + fret)
        }
        let sounded = Set(stringNotes.compactMap(\.note))
        omittedNotes = Set(shape.chord.notes).subtracting(sounded).sorted { $0.rawValue < $1.rawValue }
        let frets = shape.frets.map(String.init).joined(separator: ",")
        let fingers = shape.fingers.map { $0.map(String.init) ?? "-" }.joined(separator: ",")
        let barres = shape.barres.map {
            "\($0.fret):\($0.fromString):\($0.toString):\($0.finger)"
        }.sorted().joined(separator: ",")
        id = "v1|\(selectionKey)|\(frets)|\(fingers)|\(barres)|\(shape.baseFret)"
    }
}

/// Written chord data and verified, selectable concert-pitch fingerings.
/// Theory describes the written quality, not just the notes a guitar can sound.
public struct GuitarChordData: Sendable, Equatable {
    public let selectionKey: String
    public let symbol: String
    public let japaneseName: String
    public let explanation: String
    public let intervalLabels: [String]
    /// Quality tones in degree order, including any optional omitted tones.
    /// A non-chord slash bass is described separately in explanation.
    public let theoreticalNotes: [GuitarNote]
    /// Accepted quality SUFFIX aliases, not complete chord symbols.
    public let aliases: [String]
    /// Default first, then curated alternatives, then generated fallbacks (<= 18).
    /// Alternative searches are on demand and cached.
    public let voicings: [GuitarChordVoicing]

    /// Canonical root / quality / actual lowest pitch class, without a search.
    /// Enharmonic spellings, quality aliases and an explicit root bass share keys.
    public static func selectionKey(for symbol: String) -> String? {
        guard let parsed = parsedSymbol(symbol) else { return nil }
        return key(parsed)
    }

    // The shared legacy parser flattens parentheses for suffix alias lookup.
    // Do not let empty, nested or repeated groups masquerade as a known quality.
    static func parsedSymbol(_ symbol: String) -> ParsedGuitarChordSymbol? {
        guard let parsed = ParsedGuitarChordSymbol(symbol) else { return nil }
        let suffix = parsed.qualitySpelling.filter { !$0.isWhitespace }
        guard !suffix.contains("()") else { return nil }
        var depth = 0
        var groups = 0
        for character in suffix {
            if character == "(" {
                depth += 1
                groups += 1
                guard depth == 1, groups == 1 else { return nil }
            } else if character == ")" { depth -= 1 }
        }
        return parsed
    }

    static func key(_ parsed: ParsedGuitarChordSymbol) -> String {
        "\(parsed.chord.root.rawValue)|\(parsed.chord.quality.id)|\((parsed.bass ?? parsed.chord.root).rawValue)"
    }

    public init?(symbol: String) {
        let written = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Self.parsedSymbol(written),
              NoCapoGuitarVoicings.resolve(chord: parsed.chord, bass: parsed.bass) != nil else { return nil }
        self.symbol = written
        let canonicalKey = Self.key(parsed)
        selectionKey = canonicalKey
        let description = GuitarChordQualityData.forQuality(parsed.chord.quality)
        intervalLabels = description.degrees
        theoreticalNotes = parsed.chord.quality.intervals.map {
            GuitarNote.fromMIDI(parsed.chord.root.rawValue + $0)
        }
        aliases = description.aliases
        japaneseName = parsed.rootSpelling + "・" + description.name +
            (parsed.bassSpelling.map { "（ベース " + $0 + "）" } ?? "")
        var text = description.explanation + " 構成度数: " + intervalLabels.joined(separator: ", ") + "。"
        if let bass = parsed.bassSpelling { text += " 最低音は " + bass + "。" }
        let optional = NoCapoGuitarVoicings.optionalNotes(parsed.chord)
        if !optional.isEmpty {
            text += " ギターでは完全5度" + (parsed.chord.quality == .dominant13 ? "や11度" : "") + "を省略する場合があります。"
            if parsed.chord.quality == .dominant7 {
                text += " ドミナント7では長3度と短7度を保持し、指定されたベース音は省略しません。"
            }
        }
        explanation = text
        voicings = NoCapoGuitarVoicings.variants(chord: parsed.chord, bass: parsed.bass).map {
            GuitarChordVoicing(shape: $0, selectionKey: canonicalKey)
        }
    }
}

/// Explicit degree spelling: pitch-class intervalLabel cannot distinguish bb7
/// from 6, #9 from b3, or an extension from a suspension.
private struct GuitarChordQualityData {
    let name: String
    let explanation: String
    let degrees: [String]
    let aliases: [String]

    static func forQuality(_ quality: GuitarChordQuality) -> Self {
        let value: (String, String, [String], [String])
        switch quality {
        case .major: value = ("メジャー", "長3度を持つ長三和音。", ["1","3","5"], ["","M","maj"])
        case .minor: value = ("マイナー", "短3度を持つ短三和音。", ["1","b3","5"], ["m","min"])
        case .power5: value = ("パワーコード", "根音と完全5度のみ。3度を含まないため長短は決まりません。", ["1","5"], ["5"])
        case .major6: value = ("メジャー・シックス", "長三和音に長6度を加えます。7度は含みません。", ["1","3","5","6"], ["6"])
        case .minor6: value = ("マイナー・シックス", "短三和音に長6度を加えます。", ["1","b3","5","6"], ["m6"])
        case .dominant7: value = ("ドミナント・セブンス", "長三和音に短7度を加えます。", ["1","3","5","b7"], ["7"])
        case .major7: value = ("メジャー・セブンス", "長三和音に長7度を加えます。", ["1","3","5","7"], ["maj7","M7","△7","Δ7"])
        case .minor7: value = ("マイナー・セブンス", "短三和音に短7度を加えます。", ["1","b3","5","b7"], ["m7"])
        case .dominant9: value = ("ドミナント・ナインス", "ドミナント7に長9度を加えます。", ["1","3","5","b7","9"], ["9"])
        case .major9: value = ("メジャー・ナインス", "メジャー7に長9度を加えます。", ["1","3","5","7","9"], ["maj9","M9","△9"])
        case .minor9: value = ("マイナー・ナインス", "マイナー7に長9度を加えます。", ["1","b3","5","b7","9"], ["m9"])
        case .sus2: value = ("サス・ツー", "3度を長2度に置き換えます。", ["1","2","5"], ["sus2"])
        case .sus4: value = ("サス・フォー", "3度を完全4度に置き換えます。", ["1","4","5"], ["sus4","sus"])
        case .add9: value = ("アド・ナイン", "長三和音に長9度を加えます。7度は含みません。", ["1","3","5","9"], ["add9"])
        case .diminished: value = ("ディミニッシュ", "短3度と減5度を持つ減三和音。", ["1","b3","b5"], ["dim"])
        case .augmented: value = ("オーギュメント", "長3度と増5度を持つ増三和音。", ["1","3","#5"], ["aug","+"])
        case .halfDiminished7: value = ("ハーフ・ディミニッシュ", "減三和音に短7度を加えます。", ["1","b3","b5","b7"], ["m7(b5)","m7b5","m7-5","ø7"])
        case .diminished7: value = ("ディミニッシュ・セブンス", "減三和音に減7度を加えます。減7度は長6度と異名同音です。", ["1","b3","b5","bb7"], ["dim7","°7"])
        case .dominant7Sus4: value = ("セブンス・サス・フォー", "ドミナント7の3度を完全4度に置き換えます。", ["1","4","5","b7"], ["7sus4","7sus"])
        case .dominant7Flat9: value = ("セブンス・フラット・ナイン", "ドミナント7に短9度を加えます。", ["1","3","5","b7","b9"], ["7(b9)","7b9"])
        case .dominant7Sharp9: value = ("セブンス・シャープ・ナイン", "ドミナント7に増9度を加えます。長3度も含みます。", ["1","3","5","b7","#9"], ["7(#9)","7#9"])
        case .dominant7Sus4Flat9: value = ("セブンス・サス・フォー・フラット・ナイン", "セブンス・サス4に短9度を加えます。3度は含みません。", ["1","4","5","b7","b9"], ["7sus4(b9)","7sus4b9","7susb9"])
        case .minorMajor7: value = ("マイナー・メジャー・セブンス", "短三和音に長7度を加えます。", ["1","b3","5","7"], ["m(maj7)","mmaj7","mM7"])
        case .minorAdd9: value = ("マイナー・アド・ナイン", "短三和音に長9度を加えます。7度は含みません。", ["1","b3","5","9"], ["madd9"])
        case .majorSixNine: value = ("シックス・ナイン", "長三和音に長6度と長9度を加えます。6/9はベース指定ではありません。", ["1","3","5","6","9"], ["6/9"])
        case .minorSixNine: value = ("マイナー・シックス・ナイン", "短三和音に長6度と長9度を加えます。", ["1","b3","5","6","9"], ["m6/9"])
        case .add11: value = ("アド・イレブン", "長三和音に完全11度を加えます。3度を保持し、7度は含みません。", ["1","3","5","11"], ["add11"])
        case .dominant11: value = ("ドミナント・イレブンス", "ドミナント9に完全11度を加えます。この表記では長3度を保持します。", ["1","3","5","b7","9","11"], ["11"])
        case .minor11: value = ("マイナー・イレブンス", "マイナー9に完全11度を加えます。", ["1","b3","5","b7","9","11"], ["m11"])
        case .dominant13: value = ("ドミナント・サーティーンス", "ドミナント7に9度・11度・長13度を加えた理論構成です。", ["1","3","5","b7","9","11","13"], ["13"])
        case .minor13: value = ("マイナー・サーティーンス", "マイナー7に9度・11度・長13度を加えた理論構成です。", ["1","b3","5","b7","9","11","13"], ["m13"])
        case .dominant7Flat5: value = ("セブンス・フラット・ファイブ", "ドミナント7の5度を減5度に変えます。", ["1","3","b5","b7"], ["7(b5)","7b5"])
        case .dominant7Sharp5: value = ("セブンス・シャープ・ファイブ", "ドミナント7の5度を増5度に変えます。", ["1","3","#5","b7"], ["7(#5)","7#5"])
        case .dominant7Flat13: value = ("セブンス・フラット・サーティーン", "ドミナント7に短13度を加えます。", ["1","3","5","b7","b13"], ["7(b13)","7b13"])
        case .dominant7Sharp11: value = ("セブンス・シャープ・イレブン", "ドミナント7に増11度を加えます。完全5度も理論構成に含みます。", ["1","3","5","b7","#11"], ["7(#11)","7#11"])
        case .major7Sharp11: value = ("メジャー・セブンス・シャープ・イレブン", "メジャー7に増11度を加えます。", ["1","3","5","7","#11"], ["maj7(#11)","maj7#11"])
        case .dominant9Sus4: value = ("ナインス・サス・フォー", "ドミナント9の3度を完全4度に置き換えます。", ["1","4","5","b7","9"], ["9sus4","9sus"])
        }
        return Self(name: value.0, explanation: value.1, degrees: value.2, aliases: value.3)
    }
}
