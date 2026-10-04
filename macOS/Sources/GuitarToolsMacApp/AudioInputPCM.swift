import AudioToolbox
import Foundation

struct InputCaptureFormat: Equatable {
    let sampleRate: Double
    let channelCount: Int
}

struct InputPCMBlock {
    let samples: [Float]
    let channelLevelsDBFS: [Double]
    let selectedChannelPeak: Float
}

struct InputCaptureFrame {
    let samples: [Float]
    let sampleRate: Double
    let timestampSeconds: Double
    let channelLevelsDBFS: [Double]
    let selectedChannelPeak: Float

    // A stereo render of N frames still represents N received frames, not 2N.
    var frameCount: Int { samples.count }
}

enum InputPCM {
    static let silenceDBFS = -120.0

    static func validateChannel(_ channel: Int, channelCount: Int) throws {
        guard channelCount > 0 else { throw InputCaptureError.noInputChannels }
        guard (0..<channelCount).contains(channel) else {
            throw InputCaptureError.channelUnavailable(channel: channel, channelCount: channelCount)
        }
    }

    static func float32Format(
        sampleRate: Double,
        channelCount: Int,
        interleaved: Bool = false
    ) throws -> AudioStreamBasicDescription {
        guard sampleRate.isFinite, sampleRate > 0,
              channelCount > 0, channelCount <= 256 else {
            throw InputCaptureError.invalidFormat
        }
        let bytesPerFrame = UInt32(MemoryLayout<Float>.size * (interleaved ? channelCount : 1))
        return AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagsNativeFloatPacked | (interleaved ? 0 : kAudioFormatFlagIsNonInterleaved),
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: UInt32(channelCount),
            mBitsPerChannel: 32,
            mReserved: 0
        )
    }

    /// The HAL's input-scope / bus 1 ASBD is authoritative. Never use an engine's
    /// cached input-node format, downmix the device, or clamp the chosen channel.
    static func clientFormat(
        hardware: AudioStreamBasicDescription,
        expectedChannelCount: Int,
        selectedChannel: Int
    ) throws -> AudioStreamBasicDescription {
        guard hardware.mFormatID == kAudioFormatLinearPCM,
              hardware.mSampleRate.isFinite, hardware.mSampleRate > 0,
              hardware.mChannelsPerFrame > 0 else {
            throw InputCaptureError.invalidFormat
        }
        guard Int(hardware.mChannelsPerFrame) == expectedChannelCount else {
            throw InputCaptureError.channelCountMismatch(
                expected: expectedChannelCount,
                actual: Int(hardware.mChannelsPerFrame)
            )
        }
        try validateChannel(selectedChannel, channelCount: expectedChannelCount)
        return try float32Format(sampleRate: hardware.mSampleRate, channelCount: expectedChannelCount)
    }

    static func validateNegotiatedFormat(
        _ actual: AudioStreamBasicDescription,
        requested: AudioStreamBasicDescription
    ) throws {
        try validateFloat32(actual)
        guard actual.mChannelsPerFrame == requested.mChannelsPerFrame else {
            throw InputCaptureError.channelCountMismatch(
                expected: Int(requested.mChannelsPerFrame),
                actual: Int(actual.mChannelsPerFrame)
            )
        }
        guard abs(actual.mSampleRate - requested.mSampleRate) < 0.001,
              actual.mFormatFlags == requested.mFormatFlags,
              actual.mBytesPerFrame == requested.mBytesPerFrame else {
            throw InputCaptureError.clientFormatMismatch
        }
    }

    static func validateFloat32(_ format: AudioStreamBasicDescription) throws {
        let interleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
        let channels = Int(format.mChannelsPerFrame)
        let expectedBytes = MemoryLayout<Float>.size * (interleaved ? channels : 1)
        guard format.mSampleRate.isFinite, format.mSampleRate > 0,
              channels > 0, channels <= 256,
              format.mFormatID == kAudioFormatLinearPCM,
              format.mBitsPerChannel == 32,
              format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              format.mFormatFlags & kAudioFormatFlagIsPacked != 0,
              format.mFormatFlags & kAudioFormatFlagIsBigEndian == kAudioFormatFlagsNativeEndian,
              format.mFramesPerPacket == 1,
              format.mBytesPerFrame == UInt32(expectedBytes),
              format.mBytesPerPacket == UInt32(expectedBytes) else {
            throw InputCaptureError.invalidFormat
        }
    }

    /// Supports planar and interleaved native Float32 PCM. All bounds and buffer
    /// layouts are checked before reading any pointer; Ch 2 on mono is an error.
    static func extract(
        bufferList: UnsafePointer<AudioBufferList>,
        frameCount: Int,
        format: AudioStreamBasicDescription,
        selectedChannel: Int
    ) throws -> InputPCMBlock {
        try validateFloat32(format)
        let channels = Int(format.mChannelsPerFrame)
        try validateChannel(selectedChannel, channelCount: channels)
        let interleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
        let stride = interleaved ? channels : 1
        guard frameCount >= 0,
              frameCount <= Int(UInt32.max) / (MemoryLayout<Float>.size * stride) else {
            throw InputCaptureError.invalidBuffer
        }
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: bufferList))
        guard buffers.count == (interleaved ? 1 : channels) else {
            throw InputCaptureError.invalidBuffer
        }
        let requiredBytes = frameCount * MemoryLayout<Float>.size * stride
        for buffer in buffers {
            guard buffer.mNumberChannels == UInt32(interleaved ? channels : 1),
                  Int(buffer.mDataByteSize) >= requiredBytes,
                  frameCount == 0 || buffer.mData != nil else {
                throw InputCaptureError.invalidBuffer
            }
        }
        guard frameCount > 0 else {
            return InputPCMBlock(samples: [], channelLevelsDBFS: Array(repeating: silenceDBFS, count: channels), selectedChannelPeak: 0)
        }

        var samples = [Float](repeating: 0, count: frameCount)
        var levels = [Double](repeating: silenceDBFS, count: channels)
        var selectedPeak: Float = 0
        for channel in 0..<channels {
            let pointer = buffers[interleaved ? 0 : channel].mData!.assumingMemoryBound(to: Float.self)
            let offset = interleaved ? channel : 0
            var sumSquares = 0.0
            for frame in 0..<frameCount {
                let raw = pointer[frame * stride + offset]
                let sample: Float = raw.isFinite ? raw : 0
                sumSquares += Double(sample) * Double(sample)
                if channel == selectedChannel {
                    samples[frame] = sample
                    selectedPeak = max(selectedPeak, abs(sample))
                }
            }
            let rms = sqrt(sumSquares / Double(frameCount))
            levels[channel] = max(silenceDBFS, 20 * log10(max(rms, 1e-6)))
        }
        return InputPCMBlock(samples: samples, channelLevelsDBFS: levels, selectedChannelPeak: selectedPeak)
    }

    static func bufferStartTime(
        timestamp: AudioTimeStamp,
        frameCount: Int,
        sampleRate: Double,
        clock: any AudioHostClock
    ) -> Double {
        if timestamp.mFlags.contains(.hostTimeValid) {
            return clock.seconds(forHostTime: timestamp.mHostTime)
        }
        return clock.nowSeconds() - Double(frameCount) / sampleRate
    }
}

enum InputCaptureError: LocalizedError {
    case noInputChannels
    case noDefaultInput
    case selectedDeviceUnavailable
    case invalidSavedChannel
    case channelUnavailable(channel: Int, channelCount: Int)
    case channelCountMismatch(expected: Int, actual: Int)
    case invalidFormat
    case clientFormatMismatch
    case invalidBuffer
    case deviceMismatch
    case missingHAL
    case operationFailed(operation: String, status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .noInputChannels:
            "使用可能なオーディオ入力チャンネルがありません。"
        case .noDefaultInput:
            "システムのデフォルト入力が見つかりません。別の入力には切り替えません。"
        case .selectedDeviceUnavailable:
            "選択したオーディオ入力デバイスが接続されていません。別の入力には切り替えず、再接続を待ちます。"
        case .invalidSavedChannel:
            "入力チャンネルは Ch 1〜Ch 64 の範囲で指定してください。"
        case let .channelUnavailable(channel, channelCount):
            "選択した Ch \(channel + 1) はこの入力（\(channelCount) チャンネル）で使用できません。Ch 1 には切り替えません。"
        case let .channelCountMismatch(expected, actual):
            "入力形式がデバイス情報と一致しません（必要: \(expected) チャンネル、取得: \(actual) チャンネル）。モノラルや別チャンネルには切り替えません。"
        case .invalidFormat:
            "オーディオ入力の形式またはサンプルレートが不正です。"
        case .clientFormatMismatch:
            "ハードウェア本来のサンプルレート・全入力チャンネルで収録できません。別の形式には切り替えません。"
        case .invalidBuffer:
            "入力PCMバッファのサイズまたはチャンネル配置が不正です。入力を停止しました。"
        case .deviceMismatch:
            "指定した入力デバイスへの接続を確認できません。別の入力には切り替えません。"
        case .missingHAL:
            "入力専用のCoreAudio AudioUnitを作成できませんでした。"
        case let .operationFailed(operation, status):
            "\(operation)に失敗しました（CoreAudio OSStatus \(status)）。"
        }
    }
}
