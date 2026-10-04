import Foundation

/// Pure routing suggestions. The caller must explicitly apply a user-confirmed configuration.
enum UR12RoutingProfile {
    struct Configuration: Equatable, Sendable {
        let inputUID: String
        let outputUID: String
    }

    static func isUR12(name: String) -> Bool {
        // A bounded model name, not UR124, UR22, or a larger alphanumeric identifier.
        name.range(
            of: #"(?<![\p{L}\p{N}_])UR(?:\s+|-)?12(?![\p{L}\p{N}_])"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    /// CoreAudio indices are zero-based: front INPUT 2 (HI-Z) is index 1.
    static func channelLabel(index: Int, deviceName: String) -> String {
        if isUR12(name: deviceName) {
            switch index {
            case 0: return "Ch1 MIC"
            case 1: return "Ch2 HI-Zギター"
            default: break
            }
        }
        guard index >= 0, index < Int.max else { return "チャンネル不明" }
        return "Ch\(index + 1)"
    }

    /// Only recognized stereo UR12 endpoints qualify; no generic/default device fallback.
    /// PHONES and LINE OUTPUT remain one output endpoint, never separate channel choices.
    static func configuration(
        inputs: [CoreAudioInputDevice],
        outputs: [CoreAudioOutputDevice],
        preferredInputUID: String?
    ) -> Configuration? {
        let qualifyingInputs = inputs.filter {
            isUR12(name: $0.name) && $0.channelCount >= 2 && !$0.uid.isEmpty
        }
        let qualifyingOutputs = outputs.filter {
            isUR12(name: $0.name) && $0.channelCount >= 2 && !$0.uid.isEmpty
        }

        let preferredInputs = qualifyingInputs.filter { $0.uid == preferredInputUID }
        let input: CoreAudioInputDevice
        if preferredInputs.count == 1 {
            input = preferredInputs[0]
        } else if preferredInputs.isEmpty, qualifyingInputs.count == 1 {
            input = qualifyingInputs[0]
        } else {
            return nil
        }

        let matchingOutputs = qualifyingOutputs.filter { $0.uid == input.uid }
        if matchingOutputs.count == 1 {
            return Configuration(inputUID: input.uid, outputUID: matchingOutputs[0].uid)
        }
        guard matchingOutputs.isEmpty,
              qualifyingInputs.count == 1,
              qualifyingOutputs.count == 1 else { return nil }
        return Configuration(inputUID: input.uid, outputUID: qualifyingOutputs[0].uid)
    }
}
