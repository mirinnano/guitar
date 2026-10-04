import SwiftUI

/// Route selection is explicit: changing this section never changes the macOS default output.
struct AudioRoutingSection: View {
    @ObservedObject var audio: AudioInputModel
    @ObservedObject var output: AudioOutputModel

    var body: some View {
        MacSection("ギターの入力・基準音の出力", subtitle: "USBオーディオインターフェースで練習") {
            VStack(alignment: .leading, spacing: 12) {
                AudioInputDevicePicker(audio: audio)
                Divider()
                Picker("基準音の出力先", selection: Binding(
                    get: { output.selectedDeviceUID },
                    set: { output.selectOutputDevice(uid: $0) }
                )) {
                    Text("システムのデフォルト").tag(Optional<String>.none)
                    if output.selectedDeviceUnavailable, let uid = output.selectedDeviceUID {
                        Text("未接続の出力（再選択してください）").tag(Optional(uid))
                    }
                    ForEach(output.devices) { device in
                        Text(device.name).tag(Optional(device.uid))
                    }
                }
                HStack {
                    Text("この設定はチューナーの基準音だけに適用します。動画やメトロノームの出力先は変わりません。")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    if output.isPlaying {
                        Button("基準音を停止", systemImage: "stop.fill") { output.stopReference() }
                    }
                    Button("出力を更新", systemImage: "arrow.clockwise") { output.refreshOutputDevices() }
                        .labelStyle(.iconOnly).help("基準音の出力デバイス一覧を更新")
                }
                if let error = output.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.orange)
                }
                ur12Setup
            }
        }
    }

    private var ur12Setup: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Steinberg UR12", systemImage: "cable.connector")
                    .font(.headline)
                Spacer()
                if let route = UR12RoutingProfile.configuration(
                    inputs: audio.inputDevices, outputs: output.devices,
                    preferredInputUID: audio.selectedDeviceUID
                ) {
                    Button("UR12のギター入出力を設定") {
                        audio.configureInput(uid: route.inputUID, channel: 1)
                        output.selectOutputDevice(uid: route.outputUID)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("未接続、または入出力を個別に選択してください")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("ギター → INPUT 2（HI-Z）／GAIN 2で音量調整。基準音 → PHONESまたはLINE OUTPUT。両方の音量は本体のOUTPUTつまみで調整します。ヘッドホンだけを別の出力としては選べません。")
                .font(.caption).foregroundStyle(.secondary)
            Text("自分のギター音も聴くには本体のDIRECT MONITORを使用してください。このアプリは入力音を解析し、ソフトウェアでの生音モニターは行いません。基準音は小さな音量から確認しましょう。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .macContentSurface(radius: 12)
    }
}
