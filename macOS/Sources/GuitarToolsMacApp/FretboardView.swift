import GuitarToolsCore
import SwiftUI

private enum FretboardMode:
    String,
    CaseIterable,
    Identifiable {

    case note = "Note"
    case scale = "Scale"
    case chord = "Chord"

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

    @State
    private var zoom =
        1.0

    var body: some View {
        VStack(
            spacing: 0
        ) {
            controls

            Divider()

            ScrollView(
                [
                    .horizontal,
                    .vertical
                ]
            ) {
                fretboard
                    .scaleEffect(
                        zoom,
                        anchor:
                            .topLeading
                    )
                    .frame(
                        width:
                            (
                                56 +
                                Double(maxFret) *
                                64
                            ) *
                            zoom,
                        height:
                            (
                                26 +
                                6 * 48
                            ) *
                            zoom,
                        alignment:
                            .topLeading
                    )
                    .padding(22)
                    .gesture(
                        MagnifyGesture()
                            .onChanged {
                                value in

                                zoom =
                                    min(
                                        max(
                                            value
                                                .magnification,
                                            0.65
                                        ),
                                        1.8
                                    )
                            }
                    )
            }
        }
        .navigationTitle(
            "指板"
        )
    }

    private var controls:
        some View {
        HStack(
            spacing: 12
        ) {
            Picker(
                "Tuning",
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
                width: 170
            )

            Picker(
                "Mode",
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
            .frame(
                width: 120
            )

            Picker(
                "Root",
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
                width: 100
            )

            if mode == .scale {
                Picker(
                    "Scale",
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
                    width: 190
                )
            }

            if mode == .chord {
                Picker(
                    "Chord",
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
                    width: 140
                )
            }

            Stepper(
                "\(maxFret) frets",
                value:
                    $maxFret,
                in: 12...24
            )

            Toggle(
                "Intervals",
                isOn:
                    $intervalLabels
            )

            Toggle(
                "Left",
                isOn:
                    $leftHanded
            )

            LabeledContent(
                "Zoom"
            ) {
                Slider(
                    value: $zoom,
                    in: 0.65...1.8
                )
                .frame(
                    width: 110
                )
            }

            Spacer()
        }
        .padding(
            .horizontal,
            16
        )
        .padding(
            .vertical,
            10
        )
    }

    private var fretboard:
        some View {
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
                                ? 56
                                : 64,
                            height: 48
                        )
                    }
                }
            }
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
                    ? "Open"
                    : "\(fret)"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width:
                        fret == 0
                        ? 56
                        : 64,
                    height: 26
                )
            }
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
                    ? Color
                        .secondary
                        .opacity(0.08)
                    : Color.clear
                )

            Rectangle()
                .stroke(
                    Color.secondary
                        .opacity(0.25),
                    lineWidth: 0.5
                )

            if highlighted {
                Circle()
                    .fill(
                        isRoot
                        ? Color
                            .accentColor
                        : Color
                            .secondary
                            .opacity(0.28)
                    )
                    .frame(
                        width: 30,
                        height: 30
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
