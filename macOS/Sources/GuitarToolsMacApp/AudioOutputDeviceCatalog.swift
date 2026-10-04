import AudioToolbox
import CoreAudio
import Foundation

/// A hardware output endpoint, not an independently selectable headphone jack.
/// UR12 PHONES and LINE OUTPUT share the same stereo output and OUTPUT control.
struct CoreAudioOutputDevice: Identifiable, Equatable, Sendable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let channelCount: Int
    let sampleRate: Double
}

protocol AudioOutputDeviceCatalog: AnyObject {
    var onDevicesChanged: (() -> Void)? { get set }
    func outputDevices() throws -> [CoreAudioOutputDevice]
    func defaultOutputDeviceID() throws -> AudioDeviceID?
}

/// Output-only catalog. Deliberately independent of the input catalog and its listeners.
final class CoreAudioOutputDeviceCatalog: AudioOutputDeviceCatalog {
    var onDevicesChanged: (() -> Void)?

    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private let listenerQueue = DispatchQueue.main
    private var listeners: [(AudioObjectPropertySelector, AudioObjectPropertyListenerBlock)] = []
    private var listenerError: Error?

    init() {
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice] {
            var address = Self.address(selector)
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                self?.onDevicesChanged?()
            }
            let status = AudioObjectAddPropertyListenerBlock(systemObject, &address, listenerQueue, block)
            if status == noErr {
                listeners.append((selector, block))
            } else {
                // Do not play an unmonitored route if disconnect/default-change monitoring failed.
                listenerError = CoreAudioCatalogError.operationFailed(operation: "Monitor audio output changes", status: status)
            }
        }
    }

    deinit {
        for (selector, block) in listeners {
            var address = Self.address(selector)
            AudioObjectRemovePropertyListenerBlock(systemObject, &address, listenerQueue, block)
        }
    }

    func outputDevices() throws -> [CoreAudioOutputDevice] {
        if let listenerError { throw listenerError }
        var address = Self.address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size), "Read output device list size")
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: kAudioObjectUnknown, count: count)
        try check(AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &ids), "Read output device list")

        return try ids.compactMap { id in
            let channels = try outputChannelCount(id)
            guard channels > 0,
                  try readUInt32(id, kAudioDevicePropertyDeviceIsAlive, fallback: 1) != 0,
                  try readUInt32(id, kAudioDevicePropertyIsHidden, fallback: 0) == 0,
                  let uid = try readString(id, kAudioDevicePropertyDeviceUID),
                  let name = try readString(id, kAudioObjectPropertyName)
            else { return nil }
            var rate = Float64(0)
            var rateSize = UInt32(MemoryLayout<Float64>.size)
            var rateAddress = Self.address(kAudioDevicePropertyNominalSampleRate)
            try check(AudioObjectGetPropertyData(id, &rateAddress, 0, nil, &rateSize, &rate), "Read output sample rate")
            return CoreAudioOutputDevice(id: id, uid: uid, name: name, channelCount: channels, sampleRate: rate)
        }.sorted {
            let order = $0.name.localizedCaseInsensitiveCompare($1.name)
            return order == .orderedSame ? $0.uid < $1.uid : order == .orderedAscending
        }
    }

    func defaultOutputDeviceID() throws -> AudioDeviceID? {
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        try check(AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &id), "Read default output device")
        return id == kAudioObjectUnknown ? nil : id
    }

    private func outputChannelCount(_ id: AudioDeviceID) throws -> Int {
        var address = Self.address(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size), "Read output stream configuration size")
        guard size >= MemoryLayout<AudioBufferList>.size else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        try check(AudioObjectGetPropertyData(id, &address, 0, nil, &size, list), "Read output stream configuration")
        return UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private func readUInt32(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, fallback: UInt32) throws -> UInt32 {
        var address = Self.address(selector)
        guard AudioObjectHasProperty(id, &address) else { return fallback }
        var value = fallback
        var size = UInt32(MemoryLayout<UInt32>.size)
        try check(AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value), "Read output device property")
        return value
    }

    private func readString(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> String? {
        var address = Self.address(selector)
        guard AudioObjectHasProperty(id, &address) else { return nil }
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check(AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value), "Read output device name/UID")
        return value?.takeUnretainedValue() as String?
    }

    private static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            throw CoreAudioCatalogError.operationFailed(operation: operation, status: status)
        }
    }
}
