import Foundation
import GuitarToolsCore

actor PracticeSessionStore {

    private let directoryURL:
        URL

    init(
        directoryURL:
            URL? = nil
    ) {
        if let directoryURL {
            self.directoryURL =
                directoryURL
        } else {
            let base =
                FileManager
                    .default
                    .urls(
                        for:
                            .applicationSupportDirectory,
                        in:
                            .userDomainMask
                    )
                    .first!

            self.directoryURL =
                base
                    .appendingPathComponent(
                        "Guitar Tools",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "PracticeSessions",
                        isDirectory: true
                    )
        }
    }

    func save(
        _ session:
            PracticeSession
    ) throws {
        try ensureDirectory()

        let encoder =
            JSONEncoder()

        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        encoder.dateEncodingStrategy =
            .iso8601

        let data =
            try encoder.encode(
                session
            )

        try data.write(
            to:
                fileURL(
                    for:
                        session.id
                ),
            options:
                [.atomic]
        )
    }

    func loadAll()
        throws
        -> [PracticeSession] {
        try ensureDirectory()

        let urls =
            try FileManager
                .default
                .contentsOfDirectory(
                    at:
                        directoryURL,
                    includingPropertiesForKeys:
                        nil,
                    options: [
                        .skipsHiddenFiles
                    ]
                )
                .filter {
                    $0.pathExtension ==
                        "json"
                }

        let decoder =
            JSONDecoder()

        decoder.dateDecodingStrategy =
            .iso8601

        return urls
            .compactMap {
                url in

                guard
                    let data =
                        try? Data(
                            contentsOf: url
                        ),
                    let session =
                        try? decoder
                            .decode(
                                PracticeSession.self,
                                from:
                                    data
                            ),
                    session.schemaVersion <=
                        PracticeSession
                            .currentSchemaVersion
                else {
                    return nil
                }

                return session
            }
            .sorted {
                $0.startedAt >
                    $1.startedAt
            }
    }

    func remove(
        id: UUID
    ) throws {
        let url =
            fileURL(for: id)

        guard FileManager
            .default
            .fileExists(
                atPath:
                    url.path
            )
        else {
            return
        }

        try FileManager
            .default
            .removeItem(
                at: url
            )
    }

    private func ensureDirectory()
        throws {
        try FileManager
            .default
            .createDirectory(
                at:
                    directoryURL,
                withIntermediateDirectories:
                    true
            )
    }

    private func fileURL(
        for id: UUID
    ) -> URL {
        directoryURL
            .appendingPathComponent(
                id.uuidString
            )
            .appendingPathExtension(
                "json"
            )
    }
}
