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

enum GetSongBPMParser {

    static func parse(
        data: Data
    ) throws
        -> [MacSongSearchResult] {

        let object =
            try JSONSerialization
                .jsonObject(
                    with: data
                )

        let items:
            [[String: Any]]

        if let array =
            object as?
                [[String: Any]] {
            items = array
        } else if let root =
            object as?
                [String: Any] {
            items =
                (
                    root["search"]
                    ?? root["songs"]
                    ?? root["results"]
                )
                as?
                    [[String: Any]]
                ?? []
        } else {
            items = []
        }

        return items
            .compactMap {
                item in

                let id =
                    string(
                        item["song_id"]
                    )
                    .ifBlank {
                        string(
                            item["id"]
                        )
                    }

                let title =
                    string(
                        item["song_title"]
                    )
                    .ifBlank {
                        string(
                            item["title"]
                        )
                    }

                guard
                    !id.isEmpty,
                    !title.isEmpty
                else {
                    return nil
                }

                let artist =
                    artistName(
                        item["artist"]
                    )

                let bpm =
                    Int(
                        string(
                            item["tempo"]
                        )
                    )

                let meter =
                    string(
                        item["time_sig"]
                    )
                    .nilIfBlank

                let key =
                    string(
                        item["key_of"]
                    )
                    .nilIfBlank

                let rawURL =
                    string(
                        item["song_uri"]
                    )
                    .ifBlank {
                        string(
                            item["uri"]
                        )
                    }

                let sourceURL =
                    rawURL
                        .hasPrefix("http")
                    ? URL(
                        string: rawURL
                    )
                    : nil

                return MacSongSearchResult(
                    id: id,
                    title: title,
                    artist: artist,
                    durationMs: nil,
                    bpm: bpm,
                    timeSignature:
                        meter,
                    musicalKey: key,
                    sourceName:
                        "GetSongBPM",
                    sourceURL:
                        sourceURL
                )
            }
    }

    private static func artistName(
        _ value: Any?
    ) -> String {
        if let object =
            value as?
                [String: Any] {
            return string(
                object["name"]
            )
        }

        if let array =
            value as?
                [[String: Any]],
           let first =
            array.first {
            return string(
                first["name"]
            )
        }

        if let value =
            value as? String {
            return value
        }

        return ""
    }

    private static func string(
        _ value: Any?
    ) -> String {
        switch value {
        case let value as String:
            value

        case let value as NSNumber:
            value.stringValue

        default:
            ""
        }
    }
}

actor SongMetadataClient {

    private let getSongBPMAPIKey:
        String

    private var lastMusicBrainzRequest =
        Date.distantPast

    init(
        getSongBPMAPIKey:
            String =
            SongMetadataClient
                .configuredGetSongBPMKey()
    ) {
        self.getSongBPMAPIKey =
            getSongBPMAPIKey
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
    }

    func search(
        query: String
    ) async throws
        -> [MacSongSearchResult] {

        let trimmed =
            query.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !trimmed.isEmpty
        else {
            return []
        }

        if !getSongBPMAPIKey
            .isEmpty {
            let richResults =
                (
                    try? await
                        searchGetSongBPM(
                            query:
                                trimmed
                        )
                )
                ?? []

            if !richResults
                .isEmpty {
                return richResults
            }
        }

        return try await
            searchMusicBrainz(
                query: trimmed
            )
    }

    private func searchGetSongBPM(
        query: String
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
                value:
                    getSongBPMAPIKey
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

        request.setValue(
            userAgent,
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
                response as?
                    HTTPURLResponse,
            (200..<300)
                .contains(
                    http.statusCode
                )
        else {
            return []
        }

        return try
            GetSongBPMParser
                .parse(data: data)
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

        request.timeoutInterval = 8

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
        )

        request.setValue(
            userAgent,
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

    private var userAgent:
        String {
        "GuitarToolsMac/0.2 (https://github.com/mirinnano/guitar)"
    }

    nonisolated
    static func configuredGetSongBPMKey()
        -> String {

        let environment =
            ProcessInfo
                .processInfo
                .environment[
                    "GETSONGBPM_API_KEY"
                ]
                ?? ""

        if !environment
            .isEmpty {
            return environment
        }

        return Bundle.main
            .object(
                forInfoDictionaryKey:
                    "GetSongBPMAPIKey"
            )
            as? String
            ?? ""
    }
}

private extension String {

    var nilIfBlank:
        String? {
        isEmpty ? nil : self
    }

    func ifBlank(
        _ replacement:
            () -> String
    ) -> String {
        isEmpty
        ? replacement()
        : self
    }
}
