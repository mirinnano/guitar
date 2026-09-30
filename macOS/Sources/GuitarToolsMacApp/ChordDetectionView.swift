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
                    spacing: 8
                ),
            count: 6
        )

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 20
            ) {
                header
                inputCard
                detectedChordCard
                chromaCard
                scopeNote
            }
            .padding(24)
            .frame(
                maxWidth: 980,
                alignment: .leading
            )
        }
        .navigationTitle(
            "コード判定"
        )
    }

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text(
                "Live Chord Detection"
            )
            .font(
                .system(
                    size: 28,
                    weight: .semibold
                )
            )

            Text(
                "オーディオインターフェースからギターを入力し、現在鳴っているコードをリアルタイム判定します。録音やエフェクト処理は行いません。"
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    private var inputCard: some View {
        GroupBox(
            "Audio Input"
        ) {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                HStack(
                    spacing: 12
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text(
                            audio.inputLabel
                        )
                        .font(.headline)

                        if audio.sampleRate > 0 {
                            Text(
                                "(Int(audio.sampleRate)) Hz · (audio.availableChannels) ch"
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        } else {
                            Text(
                                "オーディオIFをmacOSの入力デバイスに選択してから開始してください。"
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }

                    Spacer()

                    Button(
                        audio.isRunning
                        ? "停止"
                        : "入力開始"
                    ) {
                        audio.toggle()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }

                if audio.availableChannels > 1 {
                    Picker(
                        "Input Channel",
                        selection:
                            $audio.selectedChannel
                    ) {
                        ForEach(
                            0..<audio.availableChannels,
                            id: \.self
                        ) {
                            index in

                            Text(
                                "Ch (index + 1)"
                            )
                            .tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(
                        audio.isRunning
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    HStack {
                        Text(
                            "Input Level"
                        )

                        Spacer()

                        Text(
                            formatDB(
                                audio.levelDBFS
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(
                            audio.clipping
                            ? .red
                            : .secondary
                        )
                    }

                    ProgressView(
                        value:
                            levelProgress(
                                audio.levelDBFS
                            )
                    )
                    .tint(
                        audio.clipping
                        ? .red
                        : .accentColor
                    )
                }

                if let error =
                    audio.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(
                            .red
                        )
                }
            }
            .padding(4)
        }
    }

    private var detectedChordCard: some View {
        GroupBox(
            "Detected Chord"
        ) {
            HStack(
                alignment: .center,
                spacing: 28
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
                            size: 64,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .contentTransition(
                        .numericText()
                    )

                    Text(
                        audio.stableChord == nil &&
                        audio.estimate != nil
                        ? "判定安定化中"
                        : audio.isRunning
                        ? "リアルタイム判定"
                        : "入力停止中"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()

                VStack(
                    alignment: .trailing,
                    spacing: 6
                ) {
                    Text(
                        "Confidence"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    Text(
                        confidenceText
                    )
                    .font(
                        .title2
                            .monospacedDigit()
                    )

                    ProgressView(
                        value:
                            audio.estimate?
                                .confidence
                            ?? 0
                    )
                    .frame(width: 180)
                }
            }
            .padding(8)
        }
    }

    private var chromaCard: some View {
        GroupBox(
            "Pitch Classes"
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
            .padding(8)
        }
    }

    private var scopeNote: some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text(
                "判定対象"
            )
            .font(.headline)

            Text(
                "Major / minor / 5 / 7 / maj7 / m7 / dim / aug / sus2 / sus4。12音のエネルギー分布とコードテンプレートを照合し、数フレームの多数決で表示を安定化します。"
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                "Direct MonitorやアンプシムはオーディオIFまたはDAW側を使用し、このアプリは練習解析に専念します。"
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
        }
    }

    private var confidenceText: String {
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
        _ pitchClass: PitchClass
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

    private func levelProgress(
        _ db: Double
    ) -> Double {
        min(
            max(
                (db + 60) / 60,
                0
            ),
            1
        )
    }

    private func formatDB(
        _ db: Double
    ) -> String {
        if db <= -119 {
            return "−∞ dBFS"
        }

        return String(
            format: "%.1f dBFS",
            db
        )
    }
}

private struct ChromaCell: View {

    let pitchClass: PitchClass
    let value: Double

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 5
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
    }
}
