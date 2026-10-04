import GuitarToolsCore
import SwiftUI

private enum FretboardMode:
    String,
    CaseIterable,
    Identifiable {

    case note = "音名"
    case scale = "スケール"
    case chord = "コード"

    var id: String {
        rawValue
    }
}

struct FretboardView:
    View {

    @State
    private var tuning =
        GuitarTuning.standard

    @State
    private var mode:
        FretboardMode =
        .scale

    @State
    private var root =
        GuitarNote.c

    @State
    private var scale =
        GuitarScaleType.major

    @State
    private var quality =
        GuitarChordQuality.major

    @State
    private var maxFret = 24

    @State
    private var intervalLabels =
        true

    @State
    private var leftHanded =
        false

    var body: some View {
        VStack(
            spacing: 0
        ) {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                MacPageHeader("指板") {
                    MacStatusPill(
                        text:
                            leftHanded
                            ? "左利き"
                            : tuning.name,
                        systemImage:
                            leftHanded
                            ? "hand.raised"
                            : "guitars",
                        role: .neutral
                    )
                }

                controls
            }
            .padding(MacLayout.pagePadding)

            Divider()

            ScrollView(
                [
                    .horizontal,
                    .vertical
                ]
            ) {
                fretboardCanvas
                    .padding(MacLayout.pagePadding)
            }
            .background(
                Color.secondary
                    .opacity(0.025)
            )
        }
        .navigationTitle(
            "指板"
        )
    }

    private var controls:
        some View {

        MacSection(
            "表示"
        ) {
            ViewThatFits {
                HStack(
                    spacing: 14
                ) {
                    controlContent
                }

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {
                    controlContent
                }
            }
        }
    }

    @ViewBuilder
    private var controlContent:
        some View {

        Picker(
            "チューニング",
            selection:
                $tuning
        ) {
            ForEach(
                GuitarTuning.presets
            ) {
                Text($0.name)
                    .tag($0)
            }
        }
        .frame(
            minWidth: 160
        )

        Picker(
            "表示内容",
            selection:
                $mode
        ) {
            ForEach(
                FretboardMode
                    .allCases
            ) {
                Text($0.rawValue)
                    .tag($0)
            }
        }
        .pickerStyle(.segmented)
        .frame(
            minWidth: 220
        )

        Picker(
            "ルート",
            selection:
                $root
        ) {
            ForEach(
                GuitarNote
                    .allCases
            ) {
                Text(
                    $0.displayName
                )
                .tag($0)
            }
        }
        .frame(
            minWidth: 100
        )

        if mode == .scale {
            Picker(
                "スケール",
                selection:
                    $scale
            ) {
                ForEach(
                    GuitarScaleType
                        .allCases
                ) {
                    Text($0.rawValue)
                        .tag($0)
                }
            }
            .frame(
                minWidth: 180
            )
        }

        if mode == .chord {
            Picker(
                "コード",
                selection:
                    $quality
            ) {
                ForEach(
                    GuitarChordQuality
                        .allCases
                ) {
                    Text(
                        $0.displayName
                    )
                    .tag($0)
                }
            }
            .frame(
                minWidth: 150
            )
        }

        Stepper(
            "\(maxFret) フレット",
            value:
                $maxFret,
            in: 12...24
        )

        Toggle(
            "度数を表示",
            isOn:
                $intervalLabels
        )

        Toggle(
            "左利き",
            isOn:
                $leftHanded
        )
    }

    private var fretboardCanvas:
        some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack(
                spacing: 12
            ) {
                Text(
                    canvasTitle
                )
                .font(
                    .headline
                )

                Text(
                    intervalLabels
                    ? "度数表示"
                    : "音名表示"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            VStack(
                spacing: 0
            ) {
                fretNumbers

                ForEach(
                    stringOrder,
                    id:
                        \.stringNumber
                ) {
                    string in

                    HStack(
                        spacing: 0
                    ) {
                        ForEach(
                            fretOrder,
                            id: \.self
                        ) {
                            fret in

                            let midi =
                                string.midi +
                                fret

                            let note =
                                GuitarNote
                                    .fromMIDI(
                                        midi
                                    )

                            FretCell(
                                note: note,
                                text:
                                    cellText(
                                        note
                                    ),
                                highlighted:
                                    isHighlighted(
                                        note
                                    ),
                                isRoot:
                                    note ==
                                    root,
                                fret: fret
                            )
                            .frame(
                                width:
                                    fret == 0
                                    ? 58
                                    : 66,
                                height: 50
                            )
                        }
                    }
                }
            }
            .background(
                .background,
                in:
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
            )
        }
    }

    private var fretNumbers:
        some View {
        HStack(
            spacing: 0
        ) {
            ForEach(
                fretOrder,
                id: \.self
            ) {
                fret in

                Text(
                    fret == 0
                    ? "開放"
                    : "\(fret)"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width:
                        fret == 0
                        ? 58
                        : 66,
                    height: 28
                )
            }
        }
    }

    private var canvasTitle:
        String {
        switch mode {
        case .note:
            root.displayName
        case .scale:
            "\(root.displayName) \(scale.rawValue)"
        case .chord:
            GuitarChord(
                root: root,
                quality: quality
            ).name
        }
    }

    private var stringOrder:
        [GuitarStringTuning] {
        let strings =
            tuning.strings
                .sorted {
                    $0.stringNumber <
                    $1.stringNumber
                }

        return leftHanded
        ? Array(
            strings.reversed()
        )
        : strings
    }

    private var fretOrder:
        [Int] {
        let values =
            Array(
                0...maxFret
            )

        return leftHanded
        ? Array(
            values.reversed()
        )
        : values
    }

    private func isHighlighted(
        _ note: GuitarNote
    ) -> Bool {
        switch mode {
        case .note:
            note == root

        case .scale:
            scale
                .notes(root: root)
                .contains(note)

        case .chord:
            GuitarChord(
                root: root,
                quality: quality
            )
            .notes
            .contains(note)
        }
    }

    private func cellText(
        _ note: GuitarNote
    ) -> String {
        guard isHighlighted(
            note
        )
        else {
            return ""
        }

        return intervalLabels
        ? intervalLabel(
            root: root,
            note: note
        )
        : note.displayName
    }
}

private struct FretCell:
    View {

    let note: GuitarNote
    let text: String
    let highlighted: Bool
    let isRoot: Bool
    let fret: Int

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    fret == 0
                    ? Color.secondary
                        .opacity(0.07)
                    : Color.clear
                )

            Rectangle()
                .stroke(
                    Color.secondary
                        .opacity(0.20),
                    lineWidth: 0.5
                )

            if highlighted {
                Circle()
                    .fill(
                        isRoot
                        ? Color.accentColor
                        : Color.secondary
                            .opacity(0.20)
                    )
                    .overlay {
                        if isRoot {
                            Circle()
                                .stroke(
                                    Color.white
                                        .opacity(0.28),
                                    lineWidth: 1
                                )
                                .padding(2)
                        }
                    }
                    .frame(
                        width: 32,
                        height: 32
                    )

                Text(text)
                    .font(
                        .caption
                            .bold()
                    )
                    .foregroundStyle(
                        isRoot
                        ? Color.white
                        : Color.primary
                    )
            }
        }
    }
}
