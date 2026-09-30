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
                minimum: 150,
                maximum: 190
            ),
            spacing: 12
        )
    ]

    var body: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 18
            ) {
                filters

                ForEach(
                    displayedRoots
                ) {
                    root in

                    let shapes =
                        filteredShapes(
                            root: root
                        )

                    if !shapes.isEmpty {
                        VStack(
                            alignment:
                                .leading,
                            spacing: 10
                        ) {
                            Text(
                                root.displayName
                            )
                            .font(.title2)
                            .fontWeight(
                                .semibold
                            )

                            LazyVGrid(
                                columns:
                                    columns,
                                spacing: 12
                            ) {
                                ForEach(
                                    shapes
                                ) {
                                    shape in

                                    GroupBox {
                                        ChordShapeDiagram(
                                            shape:
                                                shape,
                                            compact:
                                                true
                                        )
                                        .padding(
                                            6
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(22)
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

    private var filters:
        some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            ScrollView(
                .horizontal
            ) {
                HStack {
                    Button(
                        "すべて"
                    ) {
                        selectedRoot =
                            nil
                    }
                    .buttonStyle(.bordered)
                    .tint(
                        selectedRoot == nil
                        ? Color.accentColor
                        : Color.secondary
                    )

                    ForEach(
                        GuitarNote
                            .allCases
                    ) {
                        note in

                        Button(
                            note.displayName
                        ) {
                            selectedRoot =
                                note
                        }
                        .buttonStyle(.bordered)
                        .tint(
                            selectedRoot ==
                            note
                            ? Color.accentColor
                            : Color.secondary
                        )
                    }
                }
            }

            ScrollView(
                .horizontal
            ) {
                HStack {
                    Button(
                        "All qualities"
                    ) {
                        selectedQuality =
                            nil
                    }
                    .buttonStyle(.bordered)
                    .tint(
                        selectedQuality ==
                        nil
                        ? Color.accentColor
                        : Color.secondary
                    )

                    ForEach(
                        GuitarChordQuality
                            .allCases
                    ) {
                        quality in

                        Button(
                            quality
                                .displayName
                        ) {
                            selectedQuality =
                                quality
                        }
                        .buttonStyle(.bordered)
                        .tint(
                            selectedQuality ==
                            quality
                            ? Color.accentColor
                            : Color.secondary
                        )
                    }
                }
            }
        }
    }

    private var displayedRoots:
        [GuitarNote] {
        if let selectedRoot {
            [selectedRoot]
        } else {
            GuitarNote
                .allCases
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
