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

    private var lastMusicBrainzRequest =
        Date.distantPast

    func search(
        query: String
    ) async throws
        -> [MacSongSearchResult] {

        let apiKey =
            ProcessInfo
                .processInfo
                .environment[
                    "GETSONGBPM_API_KEY"
                ]
            ?? UserDefaults
                .standard
                .string(
                    forKey:
                        "getsongbpm.apiKey"
                )
            ?? ""

        if !apiKey
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty {
            let results =
                try? await searchGetSongBPM(
                    query: query,
                    apiKey: apiKey
                )

            if let results,
               !results.isEmpty {
                return results
            }
        }

        return try await
            searchMusicBrainz(
                query: query
            )
    }

    private func searchGetSongBPM(
        query: String,
        apiKey: String
    ) async throws
        -> [MacSongSearchResult] {

        var components =
            URLComponents(
                string:
                    "https://api.getsong.co/search/"
            )!

        components.queryItems = [
            URLQueryItem(
                name: "api_key",
                value: apiKey
            ),
            URLQueryItem(
                name: "type",
                value: "song"
            ),
            URLQueryItem(
                name: "lookup",
                value: query
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

        request.timeoutInterval = 8
        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
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

        let values:
            [[String: Any]]

        if let array =
            object
                as? [[String: Any]] {
            values = array
        } else if let root =
            object
                as? [String: Any] {
            values =
                root["search"]
                    as? [[String: Any]]
                ?? root["songs"]
                    as? [[String: Any]]
                ?? root["results"]
                    as? [[String: Any]]
                ?? []
        } else {
            values = []
        }

        return values
            .compactMap {
                item in

                let id =
                    string(
                        item[
                            "song_id"
                        ]
                    )
                    .nonEmpty
                    ?? string(
                        item["id"]
                    )
                    .nonEmpty
                    ?? UUID()
                        .uuidString

                guard let title =
                    (
                        string(
                            item[
                                "song_title"
                            ]
                        )
                        .nonEmpty
                        ?? string(
                            item["title"]
                        )
                        .nonEmpty
                    )
                else {
                    return nil
                }

                let artist =
                    artistName(
                        item["artist"]
                    )

                let tempo =
                    intValue(
                        item["tempo"]
                    )

                let timeSignature =
                    string(
                        item[
                            "time_sig"
                        ]
                    )
                    .nonEmpty

                let key =
                    string(
                        item[
                            "key_of"
                        ]
                    )
                    .nonEmpty

                let source =
                    (
                        string(
                            item[
                                "song_uri"
                            ]
                        )
                        .nonEmpty
                        ?? string(
                            item[
                                "uri"
                            ]
                        )
                        .nonEmpty
                    )
                    .flatMap(
                        URL.init(
                            string:
                        )
                    )

                return MacSongSearchResult(
                    id: id,
                    title: title,
                    artist: artist,
                    durationMs: nil,
                    bpm: tempo,
                    timeSignature:
                        timeSignature,
                    musicalKey: key,
                    sourceName:
                        "GetSongBPM",
                    sourceURL:
                        source
                )
            }
    }

    private func searchMusicBrainz(
        query: String
    ) async throws
        -> [MacSongSearchResult] {

        let elapsed =
            Date()
                .timeIntervalSince(
                    lastMusicBrainzRequest
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

        lastMusicBrainzRequest =
            Date()

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

    private func artistName(
        _ value: Any?
    ) -> String {
        if let object =
            value
                as? [String: Any] {
            return string(
                object["name"]
            )
        }

        if let array =
            value
                as? [[String: Any]],
           let first =
            array.first {
            return string(
                first["name"]
            )
        }

        return ""
    }

    private func string(
        _ value: Any?
    ) -> String {
        if let value =
            value as? String {
            return value
        }

        if let value =
            value as? NSNumber {
            return value
                .stringValue
        }

        return ""
    }

    private func intValue(
        _ value: Any?
    ) -> Int? {
        if let value =
            value as? NSNumber {
            return value
                .intValue
        }

        if let value =
            value as? String,
           let number =
            Double(value) {
            return Int(
                number.rounded()
            )
        }

        return nil
    }
}

private extension String {
    var nonEmpty:
        String? {
        isEmpty
        ? nil
        : self
    }
}
