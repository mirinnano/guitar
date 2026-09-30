import SwiftUI

struct AudioInputDevicePicker:
    View {

    @ObservedObject
    var audio: AudioInputModel

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Picker(
                "Input Device",
                selection:
                    Binding(
                        get: {
                            audio
                                .selectedDeviceUID
                        },
                        set: {
                            audio
                                .selectInputDevice(
                                    uid: $0
                                )
                        }
                    )
            ) {
                Text("System Default")
                    .tag(
                        Optional<String>
                            .none
                    )

                ForEach(
                    audio.inputDevices
                ) {
                    device in

                    Text(device.name)
                        .tag(
                            Optional(
                                device.uid
                            )
                        )
                }
            }

            if audio
                .selectedDeviceUnavailable {
                Label(
                    "選択した入力デバイスが接続されていません",
                    systemImage:
                        "cable.connector.slash"
                )
                .font(.caption)
                .foregroundStyle(
                    .orange
                )
            }

            if audio.availableChannels >
                0 {
                Picker(
                    "Input Channel",
                    selection:
                        Binding(
                            get: {
                                audio
                                    .selectedChannel
                            },
                            set: {
                                audio
                                    .selectInputChannel(
                                        $0
                                    )
                            }
                        )
                ) {
                    ForEach(
                        0..<audio
                            .availableChannels,
                        id: \.self
                    ) {
                        index in

                        Text(
                            "Ch \(index + 1)"
                        )
                        .tag(index)
                    }
                }
            }

            HStack(
                spacing: 8
            ) {
                if audio.sampleRate > 0 {
                    MacStatusPill(
                        text:
                            String(
                                format:
                                    "%.1f kHz",
                                audio
                                    .sampleRate /
                                1_000
                            ),
                        systemImage:
                            "waveform",
                        role: .neutral
                    )
                }

                if audio
                    .hardwareInputLatencyMs >
                    0 {
                    MacStatusPill(
                        text:
                            String(
                                format:
                                    "~%.1f ms input",
                                audio
                                    .hardwareInputLatencyMs
                            ),
                        systemImage:
                            "timer",
                        role: .neutral
                    )
                }

                Spacer()

                Button {
                    audio
                        .refreshInputDevices()
                } label: {
                    Label(
                        "再スキャン",
                        systemImage:
                            "arrow.clockwise"
                    )
                }
                .controlSize(.small)
            }
        }
    }
}
