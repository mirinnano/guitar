import AudioToolbox
import CoreAudio
import Foundation

protocol AudioInputCapturing: AnyObject {
    /// No permission request or default-device mutation occurs in this adapter.
    func start(
        device: CoreAudioInputDevice,
        channel: Int,
        clock: any AudioHostClock,
        onFrame: @escaping (InputCaptureFrame) -> Void,
        onError: @escaping (Error) -> Void,
        onConfigurationChanged: @escaping () -> Void
    ) throws -> InputCaptureFormat

    func stop()
}

/// Explicit, input-only AUHAL. Bus 1 is hardware input; bus 0 output I/O is
/// disabled. No AVAudioEngine, output graph, or system default is touched.
final class CoreAudioInputCapture: AudioInputCapturing {
    private var audioUnit: AudioUnit?
    private var initialized = false
    private var buffers: InputHALBufferStorage?
    private var format: AudioStreamBasicDescription?
    private var channel = 0
    private var clock: (any AudioHostClock)?
    private var onFrame: ((InputCaptureFrame) -> Void)?
    private var onError: ((Error) -> Void)?
    private var onConfigurationChanged: (() -> Void)?
    private var callbackContext: InputHALCallbackContext?
    private var callbackFailed = false
    private let renderLock = NSLock()
    private var listeners: [(AudioDeviceID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var listenerGeneration: UUID?

    func start(
        device: CoreAudioInputDevice,
        channel: Int,
        clock: any AudioHostClock,
        onFrame: @escaping (InputCaptureFrame) -> Void,
        onError: @escaping (Error) -> Void,
        onConfigurationChanged: @escaping () -> Void
    ) throws -> InputCaptureFormat {
        stop()
        guard device.id != kAudioObjectUnknown else { throw InputCaptureError.deviceMismatch }
        try InputPCM.validateChannel(channel, channelCount: device.channelCount)

        do {
            var description = AudioComponentDescription(
                componentType: kAudioUnitType_Output,
                componentSubType: kAudioUnitSubType_HALOutput,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
            guard let component = AudioComponentFindNext(nil, &description) else {
                throw InputCaptureError.missingHAL
            }
            var instance: AudioComponentInstance?
            try check(AudioComponentInstanceNew(component, &instance), operation: "入力AudioUnitの作成")
            guard let unit = instance else { throw InputCaptureError.missingHAL }
            audioUnit = unit

            var enabled: UInt32 = 1
            var disabled: UInt32 = 0
            try set(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enabled, operation: "入力I/Oの有効化")
            try set(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &disabled, operation: "出力I/Oの無効化")
            let inputIO: UInt32 = try get(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, initial: 0, operation: "入力I/Oの確認")
            let outputIO: UInt32 = try get(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, initial: 1, operation: "出力I/Oの確認")
            guard inputIO == 1, outputIO == 0 else { throw InputCaptureError.missingHAL }

            // AUHAL CurrentDevice is global / element 0. Verify it, rather than
            // assuming a successful set changed an AVAudioEngine cached format.
            var deviceID = device.id
            try set(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &deviceID, operation: "入力デバイスの指定")
            try verifyDevice(unit, expected: device.id)

            let hardware = try streamFormat(unit, scope: kAudioUnitScope_Input)
            var client = try InputPCM.clientFormat(
                hardware: hardware,
                expectedChannelCount: device.channelCount,
                selectedChannel: channel
            )
            try set(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &client, operation: "全入力チャンネルのFloat32形式の設定")
            try InputPCM.validateNegotiatedFormat(try streamFormat(unit, scope: kAudioUnitScope_Output), requested: client)

            let currentMaximum: UInt32 = try get(unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, initial: 0, operation: "入力最大フレーム数の取得")
            var maximumFrames = max(4_096, currentMaximum, device.bufferFrameSize)
            guard maximumFrames <= 1_048_576 else { throw InputCaptureError.invalidBuffer }
            try set(unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFrames, operation: "入力最大フレーム数の設定")
            let actualMaximum: UInt32 = try get(unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, initial: 0, operation: "入力最大フレーム数の確認")
            guard actualMaximum > 0, actualMaximum <= 1_048_576 else { throw InputCaptureError.invalidBuffer }

            self.buffers = InputHALBufferStorage(channelCount: device.channelCount, maximumFrames: Int(actualMaximum))
            self.format = client
            self.channel = channel
            self.clock = clock
            self.onFrame = onFrame
            self.onError = onError
            self.onConfigurationChanged = onConfigurationChanged
            self.callbackFailed = false
            let context = InputHALCallbackContext(owner: self)
            callbackContext = context
            var callback = AURenderCallbackStruct(
                inputProc: { reference, flags, timestamp, _, frameCount, _ in
                    let context = Unmanaged<InputHALCallbackContext>.fromOpaque(reference).takeUnretainedValue()
                    guard let owner = context.owner else { return noErr }
                    return owner.render(flags: flags, timestamp: timestamp, frameCount: frameCount)
                },
                inputProcRefCon: Unmanaged.passUnretained(context).toOpaque()
            )
            try set(unit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callback, operation: "入力コールバックの設定")
            try check(AudioUnitInitialize(unit), operation: "入力AudioUnitの初期化")
            initialized = true

            // Some drivers finish negotiating at initialization. Reject any
            // late mono/rate change, instead of silently selecting Ch 1.
            try verifyDevice(unit, expected: device.id)
            let initializedHardware = try streamFormat(unit, scope: kAudioUnitScope_Input)
            let initializedClient = try InputPCM.clientFormat(
                hardware: initializedHardware,
                expectedChannelCount: device.channelCount,
                selectedChannel: channel
            )
            try InputPCM.validateNegotiatedFormat(initializedClient, requested: client)
            try InputPCM.validateNegotiatedFormat(try streamFormat(unit, scope: kAudioUnitScope_Output), requested: client)
            try installDeviceListeners(device.id)
            try check(AudioOutputUnitStart(unit), operation: "オーディオ入力の開始")
            return InputCaptureFormat(sampleRate: client.mSampleRate, channelCount: Int(client.mChannelsPerFrame))
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        removeDeviceListeners()
        guard let unit = audioUnit else { return }
        // Do not hold renderLock while stopping I/O: an in-flight callback may
        // need it. Stop first, then drain that callback before freeing storage.
        // Even a failed start may have partially armed I/O.
        AudioOutputUnitStop(unit)
        renderLock.lock()
        audioUnit = nil
        buffers = nil
        format = nil
        clock = nil
        onFrame = nil
        onError = nil
        onConfigurationChanged = nil
        callbackFailed = false
        renderLock.unlock()
        if initialized { AudioUnitUninitialize(unit) }
        initialized = false
        AudioComponentInstanceDispose(unit)
        // Keep the callback reference alive until the AudioUnit is disposed.
        callbackContext = nil
    }

    deinit { stop() }

    private func render(
        flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timestamp: UnsafePointer<AudioTimeStamp>,
        frameCount: UInt32
    ) -> OSStatus {
        renderLock.lock()
        defer { renderLock.unlock() }
        guard !callbackFailed, let unit = audioUnit, let buffers, let format, let clock else { return noErr }
        guard frameCount > 0 else { return noErr }
        guard Int(frameCount) <= buffers.maximumFrames else {
            failCallback(InputCaptureError.invalidBuffer)
            return kAudio_ParamError
        }
        buffers.prepare(frameCount: Int(frameCount))
        let status = AudioUnitRender(unit, flags, timestamp, 1, frameCount, buffers.list)
        guard status == noErr else {
            failCallback(InputCaptureError.operationFailed(operation: "入力PCMの取得", status: status))
            return status
        }
        do {
            let block = try InputPCM.extract(
                bufferList: UnsafePointer(buffers.list),
                frameCount: Int(frameCount),
                format: format,
                selectedChannel: channel
            )
            onFrame?(InputCaptureFrame(
                samples: block.samples,
                sampleRate: format.mSampleRate,
                timestampSeconds: InputPCM.bufferStartTime(
                    timestamp: timestamp.pointee,
                    frameCount: Int(frameCount),
                    sampleRate: format.mSampleRate,
                    clock: clock
                ),
                channelLevelsDBFS: block.channelLevelsDBFS,
                selectedChannelPeak: block.selectedChannelPeak
            ))
            return noErr
        } catch {
            failCallback(error)
            return kAudio_ParamError
        }
    }

    private func failCallback(_ error: Error) {
        guard !callbackFailed else { return }
        callbackFailed = true
        // The model only enqueues work here; it never stops the unit on its
        // render thread or does chord analysis/UI publishing in this callback.
        onError?(error)
    }

    private func streamFormat(_ unit: AudioUnit, scope: AudioUnitScope) throws -> AudioStreamBasicDescription {
        try get(unit, kAudioUnitProperty_StreamFormat, scope, 1, initial: AudioStreamBasicDescription(), operation: "入力形式の取得")
    }

    private func verifyDevice(_ unit: AudioUnit, expected: AudioDeviceID) throws {
        let actual: AudioDeviceID = try get(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, initial: AudioDeviceID(kAudioObjectUnknown), operation: "入力デバイスの確認")
        guard actual == expected else { throw InputCaptureError.deviceMismatch }
    }

    private func set<Value>(
        _ unit: AudioUnit, _ property: AudioUnitPropertyID, _ scope: AudioUnitScope,
        _ element: AudioUnitElement, _ value: inout Value, operation: String
    ) throws {
        let status = withUnsafeBytes(of: &value) {
            AudioUnitSetProperty(unit, property, scope, element, $0.baseAddress, UInt32($0.count))
        }
        try check(status, operation: operation)
    }

    private func get<Value>(
        _ unit: AudioUnit, _ property: AudioUnitPropertyID, _ scope: AudioUnitScope,
        _ element: AudioUnitElement, initial: Value, operation: String
    ) throws -> Value {
        var value = initial
        var size = UInt32(MemoryLayout<Value>.size)
        let status = withUnsafeMutableBytes(of: &value) {
            AudioUnitGetProperty(unit, property, scope, element, $0.baseAddress!, &size)
        }
        try check(status, operation: operation)
        guard size == MemoryLayout<Value>.size else { throw InputCaptureError.invalidFormat }
        return value
    }

    private func check(_ status: OSStatus, operation: String) throws {
        guard status == noErr else { throw InputCaptureError.operationFailed(operation: operation, status: status) }
    }

    private func installDeviceListeners(_ deviceID: AudioDeviceID) throws {
        let generation = UUID()
        listenerGeneration = generation
        let properties: [(AudioObjectPropertySelector, AudioObjectPropertyScope)] = [
            (kAudioDevicePropertyDeviceIsAlive, kAudioObjectPropertyScopeGlobal),
            (kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal),
            (kAudioDevicePropertyStreamConfiguration, kAudioObjectPropertyScopeInput)
        ]
        for (selector, scope) in properties {
            var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                guard let self, self.listenerGeneration == generation else { return }
                self.onConfigurationChanged?()
            }
            try check(AudioObjectAddPropertyListenerBlock(deviceID, &address, .main, block), operation: "入力デバイス変更の監視")
            listeners.append((deviceID, address, block))
        }
    }

    private func removeDeviceListeners() {
        listenerGeneration = nil
        for (deviceID, savedAddress, block) in listeners {
            var address = savedAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, .main, block)
        }
        listeners.removeAll()
    }
}

private final class InputHALCallbackContext {
    weak var owner: CoreAudioInputCapture?
    init(owner: CoreAudioInputCapture) { self.owner = owner }
}

private final class InputHALBufferStorage {
    let list: UnsafeMutablePointer<AudioBufferList>
    let maximumFrames: Int
    private let allocation: UnsafeMutableRawPointer
    private var channelPointers: [UnsafeMutablePointer<Float>] = []

    init(channelCount: Int, maximumFrames: Int) {
        self.maximumFrames = maximumFrames
        let size = MemoryLayout<AudioBufferList>.size + (channelCount - 1) * MemoryLayout<AudioBuffer>.stride
        allocation = .allocate(byteCount: size, alignment: MemoryLayout<AudioBufferList>.alignment)
        list = allocation.bindMemory(to: AudioBufferList.self, capacity: 1)
        list.initialize(to: AudioBufferList())
        list.pointee.mNumberBuffers = UInt32(channelCount)
        for _ in 0..<channelCount {
            let pointer = UnsafeMutablePointer<Float>.allocate(capacity: maximumFrames)
            pointer.initialize(repeating: 0, count: maximumFrames)
            channelPointers.append(pointer)
        }
        prepare(frameCount: maximumFrames)
    }

    func prepare(frameCount: Int) {
        let buffers = UnsafeMutableAudioBufferListPointer(list)
        for (index, pointer) in channelPointers.enumerated() {
            buffers[index] = AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(frameCount * MemoryLayout<Float>.size),
                mData: UnsafeMutableRawPointer(pointer)
            )
        }
    }

    deinit {
        for pointer in channelPointers {
            pointer.deinitialize(count: maximumFrames)
            pointer.deallocate()
        }
        list.deinitialize(count: 1)
        allocation.deallocate()
    }
}
