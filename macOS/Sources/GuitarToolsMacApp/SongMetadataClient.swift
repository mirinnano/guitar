import Foundation

struct MacSongSearchResult:
    Identifiable,
    Hashable,
    Sendable {

    let id: String
    let title: String
    let artist: String
    let durationMs: Int64?
    let bpm: Int?
    let timeSignature: String?
    let musicalKey: String?
    let sourceName: String
    let sourceURL: URL?
}

actor SongMetadataClient {

    private var lastRequest =
        Date.distantPast

    func search(
        query: String
    ) async throws
        -> [MacSongSearchResult] {

        let elapsed =
            Date()
                .timeIntervalSince(
                    lastRequest
                )

        if elapsed < 1.05 {
            try await Task.sleep(
                for:
                    .seconds(
                        1.05 -
                        elapsed
                    )
            )
        }

        lastRequest = Date()

        var components =
            URLComponents(
                string:
                    "https://musicbrainz.org/ws/2/recording/"
            )!

        components.queryItems = [
            URLQueryItem(
                name: "query",
                value: query
            ),
            URLQueryItem(
                name: "fmt",
                value: "json"
            ),
            URLQueryItem(
                name: "limit",
                value: "20"
            )
        ]

        guard let url =
            components.url
        else {
            return []
        }

        var request =
            URLRequest(url: url)

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
        )

        request.setValue(
            "GuitarToolsMac/0.2 (https://github.com/mirinnano/guitar)",
            forHTTPHeaderField:
                "User-Agent"
        )

        let (
            data,
            response
        ) =
            try await URLSession
                .shared
                .data(
                    for: request
                )

        guard
            let http =
                response
                as? HTTPURLResponse,
            (200..<300)
                .contains(
                    http.statusCode
                )
        else {
            return []
        }

        let object =
            try JSONSerialization
                .jsonObject(
                    with: data
                )

        guard
            let root =
                object
                as? [String: Any],
            let recordings =
                root["recordings"]
                as? [
                    [String: Any]
                ]
        else {
            return []
        }

        return recordings
            .compactMap {
                item in

                guard
                    let id =
                        item["id"]
                        as? String,
                    let title =
                        item["title"]
                        as? String
                else {
                    return nil
                }

                let credit =
                    item[
                        "artist-credit"
                    ] as? [
                        [String: Any]
                    ]

                let artist =
                    credit?
                        .first?["name"]
                    as? String
                    ?? ""

                let length =
                    (
                        item["length"]
                        as? NSNumber
                    )?
                    .int64Value

                return MacSongSearchResult(
                    id: id,
                    title: title,
                    artist: artist,
                    durationMs:
                        length,
                    bpm: nil,
                    timeSignature: nil,
                    musicalKey: nil,
                    sourceName:
                        "MusicBrainz",
                    sourceURL:
                        URL(
                            string:
                                "https://musicbrainz.org/recording/\(id)"
                        )
                )
            }
    }
}
