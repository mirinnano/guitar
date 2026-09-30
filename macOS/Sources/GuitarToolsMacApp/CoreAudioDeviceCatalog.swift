import AudioToolbox
import CoreAudio
import Foundation

struct CoreAudioInputDevice:
    Identifiable,
    Equatable,
    Sendable {

    let id: AudioDeviceID
    let uid: String
    let name: String
    let channelCount: Int
    let sampleRate: Double
    let deviceLatencyFrames: UInt32
    let safetyOffsetFrames: UInt32
    let bufferFrameSize: UInt32

    var estimatedInputLatencySeconds:
        Double {
        guard sampleRate > 0
        else {
            return 0
        }

        return Double(
            deviceLatencyFrames +
            safetyOffsetFrames +
            bufferFrameSize
        ) /
        sampleRate
    }

    var estimatedInputLatencyMs:
        Double {
        estimatedInputLatencySeconds *
        1_000
    }
}

final class CoreAudioDeviceCatalog {

    var onDevicesChanged:
        (() -> Void)?

    private let systemObject =
        AudioObjectID(
            kAudioObjectSystemObject
        )

    private let listenerQueue =
        DispatchQueue.main

    private var devicesListener:
        AudioObjectPropertyListenerBlock?

    private var defaultInputListener:
        AudioObjectPropertyListenerBlock?

    init() {
        installListeners()
    }

    deinit {
        removeListeners()
    }

    func inputDevices()
        throws
        -> [CoreAudioInputDevice] {

        let deviceIDs =
            try allDeviceIDs()

        return try deviceIDs
            .compactMap {
                deviceID
                -> CoreAudioInputDevice? in

                let channels =
                    try inputChannelCount(
                        deviceID:
                            deviceID
                    )

                guard channels > 0
                else {
                    return nil
                }

                if
                    try readUInt32(
                        objectID:
                            deviceID,
                        selector:
                            kAudioDevicePropertyDeviceIsAlive,
                        scope:
                            kAudioObjectPropertyScopeGlobal,
                        defaultValue: 1
                    ) == 0 {
                    return nil
                }

                if
                    try readUInt32(
                        objectID:
                            deviceID,
                        selector:
                            kAudioDevicePropertyIsHidden,
                        scope:
                            kAudioObjectPropertyScopeGlobal,
                        defaultValue: 0
                    ) != 0 {
                    return nil
                }

                guard
                    let uid =
                        try readString(
                            objectID:
                                deviceID,
                            selector:
                                kAudioDevicePropertyDeviceUID,
                            scope:
                                kAudioObjectPropertyScopeGlobal
                        ),
                    let name =
                        try readString(
                            objectID:
                                deviceID,
                            selector:
                                kAudioObjectPropertyName,
                            scope:
                                kAudioObjectPropertyScopeGlobal
                        )
                else {
                    return nil
                }

                let sampleRate =
                    try readFloat64(
                        objectID:
                            deviceID,
                        selector:
                            kAudioDevicePropertyNominalSampleRate,
                        scope:
                            kAudioObjectPropertyScopeGlobal,
                        defaultValue: 0
                    )

                let latency =
                    try readUInt32(
                        objectID:
                            deviceID,
                        selector:
                            kAudioDevicePropertyLatency,
                        scope:
                            kAudioObjectPropertyScopeInput,
                        defaultValue: 0
                    )

                let safety =
                    try readUInt32(
                        objectID:
                            deviceID,
                        selector:
                            kAudioDevicePropertySafetyOffset,
                        scope:
                            kAudioObjectPropertyScopeInput,
                        defaultValue: 0
                    )

                let buffer =
                    try readUInt32(
                        objectID:
                            deviceID,
                        selector:
                            kAudioDevicePropertyBufferFrameSize,
                        scope:
                            kAudioObjectPropertyScopeGlobal,
                        defaultValue: 0
                    )

                return CoreAudioInputDevice(
                    id: deviceID,
                    uid: uid,
                    name: name,
                    channelCount:
                        channels,
                    sampleRate:
                        sampleRate,
                    deviceLatencyFrames:
                        latency,
                    safetyOffsetFrames:
                        safety,
                    bufferFrameSize:
                        buffer
                )
            }
            .sorted {
                lhs,
                rhs in

                lhs.name
                    .localizedCaseInsensitiveCompare(
                        rhs.name
                    ) ==
                    .orderedAscending
            }
    }

    func defaultInputDeviceID()
        throws
        -> AudioDeviceID? {

        var address =
            AudioObjectPropertyAddress(
                mSelector:
                    kAudioHardwarePropertyDefaultInputDevice,
                mScope:
                    kAudioObjectPropertyScopeGlobal,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        var deviceID =
            AudioDeviceID(
                kAudioObjectUnknown
            )

        var size =
            UInt32(
                MemoryLayout<
                    AudioDeviceID
                >.size
            )

        let status =
            AudioObjectGetPropertyData(
                systemObject,
                &address,
                0,
                nil,
                &size,
                &deviceID
            )

        try check(
            status,
            operation:
                "Read default input device"
        )

        return deviceID ==
            kAudioObjectUnknown
        ? nil
        : deviceID
    }

    func deviceID(
        forUID uid: String
    ) throws
        -> AudioDeviceID? {

        try inputDevices()
            .first {
                $0.uid == uid
            }?
            .id
    }

    private func allDeviceIDs()
        throws
        -> [AudioDeviceID] {

        var address =
            AudioObjectPropertyAddress(
                mSelector:
                    kAudioHardwarePropertyDevices,
                mScope:
                    kAudioObjectPropertyScopeGlobal,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        var size: UInt32 = 0

        var status =
            AudioObjectGetPropertyDataSize(
                systemObject,
                &address,
                0,
                nil,
                &size
            )

        try check(
            status,
            operation:
                "Read audio device list size"
        )

        let count =
            Int(size) /
            MemoryLayout<
                AudioDeviceID
            >.size

        guard count > 0
        else {
            return []
        }

        var values =
            Array(
                repeating:
                    AudioDeviceID(
                        kAudioObjectUnknown
                    ),
                count: count
            )

        status =
            AudioObjectGetPropertyData(
                systemObject,
                &address,
                0,
                nil,
                &size,
                &values
            )

        try check(
            status,
            operation:
                "Read audio device list"
        )

        return values
    }

    private func inputChannelCount(
        deviceID:
            AudioDeviceID
    ) throws -> Int {

        var address =
            AudioObjectPropertyAddress(
                mSelector:
                    kAudioDevicePropertyStreamConfiguration,
                mScope:
                    kAudioObjectPropertyScopeInput,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        var size: UInt32 = 0

        var status =
            AudioObjectGetPropertyDataSize(
                deviceID,
                &address,
                0,
                nil,
                &size
            )

        try check(
            status,
            operation:
                "Read input stream configuration size"
        )

        guard size >=
            MemoryLayout<
                AudioBufferList
            >.size
        else {
            return 0
        }

        let raw =
            UnsafeMutableRawPointer
                .allocate(
                    byteCount:
                        Int(size),
                    alignment:
                        MemoryLayout<
                            AudioBufferList
                        >.alignment
                )

        defer {
            raw.deallocate()
        }

        let list =
            raw.bindMemory(
                to:
                    AudioBufferList.self,
                capacity: 1
            )

        status =
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &size,
                list
            )

        try check(
            status,
            operation:
                "Read input stream configuration"
        )

        return UnsafeMutableAudioBufferListPointer(
            list
        )
        .reduce(0) {
            $0 +
            Int(
                $1.mNumberChannels
            )
        }
    }

    private func readUInt32(
        objectID: AudioObjectID,
        selector:
            AudioObjectPropertySelector,
        scope:
            AudioObjectPropertyScope,
        defaultValue: UInt32
    ) throws -> UInt32 {
        var address =
            AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: scope,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        guard AudioObjectHasProperty(
            objectID,
            &address
        )
        else {
            return defaultValue
        }

        var value =
            defaultValue

        var size =
            UInt32(
                MemoryLayout<
                    UInt32
                >.size
            )

        let status =
            AudioObjectGetPropertyData(
                objectID,
                &address,
                0,
                nil,
                &size,
                &value
            )

        try check(
            status,
            operation:
                "Read CoreAudio UInt32 property"
        )

        return value
    }

    private func readFloat64(
        objectID: AudioObjectID,
        selector:
            AudioObjectPropertySelector,
        scope:
            AudioObjectPropertyScope,
        defaultValue: Float64
    ) throws -> Float64 {
        var address =
            AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: scope,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        guard AudioObjectHasProperty(
            objectID,
            &address
        )
        else {
            return defaultValue
        }

        var value =
            defaultValue

        var size =
            UInt32(
                MemoryLayout<
                    Float64
                >.size
            )

        let status =
            AudioObjectGetPropertyData(
                objectID,
                &address,
                0,
                nil,
                &size,
                &value
            )

        try check(
            status,
            operation:
                "Read CoreAudio Float64 property"
        )

        return value
    }

    private func readString(
        objectID: AudioObjectID,
        selector:
            AudioObjectPropertySelector,
        scope:
            AudioObjectPropertyScope
    ) throws -> String? {
        var address =
            AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: scope,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        guard AudioObjectHasProperty(
            objectID,
            &address
        )
        else {
            return nil
        }

        var value:
            CFString =
            "" as CFString

        var size =
            UInt32(
                MemoryLayout<
                    CFString
                >.size
            )

        let status =
            AudioObjectGetPropertyData(
                objectID,
                &address,
                0,
                nil,
                &size,
                &value
            )

        try check(
            status,
            operation:
                "Read CoreAudio string property"
        )

        return value as String
    }

    private func installListeners() {
        var devicesAddress =
            AudioObjectPropertyAddress(
                mSelector:
                    kAudioHardwarePropertyDevices,
                mScope:
                    kAudioObjectPropertyScopeGlobal,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        let devicesBlock:
            AudioObjectPropertyListenerBlock = {
                [weak self]
                _,
                _ in

                self?
                    .onDevicesChanged?()
            }

        if AudioObjectAddPropertyListenerBlock(
            systemObject,
            &devicesAddress,
            listenerQueue,
            devicesBlock
        ) == noErr {
            devicesListener =
                devicesBlock
        }

        var defaultAddress =
            AudioObjectPropertyAddress(
                mSelector:
                    kAudioHardwarePropertyDefaultInputDevice,
                mScope:
                    kAudioObjectPropertyScopeGlobal,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        let defaultBlock:
            AudioObjectPropertyListenerBlock = {
                [weak self]
                _,
                _ in

                self?
                    .onDevicesChanged?()
            }

        if AudioObjectAddPropertyListenerBlock(
            systemObject,
            &defaultAddress,
            listenerQueue,
            defaultBlock
        ) == noErr {
            defaultInputListener =
                defaultBlock
        }
    }

    private func removeListeners() {
        if let devicesListener {
            var address =
                AudioObjectPropertyAddress(
                    mSelector:
                        kAudioHardwarePropertyDevices,
                    mScope:
                        kAudioObjectPropertyScopeGlobal,
                    mElement:
                        kAudioObjectPropertyElementMain
                )

            AudioObjectRemovePropertyListenerBlock(
                systemObject,
                &address,
                listenerQueue,
                devicesListener
            )
        }

        if let defaultInputListener {
            var address =
                AudioObjectPropertyAddress(
                    mSelector:
                        kAudioHardwarePropertyDefaultInputDevice,
                    mScope:
                        kAudioObjectPropertyScopeGlobal,
                    mElement:
                        kAudioObjectPropertyElementMain
                )

            AudioObjectRemovePropertyListenerBlock(
                systemObject,
                &address,
                listenerQueue,
                defaultInputListener
            )
        }
    }

    private func check(
        _ status: OSStatus,
        operation: String
    ) throws {
        guard status == noErr
        else {
            throw CoreAudioCatalogError
                .operationFailed(
                    operation:
                        operation,
                    status:
                        status
                )
        }
    }
}

enum CoreAudioCatalogError:
    LocalizedError {

    case operationFailed(
        operation: String,
        status: OSStatus
    )

    var errorDescription:
        String? {
        switch self {
        case let .operationFailed(
            operation,
            status
        ):
            "\(operation) failed (OSStatus \(status))"
        }
    }
}
