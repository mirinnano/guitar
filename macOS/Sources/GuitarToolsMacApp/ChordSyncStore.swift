import Foundation
import GuitarToolsCore

struct ChordSyncStore {

    private let defaults =
        UserDefaults.standard

    func load(
        chart: ChordChart
    ) -> [ChordSyncAnchor] {
        guard
            let data =
                defaults.data(
                    forKey:
                        key(chart)
                ),
            let anchors =
                try? JSONDecoder()
                    .decode(
                        [ChordSyncAnchor]
                            .self,
                        from: data
                    )
        else {
            return []
        }

        return anchors
    }

    func save(
        _ anchors:
            [ChordSyncAnchor],
        chart: ChordChart
    ) {
        guard
            let data =
                try? JSONEncoder()
                    .encode(anchors)
        else {
            return
        }

        defaults.set(
            data,
            forKey:
                key(chart)
        )
    }

    func clear(
        chart: ChordChart
    ) {
        defaults.removeObject(
            forKey:
                key(chart)
        )
    }

    private func key(
        _ chart:
            ChordChart
    ) -> String {
        "chordwiki-sync:" +
        (
            chart.sourceURL?
                .absoluteString
            ?? chart.title
        ) +
        "#" +
        (
            chart.youtubeVideoID
            ?? ""
        )
    }
}
