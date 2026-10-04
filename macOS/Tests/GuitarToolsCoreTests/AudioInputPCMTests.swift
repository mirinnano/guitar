import AudioToolbox
import CoreAudio
import Foundation
import XCTest
@testable import GuitarToolsMacApp

/// Synthetic PCM only: no AudioUnit, device query, microphone or permission API.
final class AudioInputPCMTests: XCTestCase {
    func testMonoSamplesAndLevel() throws {
        let samples: [Float] = [-0.5, 0.5, 0, -1]
        let pcm = SyntheticInputPCM(channels: [samples])
        let format = try InputPCM.float32Format(sampleRate: 48_000, channelCount: 1)
        let block = try InputPCM.extract(bufferList: UnsafePointer(pcm.list), frameCount: 4, format: format, selectedChannel: 0)
        XCTAssertEqual(block.samples, samples)
        XCTAssertEqual(block.channelLevelsDBFS.count, 1)
        XCTAssertEqual(block.channelLevelsDBFS[0], 20 * log10(sqrt(1.5 / 4)), accuracy: 0.00001)
        XCTAssertEqual(block.selectedChannelPeak, 1)
    }

    func testUR12Ch2GuitarIsNotReplacedBySilentCh1() throws {
        let guitar: [Float] = [0.2, -0.4, 0.6, -0.8]
        let pcm = SyntheticInputPCM(channels: [[0, 0, 0, 0], guitar])
        let format = try InputPCM.float32Format(sampleRate: 48_000, channelCount: 2)
        let block = try InputPCM.extract(bufferList: UnsafePointer(pcm.list), frameCount: 4, format: format, selectedChannel: 1)
        XCTAssertEqual(block.samples, guitar)
        XCTAssertEqual(block.channelLevelsDBFS[0], -120)
        XCTAssertEqual(block.channelLevelsDBFS[1], 20 * log10(sqrt(0.3)), accuracy: 0.00001)
        XCTAssertEqual(block.selectedChannelPeak, 0.8)
        let frame = InputCaptureFrame(samples: block.samples, sampleRate: 48_000, timestampSeconds: 10, channelLevelsDBFS: block.channelLevelsDBFS, selectedChannelPeak: block.selectedChannelPeak)
        XCTAssertEqual(frame.frameCount, 4, "Count hardware frames, not buffers or frames × channels")
    }

    func testChannelsRemainIndependentAndInHardwareOrder() throws {
        let left: [Float] = [0.1, 0.2, 0.3]
        let right: [Float] = [-0.7, -0.8, -0.9]
        let pcm = SyntheticInputPCM(channels: [left, right])
        let format = try InputPCM.float32Format(sampleRate: 44_100, channelCount: 2)
        for (channel, expected) in [left, right].enumerated() {
            let block = try InputPCM.extract(bufferList: UnsafePointer(pcm.list), frameCount: 3, format: format, selectedChannel: channel)
            XCTAssertEqual(block.samples, expected)
            XCTAssertGreaterThan(block.channelLevelsDBFS[1], block.channelLevelsDBFS[0])
        }
    }

    func testInterleavedStereoExtractsCh2WithCorrectStride() throws {
        let right: [Float] = [0.25, -0.5, 0.75, -1]
        let pcm = SyntheticInputPCM(channels: [[0, 0, 0, 0], right], interleaved: true)
        let format = try InputPCM.float32Format(sampleRate: 48_000, channelCount: 2, interleaved: true)
        let block = try InputPCM.extract(bufferList: UnsafePointer(pcm.list), frameCount: 4, format: format, selectedChannel: 1)
        XCTAssertEqual(block.samples, right)
        XCTAssertEqual(block.channelLevelsDBFS[0], -120)
        XCTAssertEqual(block.channelLevelsDBFS[1], 20 * log10(sqrt(0.46875)), accuracy: 0.00001)
        XCTAssertEqual(block.selectedChannelPeak, 1)
    }

    func testChosenChannelGuardThrowsInsteadOfClampingMonoCh2() throws {
        let pcm = SyntheticInputPCM(channels: [[0.5, 0.5]])
        let format = try InputPCM.float32Format(sampleRate: 48_000, channelCount: 1)
        for channel in [-1, 1, 2, 63] {
            XCTAssertThrowsError(try InputPCM.extract(bufferList: UnsafePointer(pcm.list), frameCount: 2, format: format, selectedChannel: channel)) { error in
                guard case InputCaptureError.channelUnavailable(_, 1) = error else {
                    return XCTFail("Expected explicit unavailable-channel error, got \(error)")
                }
                XCTAssertTrue(error.localizedDescription.contains("Ch 1 には切り替えません"))
            }
        }
    }

    func testShortOrMissingBufferAndWrongLayoutAreRejectedBeforeRead() throws {
        let pcm = SyntheticInputPCM(channels: [[0.25, 0.5], [0.75, 1]])
        let format = try InputPCM.float32Format(sampleRate: 48_000, channelCount: 2)
        let buffers = UnsafeMutableAudioBufferListPointer(pcm.list)
        buffers[1].mDataByteSize = 4
        XCTAssertThrowsError(try InputPCM.extract(bufferList: UnsafePointer(pcm.list), frameCount: 2, format: format, selectedChannel: 1))
        buffers[1].mDataByteSize = 8
        let pointer = buffers[1].mData
        buffers[1].mData = nil
        XCTAssertThrowsError(try InputPCM.extract(bufferList: UnsafePointer(pcm.list), frameCount: 2, format: format, selectedChannel: 1))
        buffers[1].mData = pointer
        buffers[1].mNumberChannels = 2
        XCTAssertThrowsError(try InputPCM.extract(bufferList: UnsafePointer(pcm.list), frameCount: 2, format: format, selectedChannel: 1))
        buffers[1].mNumberChannels = 1
        pcm.list.pointee.mNumberBuffers = 1
        XCTAssertThrowsError(try InputPCM.extract(bufferList: UnsafePointer(pcm.list), frameCount: 2, format: format, selectedChannel: 1))
        pcm.list.pointee.mNumberBuffers = 2
        XCTAssertThrowsError(try InputPCM.extract(bufferList: UnsafePointer(pcm.list), frameCount: -1, format: format, selectedChannel: 1))
        XCTAssertThrowsError(try InputPCM.extract(bufferList: UnsafePointer(pcm.list), frameCount: Int.max, format: format, selectedChannel: 1))
    }

    func testNonFiniteSamplesCannotPoisonMetersOrAnalysis() throws {
        let pcm = SyntheticInputPCM(channels: [[.nan, .infinity, -.infinity, 0.5]])
        let format = try InputPCM.float32Format(sampleRate: 48_000, channelCount: 1)
        let block = try InputPCM.extract(bufferList: UnsafePointer(pcm.list), frameCount: 4, format: format, selectedChannel: 0)
        XCTAssertEqual(block.samples, [0, 0, 0, 0.5])
        XCTAssertEqual(block.channelLevelsDBFS[0], 20 * log10(0.25), accuracy: 0.00001)
        XCTAssertEqual(block.selectedChannelPeak, 0.5)
    }

    func testZeroFramesAreEmptyRatherThanReadingStaleStorage() throws {
        let pcm = SyntheticInputPCM(channels: [[1], [1]])
        let format = try InputPCM.float32Format(sampleRate: 48_000, channelCount: 2)
        let block = try InputPCM.extract(bufferList: UnsafePointer(pcm.list), frameCount: 0, format: format, selectedChannel: 1)
        XCTAssertTrue(block.samples.isEmpty)
        XCTAssertEqual(block.channelLevelsDBFS, [-120, -120])
        XCTAssertEqual(block.selectedChannelPeak, 0)
    }

    func testNegotiationUsesNativeHardwareRateAndAllChannels() throws {
        // Hardware may be integer/interleaved; the requested client is planar
        // Float32 at 48k, never a stale 44.1k / mono engine-node format.
        var hardware = try InputPCM.float32Format(sampleRate: 48_000, channelCount: 2, interleaved: true)
        hardware.mBitsPerChannel = 16
        hardware.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        hardware.mBytesPerFrame = 4
        hardware.mBytesPerPacket = 4
        let client = try InputPCM.clientFormat(hardware: hardware, expectedChannelCount: 2, selectedChannel: 1)
        XCTAssertEqual(client.mSampleRate, 48_000)
        XCTAssertEqual(client.mChannelsPerFrame, 2)
        XCTAssertEqual(client.mBitsPerChannel, 32)
        XCTAssertEqual(client.mBytesPerFrame, 4)
        XCTAssertNotEqual(client.mFormatFlags & kAudioFormatFlagIsNonInterleaved, 0)
        XCTAssertNoThrow(try InputPCM.validateNegotiatedFormat(client, requested: client))
    }

    func testStaleMonoSourceFormatForTwoChannelHardwareMustThrow() throws {
        let mono = try InputPCM.float32Format(sampleRate: 44_100, channelCount: 1)
        XCTAssertThrowsError(try InputPCM.clientFormat(hardware: mono, expectedChannelCount: 2, selectedChannel: 1)) { error in
            guard case InputCaptureError.channelCountMismatch(2, 1) = error else {
                return XCTFail("Expected mono mismatch, got \(error)")
            }
            XCTAssertTrue(error.localizedDescription.contains("モノラルや別チャンネルには切り替えません"))
        }
        XCTAssertThrowsError(try InputPCM.clientFormat(hardware: mono, expectedChannelCount: 1, selectedChannel: 1))
    }

    func testNegotiatedMonoRateOrLayoutFallbackIsRejected() throws {
        let requested = try InputPCM.float32Format(sampleRate: 48_000, channelCount: 2)
        for actual in [
            try InputPCM.float32Format(sampleRate: 48_000, channelCount: 1),
            try InputPCM.float32Format(sampleRate: 44_100, channelCount: 2),
            try InputPCM.float32Format(sampleRate: 48_000, channelCount: 2, interleaved: true)
        ] {
            XCTAssertThrowsError(try InputPCM.validateNegotiatedFormat(actual, requested: requested))
        }
        var unsupported = requested
        unsupported.mBitsPerChannel = 64
        XCTAssertThrowsError(try InputPCM.validateNegotiatedFormat(unsupported, requested: requested))
        for rate in [0.0, -1, .nan, .infinity] {
            var hardware = requested
            hardware.mSampleRate = rate
            XCTAssertThrowsError(try InputPCM.clientFormat(hardware: hardware, expectedChannelCount: 2, selectedChannel: 1))
        }
    }

    func testTimestampUsesInputHostTimeOrFrameDurationFallback() {
        let clock = PCMTestClock(now: 100)
        var timestamp = AudioTimeStamp()
        timestamp.mFlags = .hostTimeValid
        timestamp.mHostTime = 12_345_000
        XCTAssertEqual(InputPCM.bufferStartTime(timestamp: timestamp, frameCount: 480, sampleRate: 48_000, clock: clock), 12.345, accuracy: 0.000001)
        timestamp.mFlags = []
        XCTAssertEqual(InputPCM.bufferStartTime(timestamp: timestamp, frameCount: 480, sampleRate: 48_000, clock: clock), 99.99, accuracy: 0.000001)
    }

    func testMetersCountFramesAndThrottleButRetainClippingBetweenPublications() throws {
        var meter = InputMeterAccumulator()
        let first = meter.ingest(frame(count: 128), at: 100)
        XCTAssertEqual(first?.receivedFrameCount, 128)
        XCTAssertEqual(first?.channelLevelsDBFS, [-120, -6])
        XCTAssertEqual(first?.clipping, false)
        XCTAssertNil(meter.ingest(frame(count: 256, peak: 1), at: 100.05))
        let next = meter.ingest(frame(count: 64), at: 100.11)
        XCTAssertEqual(next?.receivedFrameCount, 448)
        XCTAssertEqual(next?.clipping, true)
        XCTAssertEqual(meter.ingest(frame(count: 32), at: 100.22)?.clipping, false)
    }

    func testMeterPublicationIsApproximatelyTenHz() {
        var meter = InputMeterAccumulator()
        var publications = 0
        for index in 0..<100 {
            if meter.ingest(frame(count: 64), at: Double(index) * 0.01) != nil { publications += 1 }
        }
        XCTAssertGreaterThanOrEqual(publications, 9)
        XCTAssertLessThanOrEqual(publications, 11)
        XCTAssertEqual(meter.receivedFrameCount, 6_400)
    }

    func testGenerationsRejectStoppedAndPreviousRouteWork() {
        let gate = InputCaptureGenerationGate()
        let first = gate.begin()
        XCTAssertTrue(gate.accepts(first))
        gate.invalidate()
        XCTAssertFalse(gate.accepts(first))
        let next = gate.begin()
        XCTAssertNotEqual(next, first)
        XCTAssertFalse(gate.accepts(first))
        XCTAssertTrue(gate.accepts(next))
        let third = gate.begin()
        XCTAssertFalse(gate.accepts(next))
        XCTAssertTrue(gate.accepts(third))
        var deliveries = 0
        gate.performIfCurrent(first) { deliveries += 1 }
        gate.performIfCurrent(next) { deliveries += 1 }
        XCTAssertEqual(deliveries, 0)
        gate.performIfCurrent(third) { deliveries += 1 }
        XCTAssertEqual(deliveries, 1)
    }

    func testExplicitMissingUIDNeverReadsDefaultAndReconnectResolvesNewID() throws {
        let mac = device(id: 10, uid: "mac", channels: 1)
        let reconnected = device(id: 99, uid: "ur12", channels: 2)
        var defaultReads = 0
        let defaultID = { defaultReads += 1; return Optional(mac.id) }
        XCTAssertThrowsError(try InputRoutePolicy.resolve(uid: "ur12", devices: [mac], defaultDeviceID: defaultID))
        XCTAssertEqual(defaultReads, 0)
        XCTAssertEqual(try InputRoutePolicy.resolve(uid: "ur12", devices: [mac, reconnected], defaultDeviceID: defaultID).id, 99)
        XCTAssertEqual(defaultReads, 0)
        XCTAssertEqual(try InputRoutePolicy.resolve(uid: nil, devices: [reconnected, mac], defaultDeviceID: defaultID).id, 10)
        XCTAssertEqual(defaultReads, 1)
    }

    func testMissingDefaultDoesNotSelectFirstAvailableDevice() {
        let devices = [device(id: 51, uid: "ur12", channels: 2)]
        XCTAssertThrowsError(try InputRoutePolicy.resolve(uid: nil, devices: devices, defaultDeviceID: { nil }))
        XCTAssertThrowsError(try InputRoutePolicy.resolve(uid: nil, devices: devices, defaultDeviceID: { 1000 }))
    }

    private func frame(count: Int, peak: Float = 0.5) -> InputCaptureFrame {
        InputCaptureFrame(samples: Array(repeating: 0.5, count: count), sampleRate: 48_000, timestampSeconds: 100, channelLevelsDBFS: [-120, -6], selectedChannelPeak: peak)
    }

    private func device(id: AudioDeviceID, uid: String, channels: Int) -> CoreAudioInputDevice {
        CoreAudioInputDevice(id: id, uid: uid, name: uid, channelCount: channels, sampleRate: 48_000, deviceLatencyFrames: 0, safetyOffsetFrames: 0, bufferFrameSize: 128)
    }
}

private struct PCMTestClock: AudioHostClock {
    let now: Double
    func nowSeconds() -> Double { now }
    func seconds(forHostTime hostTime: UInt64) -> Double { Double(hostTime) / 1_000_000 }
}

private final class SyntheticInputPCM {
    let list: UnsafeMutablePointer<AudioBufferList>
    private let allocation: UnsafeMutableRawPointer
    private var data: [(UnsafeMutablePointer<Float>, Int)] = []

    init(channels: [[Float]], interleaved: Bool = false) {
        precondition(!channels.isEmpty && channels.allSatisfy { $0.count == channels[0].count })
        let bufferCount = interleaved ? 1 : channels.count
        let size = MemoryLayout<AudioBufferList>.size + (bufferCount - 1) * MemoryLayout<AudioBuffer>.stride
        allocation = .allocate(byteCount: size, alignment: MemoryLayout<AudioBufferList>.alignment)
        list = allocation.bindMemory(to: AudioBufferList.self, capacity: 1)
        list.initialize(to: AudioBufferList())
        list.pointee.mNumberBuffers = UInt32(bufferCount)
        let contents: [[Float]] = interleaved
            ? [(0..<channels[0].count).flatMap { frame in channels.map { $0[frame] } }]
            : channels
        let buffers = UnsafeMutableAudioBufferListPointer(list)
        for (index, samples) in contents.enumerated() {
            let pointer = UnsafeMutablePointer<Float>.allocate(capacity: max(samples.count, 1))
            pointer.initialize(from: samples, count: samples.count)
            data.append((pointer, samples.count))
            buffers[index] = AudioBuffer(mNumberChannels: UInt32(interleaved ? channels.count : 1), mDataByteSize: UInt32(samples.count * MemoryLayout<Float>.size), mData: UnsafeMutableRawPointer(pointer))
        }
    }

    deinit {
        for (pointer, count) in data {
            pointer.deinitialize(count: count)
            pointer.deallocate()
        }
        list.deinitialize(count: 1)
        allocation.deallocate()
    }
}
