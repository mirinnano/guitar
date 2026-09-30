import GuitarToolsCore
import SwiftUI

struct ChordsView:
    View {

    @State
    private var query = ""

    @State
    private var selectedRoot:
        GuitarNote?

    @State
    private var selectedQuality:
        GuitarChordQuality?

    private let columns = [
        GridItem(
            .adaptive(
                minimum: 160,
                maximum: 210
            ),
            spacing: 12
        )
    ]

    var body: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 22
            ) {
                MacPageHeader(
                    "コード",
                    subtitle:
                        "12ルート × 16種類の押さえ方"
                ) {
                    MacStatusPill(
                        text:
                            "\(resultCount) chords",
                        systemImage:
                            "guitars",
                        role: .neutral
                    )
                }

                filterBar

                if resultCount == 0 {
                    ContentUnavailableView(
                        "コードが見つかりません",
                        systemImage:
                            "magnifyingglass",
                        description:
                            Text(
                                "検索語またはフィルターを変更してください。"
                            )
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 320
                    )
                } else {
                    ForEach(
                        displayedRoots
                    ) {
                        root in

                        let shapes =
                            filteredShapes(
                                root: root
                            )

                        if !shapes.isEmpty {
                            rootSection(
                                root,
                                shapes: shapes
                            )
                        }
                    }
                }
            }
            .padding(26)
            .macPageWidth(1_180)
        }
        .navigationTitle(
            "コード"
        )
        .searchable(
            text: $query,
            placement: .toolbar,
            prompt:
                "C, Am, maj7..."
        )
    }

    private var filterBar:
        some View {

        MacSection(
            "フィルター"
        ) {
            HStack(
                spacing: 14
            ) {
                Picker(
                    "Root",
                    selection:
                        $selectedRoot
                ) {
                    Text("All roots")
                        .tag(
                            Optional<GuitarNote>
                                .none
                        )

                    ForEach(
                        GuitarNote.allCases
                    ) {
                        note in

                        Text(
                            note.displayName
                        )
                        .tag(
                            Optional(note)
                        )
                    }
                }
                .frame(
                    minWidth: 150
                )

                Picker(
                    "Quality",
                    selection:
                        $selectedQuality
                ) {
                    Text("All qualities")
                        .tag(
                            Optional<
                                GuitarChordQuality
                            >.none
                        )

                    ForEach(
                        GuitarChordQuality
                            .allCases
                    ) {
                        quality in

                        Text(
                            quality
                                .displayName
                        )
                        .tag(
                            Optional(
                                quality
                            )
                        )
                    }
                }
                .frame(
                    minWidth: 190
                )

                Spacer()

                if selectedRoot != nil ||
                    selectedQuality != nil ||
                    !query.isEmpty {
                    Button(
                        "リセット"
                    ) {
                        selectedRoot = nil
                        selectedQuality =
                            nil
                        query = ""
                    }
                }
            }
        }
    }

    private func rootSection(
        _ root: GuitarNote,
        shapes:
            [GuitarChordShape]
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            HStack {
                Text(
                    root.displayName
                )
                .font(
                    .title2
                        .weight(
                            .semibold
                        )
                )

                Text(
                    "\(shapes.count)"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                Spacer()
            }

            LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(
                    shapes
                ) {
                    shape in

                    ChordShapeDiagram(
                        shape: shape,
                        compact: true
                    )
                    .padding(12)
                    .frame(
                        maxWidth: .infinity
                    )
                    .background(
                        .quaternary
                            .opacity(0.16),
                        in:
                            RoundedRectangle(
                                cornerRadius: 12,
                                style:
                                    .continuous
                            )
                    )
                }
            }
        }
    }

    private var displayedRoots:
        [GuitarNote] {
        if let selectedRoot {
            [selectedRoot]
        } else {
            GuitarNote.allCases
        }
    }

    private var resultCount:
        Int {
        displayedRoots
            .reduce(0) {
                result,
                root in

                result +
                    filteredShapes(
                        root: root
                    ).count
            }
    }

    private func filteredShapes(
        root: GuitarNote
    ) -> [GuitarChordShape] {
        CommonGuitarChords
            .forRoot(root)
            .filter {
                shape in

                let queryMatch =
                    query.isEmpty ||
                    shape.name
                        .localizedCaseInsensitiveContains(
                            query
                        )

                let qualityMatch =
                    selectedQuality ==
                    nil ||
                    shape.chord.quality ==
                    selectedQuality

                return queryMatch &&
                    qualityMatch
            }
    }
}
