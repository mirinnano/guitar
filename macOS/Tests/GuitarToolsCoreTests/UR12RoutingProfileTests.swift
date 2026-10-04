import CoreAudio
import XCTest
@testable import GuitarToolsMacApp

final class UR12RoutingProfileTests: XCTestCase {
    func testRecognizesBoundedModelNamesCaseInsensitively() {
        for name in ["UR12", "Steinberg UR12 ", "ur 12", "Yamaha UR-12", "(Ur12)", "UR12/USB"] {
            XCTAssertTrue(UR12RoutingProfile.isUR12(name: name), name)
        }
        for name in ["", "UR124", "UR22", "UR12mkII", "XUR12", "UR12_2", "UR-124", "UR 124", "UR--12"] {
            XCTAssertFalse(UR12RoutingProfile.isUR12(name: name), name)
        }
    }

    func testChannelLabelsUseZeroBasedInput2ForGuitarOnlyOnUR12() {
        XCTAssertEqual(UR12RoutingProfile.channelLabel(index: 0, deviceName: "Steinberg UR12"), "Ch1 MIC")
        XCTAssertEqual(UR12RoutingProfile.channelLabel(index: 1, deviceName: "UR-12"), "Ch2 HI-Zギター")
        XCTAssertEqual(UR12RoutingProfile.channelLabel(index: 2, deviceName: "UR12"), "Ch3")
        XCTAssertEqual(UR12RoutingProfile.channelLabel(index: 1, deviceName: "UR22"), "Ch2")
        XCTAssertEqual(UR12RoutingProfile.channelLabel(index: 0, deviceName: "Mac Microphone"), "Ch1")
        XCTAssertEqual(UR12RoutingProfile.channelLabel(index: -1, deviceName: "UR12"), "チャンネル不明")
        XCTAssertEqual(UR12RoutingProfile.channelLabel(index: Int.max, deviceName: "UR12"), "チャンネル不明")
    }

    func testAbsentUR12NeverSuggestsGenericHardware() {
        XCTAssertNil(configuration([], []))
        XCTAssertNil(configuration([input("mac", name: "Mac Microphone")], [output("mac", name: "Mac Speakers")]))
        XCTAssertNil(configuration([input("ur12")], []))
        XCTAssertNil(configuration([], [output("ur12")]))
        XCTAssertNil(configuration([input("ur22", name: "UR22")], [output("ur22", name: "UR22")]))
    }

    func testSinglePairWithSameUIDIsMatched() {
        XCTAssertEqual(configuration([input("shared")], [output("shared")]), UR12RoutingProfile.Configuration(inputUID: "shared", outputUID: "shared"))
    }

    func testUniqueSeparateUIDPairIsAllowedDespiteOtherGenericDevices() {
        let result = configuration(
            [input("mac-in", name: "Mac Microphone"), input("ur-in")],
            [output("mac-out", name: "Mac Speakers"), output("ur-out")]
        )
        XCTAssertEqual(result, UR12RoutingProfile.Configuration(inputUID: "ur-in", outputUID: "ur-out"))
    }

    func testPreferredUR12ResolvesMultipleInputsWhenSameUIDOutputExists() {
        let inputs = [input("a"), input("b")]
        let outputs = [output("a"), output("b")]
        XCTAssertNil(configuration(inputs, outputs))
        XCTAssertEqual(configuration(inputs, outputs, preferred: "b"), UR12RoutingProfile.Configuration(inputUID: "b", outputUID: "b"))
        XCTAssertNil(configuration(inputs, outputs, preferred: "missing"))
    }

    func testSameUIDOutputIsPreferredEvenWhenOtherUR12OutputsExist() {
        XCTAssertEqual(configuration([input("a")], [output("other"), output("a")]), UR12RoutingProfile.Configuration(inputUID: "a", outputUID: "a"))
    }

    func testSeparateUIDFallbackIsForbiddenWithAmbiguousInputsEvenIfPreferred() {
        XCTAssertNil(configuration([input("a"), input("b")], [output("out")], preferred: "a"))
    }

    func testSeparateUIDFallbackIsForbiddenWithAmbiguousOutputs() {
        XCTAssertNil(configuration([input("in")], [output("a"), output("b")], preferred: "in"))
    }

    func testNonUR12OrMonoPreferredInputCannotBeUsedForGuitar() {
        let valid = input("valid")
        let inputs = [input("mac", name: "Mac Microphone"), input("mono", channels: 1), valid]
        for preferred in ["mac", "mono", "missing"] {
            XCTAssertEqual(configuration(inputs, [output("valid")], preferred: preferred), UR12RoutingProfile.Configuration(inputUID: "valid", outputUID: "valid"))
        }
        XCTAssertNil(configuration([input("mono", channels: 1)], [output("mono")], preferred: "mono"))
        XCTAssertNil(configuration([input("in")], [output("out", channels: 1)]))
        XCTAssertNil(configuration([input("UR124", name: "UR124")], [output("UR124", name: "UR124")]))
    }

    func testEmptyOrDuplicateUIDsAreNotSafeSuggestions() {
        XCTAssertNil(configuration([input("")], [output("")]))
        XCTAssertNil(configuration([input("a"), input("a")], [output("a")], preferred: "a"))
        XCTAssertNil(configuration([input("a")], [output("a"), output("a")]))
    }

    private func configuration(
        _ inputs: [CoreAudioInputDevice],
        _ outputs: [CoreAudioOutputDevice],
        preferred: String? = nil
    ) -> UR12RoutingProfile.Configuration? {
        UR12RoutingProfile.configuration(inputs: inputs, outputs: outputs, preferredInputUID: preferred)
    }

    private func input(_ uid: String, name: String = "Steinberg UR12", channels: Int = 2) -> CoreAudioInputDevice {
        CoreAudioInputDevice(
            id: 10, uid: uid, name: name, channelCount: channels, sampleRate: 48_000,
            deviceLatencyFrames: 0, safetyOffsetFrames: 0, bufferFrameSize: 128
        )
    }

    private func output(_ uid: String, name: String = "Steinberg UR12", channels: Int = 2) -> CoreAudioOutputDevice {
        CoreAudioOutputDevice(id: 20, uid: uid, name: name, channelCount: channels, sampleRate: 48_000)
    }
}
