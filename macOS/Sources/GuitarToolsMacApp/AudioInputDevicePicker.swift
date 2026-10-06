import SwiftUI

struct AudioInputDevicePicker: View {
    @ObservedObject var audio: AudioInputModel

    private var isUR12: Bool {
        UR12RoutingProfile.isUR12(name: audio.selectedDevice?.name ?? audio.inputLabel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("入力デバイス", selection: Binding(
                get: { audio.selectedDeviceUID },
                set: { audio.selectInputDevice(uid: $0) }
            )) {
                Text("システムのデフォルト").tag(Optional<String>.none)
                if audio.selectedDeviceUnavailable, let uid = audio.selectedDeviceUID {
                    Text(audio.isStartRequested ? "未接続の入力（再接続を待機）" : "未接続の入力")
                        .tag(Optional(uid))
                }
                ForEach(audio.inputDevices) { device in
                    Text(device.name).tag(Optional(device.uid))
                }
            }
            if audio.selectedDeviceUnavailable {
                Label("選択した入力が未接続です。別の機器やCh 1には切り替えません。",
                      systemImage: "cable.connector.slash")
                    .font(.caption).foregroundStyle(.orange)
            }
            if audio.availableChannels > 0 {
                Picker("チャンネル", selection: Binding(
                    get: { audio.selectedChannel },
                    set: { audio.selectInputChannel($0) }
                )) {
                    if audio.selectedChannel >= audio.availableChannels {
                        Text("Ch \(audio.selectedChannel + 1)（この機器では使用不可）")
                            .tag(audio.selectedChannel)
                    }
                    ForEach(0..<audio.availableChannels, id: \.self) { index in
                        Text(channelLabel(index)).tag(index)
                    }
                }
            }
            if isUR12 && audio.selectedChannel == 0 {
                HStack(alignment: .top) {
                    Label("Ch 1はMIC入力です。ギターをINPUT 2に接続したらCh 2（HI-Z）を選んでください。",
                          systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.orange)
                    Spacer(minLength: 8)
                    Button("ギター用Ch 2へ") {
                        audio.configureInput(uid: audio.selectedDeviceUID, channel: 1)
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }
            }
            if audio.isStartRequested && !audio.isRunning {
                HStack {
                    Label("入力開始を待機中", systemImage: "hourglass")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button("開始をキャンセル", systemImage: "xmark.circle") { audio.toggle() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
            HStack(spacing: 8) {
                if audio.sampleRate > 0 {
                    MacStatusPill(text: String(format: "%.1f kHz", audio.sampleRate / 1_000),
                                  systemImage: "waveform", role: .neutral)
                }
                if audio.hardwareInputLatencyMs > 0 {
                    MacStatusPill(text: String(format: "入力 ~%.1f ms", audio.hardwareInputLatencyMs),
                                  systemImage: "timer", role: .neutral)
                }
                Spacer()
                Button("更新", systemImage: "arrow.clockwise") { audio.refreshInputDevices() }
                    .controlSize(.small).labelStyle(.iconOnly).help("入力デバイス一覧を更新")
            }
            if audio.isRunning {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(audio.channelLevelsDBFS.enumerated()), id: \.offset) { index, level in
                        HStack(spacing: 10) {
                            Text(channelLabel(index))
                                .font(.caption.weight(index == audio.selectedChannel ? .semibold : .regular))
                                .frame(width: 108, alignment: .leading)
                            ProgressView(value: min(60, max(0, level + 60)), total: 60)
                                .tint(index == audio.selectedChannel ? .accentColor : .secondary)
                                .accessibilityLabel(channelLabel(index) + "の入力音量")
                                .accessibilityValue(String(format: "%.0f dBFS", level))
                            Text(String(format: "%.0f dBFS", level))
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .trailing)
                        }
                    }
                    Text(audio.receivedFrameCount > 0
                         ? "PCM受信：\(audio.receivedFrameCount.formatted())フレーム"
                         : "PCM入力を待っています")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            if let message = audio.inputHealthMessage {
                Label(message, systemImage: "waveform.badge.exclamationmark")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private func channelLabel(_ index: Int) -> String {
        UR12RoutingProfile.channelLabel(index: index,
                                        deviceName: audio.selectedDevice?.name ?? audio.inputLabel)
    }
}
