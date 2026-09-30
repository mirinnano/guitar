import GuitarToolsCore
import SwiftUI

struct ChordDetectionView: View {

    @ObservedObject
    var audio: AudioInputModel

    private let noteColumns =
        Array(
            repeating:
                GridItem(
                    .flexible(),
                    spacing: 10
                ),
            count: 6
        )

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 20
            ) {
                MacPageHeader(
                    "コード判定",
                    subtitle:
                        "オーディオインターフェース入力から現在のコードをリアルタイム推定"
                ) {
                    MacStatusPill(
                        text:
                            audio.isRunning
                            ? "Listening"
                            : "Input Off",
                        systemImage:
                            audio.isRunning
                            ? "waveform"
                            : "waveform.slash",
                        role:
                            audio.isRunning
                            ? .success
                            : .neutral
                    )
                }

                detectionHero

                HStack(
                    alignment: .top,
                    spacing: 16
                ) {
                    inputSection
                        .frame(
                            maxWidth: 380
                        )

                    pitchClassSection
                        .frame(
                            maxWidth: .infinity
                        )
                }

                MacSection(
                    "判定について"
                ) {
                    Text(
                        "Major / minor / 5 / 7 / maj7 / m7 / dim / aug / sus2 / sus4 を対象に、12音のエネルギー分布とコードテンプレートを照合します。表示は複数フレームの多数決で安定化します。Direct MonitorやアンプシムはオーディオIFまたはDAW側を使用し、この画面は解析だけを行います。"
                    )
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }
            }
            .padding(26)
            .macPageWidth(1_080)
        }
        .navigationTitle(
            "コード判定"
        )
        .toolbar {
            ToolbarItem(
                placement:
                    .primaryAction
            ) {
                Button {
                    audio.toggle()
                } label: {
                    Label(
                        audio.isRunning
                        ? "入力停止"
                        : "入力開始",
                        systemImage:
                            audio.isRunning
                            ? "waveform.slash"
                            : "waveform"
                    )
                }
            }
        }
    }

    private var detectionHero:
        some View {

        HStack(
            alignment: .center,
            spacing: 32
        ) {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(
                    audio.stableChord
                    ?? audio.estimate?.name
                    ?? "—"
                )
                .font(
                    .system(
                        size: 76,
                        weight: .semibold,
                        design: .rounded
                    )
                )

                Text(detectionStateText)
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()

            VStack(
                alignment: .trailing,
                spacing: 8
            ) {
                Text("Confidence")
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                Text(confidenceText)
                    .font(
                        .title
                            .weight(.semibold)
                            .monospacedDigit()
                    )

                ProgressView(
                    value:
                        audio.estimate?
                            .confidence
                        ?? 0
                )
                .frame(
                    width: 220
                )
            }
        }
        .padding(24)
        .background(
            .quaternary.opacity(0.18),
            in:
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
        )
    }

    private var inputSection:
        some View {

        MacSection(
            "Audio Input",
            subtitle:
                "入力ソースとレベル"
        ) {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                LabeledContent(
                    "Device"
                ) {
                    Text(
                        audio.inputLabel
                    )
                    .lineLimit(1)
                }

                if audio.sampleRate > 0 {
                    LabeledContent(
                        "Format"
                    ) {
                        Text(
                            "\(Int(audio.sampleRate)) Hz · \(audio.availableChannels) ch"
                        )
                        .monospacedDigit()
                    }
                }

                if audio.availableChannels >
                    1 {
                    Picker(
                        "Channel",
                        selection:
                            $audio.selectedChannel
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
                    .pickerStyle(
                        .segmented
                    )
                    .disabled(
                        audio.isRunning
                    )
                }

                MacAudioLevelMeter(
                    levelDBFS:
                        audio.levelDBFS,
                    clipping:
                        audio.clipping
                )

                if let error =
                    audio.errorMessage {
                    Label(
                        error,
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .red
                    )
                }
            }
        }
    }

    private var pitchClassSection:
        some View {

        MacSection(
            "Pitch Classes",
            subtitle:
                "現在の12音エネルギー"
        ) {
            LazyVGrid(
                columns: noteColumns,
                spacing: 14
            ) {
                ForEach(
                    PitchClass.allCases
                ) {
                    pitchClass in

                    ChromaCell(
                        pitchClass:
                            pitchClass,
                        value:
                            chromaValue(
                                pitchClass
                            )
                    )
                }
            }
        }
    }

    private var detectionStateText:
        String {
        if !audio.isRunning {
            return "入力停止中"
        }

        if audio.stableChord != nil {
            return "安定判定"
        }

        if audio.estimate != nil {
            return "判定安定化中"
        }

        return "演奏待ち"
    }

    private var confidenceText:
        String {
        let value =
            (
                audio.estimate?
                    .confidence
                ?? 0
            ) * 100

        return String(
            format: "%.0f%%",
            value
        )
    }

    private func chromaValue(
        _ pitchClass:
            PitchClass
    ) -> Double {
        guard
            let chroma =
                audio.estimate?.chroma,
            pitchClass.rawValue <
                chroma.count
        else {
            return 0
        }

        let peak =
            chroma.max() ?? 0

        guard peak > 0 else {
            return 0
        }

        return min(
            chroma[
                pitchClass.rawValue
            ] / peak,
            1
        )
    }
}

private struct ChromaCell: View {

    let pitchClass: PitchClass
    let value: Double

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            HStack {
                Text(
                    pitchClass
                        .displayName
                )
                .fontWeight(
                    .semibold
                )

                Spacer()

                Text(
                    String(
                        format: "%.0f",
                        value * 100
                    )
                )
                .font(
                    .caption
                        .monospacedDigit()
                )
                .foregroundStyle(
                    .secondary
                )
            }

            ProgressView(
                value: value
            )
        }
        .padding(10)
        .background(
            Color.secondary.opacity(0.05),
            in:
                RoundedRectangle(
                    cornerRadius: 9,
                    style: .continuous
                )
        )
    }
}
