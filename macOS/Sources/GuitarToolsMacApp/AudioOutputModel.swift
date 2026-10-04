import Combine
import CoreAudio
import Foundation

@MainActor
protocol ReferenceTonePlaying: AnyObject {
    /// Nil on normal completion; a visible explanation when playback must stop.
    var onPlaybackEnded: ((String?) -> Void)? { get set }
    func play(frequency: Double, outputDeviceID: AudioDeviceID) throws
    func stop()
}

@MainActor
final class AudioOutputModel: ObservableObject {
    @Published private(set) var devices: [CoreAudioOutputDevice] = []
    @Published private(set) var selectedDeviceUID: String?
    @Published private(set) var isPlaying = false
    @Published var errorMessage: String?

    var selectedDevice: CoreAudioOutputDevice? {
        guard let selectedDeviceUID else { return nil }
        return devices.first { $0.uid == selectedDeviceUID }
    }

    var selectedDeviceUnavailable: Bool {
        selectedDeviceUID != nil && selectedDevice == nil
    }

    private let preferencesStore: AppPreferencesStore
    private let catalog: any AudioOutputDeviceCatalog
    private let playerFactory: @MainActor () -> any ReferenceTonePlaying
    // Creating an output engine is deferred until the first valid play request.
    private var referencePlayer: (any ReferenceTonePlaying)?
    private var activeDevice: CoreAudioOutputDevice?
    private var playbackGeneration: UInt64 = 0
    private static let unavailableMessage = "選択した音声出力が見つかりません。基準音を停止しました。別の出力には切り替えません。再接続するか、出力を選び直してください。"

    init(
        preferencesStore: AppPreferencesStore,
        catalog: any AudioOutputDeviceCatalog = CoreAudioOutputDeviceCatalog(),
        playerFactory: @escaping @MainActor () -> any ReferenceTonePlaying = { ReferenceTonePlayer() }
    ) {
        self.preferencesStore = preferencesStore
        self.catalog = catalog
        self.playerFactory = playerFactory
        selectedDeviceUID = preferencesStore.value.audio.outputDeviceUID
        catalog.onDevicesChanged = { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshOutputDevices()
            }
        }
        refreshOutputDevices()
    }

    func selectOutputDevice(uid: String?) {
        guard selectedDeviceUID != uid else { return }
        stopReference()
        selectedDeviceUID = uid
        preferencesStore.update { $0.audio.outputDeviceUID = uid }
        errorMessage = nil
        refreshOutputDevices()
    }

    func refreshOutputDevices() {
        do {
            devices = try catalog.outputDevices()
            if selectedDeviceUnavailable {
                stopReference()
                errorMessage = Self.unavailableMessage
                return
            }
            if let activeDevice {
                let current = devices.first { $0.uid == activeDevice.uid }
                let defaultChanged = try selectedDeviceUID == nil && catalog.defaultOutputDeviceID() != activeDevice.id
                if current != activeDevice || defaultChanged {
                    stopReference()
                    errorMessage = "音声出力が変わったため基準音を停止しました。もう一度再生してください。"
                }
            }
            if errorMessage == Self.unavailableMessage {
                errorMessage = nil
            }
        } catch {
            // A failed enumeration is not evidence that the saved output is safe to use.
            devices = []
            stopReference()
            errorMessage = "音声出力を更新できません：\(Self.errorDetail(error))。基準音を停止しました。別の出力には切り替えません。"
        }
    }

    func playReference(frequency: Double) {
        stopReference()
        guard frequency.isFinite, (20.0...4_000.0).contains(frequency) else {
            errorMessage = "基準音の周波数は20〜4,000 Hzの有限の値で指定してください。"
            return
        }
        do {
            // Resolve stable UID (or today's system default) immediately before playback.
            devices = try catalog.outputDevices()
            let device: CoreAudioOutputDevice
            if selectedDeviceUID != nil {
                guard let selectedDevice else {
                    errorMessage = Self.unavailableMessage
                    return
                }
                device = selectedDevice
            } else {
                guard let id = try catalog.defaultOutputDeviceID(),
                      let output = devices.first(where: { $0.id == id }) else {
                    errorMessage = "システム標準の音声出力が見つかりません。基準音は再生していません。"
                    return
                }
                device = output
            }
            if referencePlayer == nil { referencePlayer = playerFactory() }
            guard let referencePlayer else { return }
            let generation = playbackGeneration
            referencePlayer.onPlaybackEnded = { [weak self] message in
                guard let self, self.playbackGeneration == generation else { return }
                self.stopReference()
                if let message { self.errorMessage = message }
            }
            activeDevice = device
            isPlaying = true
            errorMessage = nil
            try referencePlayer.play(frequency: frequency, outputDeviceID: device.id)
        } catch {
            stopReference()
            errorMessage = "基準音を再生できません：\(Self.errorDetail(error))。別の出力には切り替えません。"
        }
    }

    private static func errorDetail(_ error: Error) -> String {
        if let catalogError = error as? CoreAudioCatalogError {
            switch catalogError {
            case .operationFailed(_, let status):
                return "CoreAudioエラー（OSStatus \(status)）"
            }
        }
        return error.localizedDescription
    }

    func stopReference() {
        playbackGeneration &+= 1
        referencePlayer?.stop()
        activeDevice = nil
        isPlaying = false
    }
}
