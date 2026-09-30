import Combine
import CoreAudio
import Foundation

@MainActor
final class AudioOutputRouteModel:
    ObservableObject {

    @Published private(set)
    var isBluetooth = false

    private var timer: Timer?

    init() {
        refresh()

        timer =
            Timer.scheduledTimer(
                withTimeInterval: 2,
                repeats: true
            ) {
                [weak self]
                _ in

                Task {
                    @MainActor in
                    self?.refresh()
                }
            }
    }

    func refresh() {
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

        var address =
            AudioObjectPropertyAddress(
                mSelector:
                    kAudioHardwarePropertyDefaultOutputDevice,
                mScope:
                    kAudioObjectPropertyScopeGlobal,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        let system =
            AudioObjectID(
                kAudioObjectSystemObject
            )

        guard
            AudioObjectGetPropertyData(
                system,
                &address,
                0,
                nil,
                &size,
                &deviceID
            ) == noErr,
            deviceID !=
                kAudioObjectUnknown
        else {
            isBluetooth = false
            return
        }

        var transport:
            UInt32 = 0

        size =
            UInt32(
                MemoryLayout<
                    UInt32
                >.size
            )

        address =
            AudioObjectPropertyAddress(
                mSelector:
                    kAudioDevicePropertyTransportType,
                mScope:
                    kAudioObjectPropertyScopeGlobal,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        guard
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &size,
                &transport
            ) == noErr
        else {
            isBluetooth = false
            return
        }

        isBluetooth =
            transport ==
                kAudioDeviceTransportTypeBluetooth ||
            transport ==
                kAudioDeviceTransportTypeBluetoothLE
    }

    deinit {
        timer?.invalidate()
    }
}
