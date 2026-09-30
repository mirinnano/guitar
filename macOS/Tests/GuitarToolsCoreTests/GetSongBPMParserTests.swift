import XCTest
@testable import GuitarToolsMacApp

final class GetSongBPMParserTests:
    XCTestCase {

    func testParsesRichSongMetadata() throws {
        let json =
            """
            {
              "search": [
                {
                  "song_id": "song-1",
                  "song_title": "Example Song",
                  "tempo": "148",
                  "time_sig": "4/4",
                  "key_of": "C#m",
                  "song_uri": "https://getsongbpm.com/song/example",
                  "artist": {
                    "name": "Example Artist"
                  }
                }
              ]
            }
            """

        let values =
            try GetSongBPMParser
                .parse(
                    data:
                        Data(
                            json.utf8
                        )
                )

        XCTAssertEqual(
            values.count,
            1
        )
        XCTAssertEqual(
            values[0].title,
            "Example Song"
        )
        XCTAssertEqual(
            values[0].artist,
            "Example Artist"
        )
        XCTAssertEqual(
            values[0].bpm,
            148
        )
        XCTAssertEqual(
            values[0]
                .timeSignature,
            "4/4"
        )
        XCTAssertEqual(
            values[0]
                .musicalKey,
            "C#m"
        )
        XCTAssertEqual(
            values[0]
                .sourceName,
            "GetSongBPM"
        )
    }

    func testAcceptsArrayArtistShape() throws {
        let json =
            """
            [
              {
                "id": "song-2",
                "title": "Array Artist",
                "tempo": 96,
                "artist": [
                  {
                    "name": "Artist"
                  }
                ]
              }
            ]
            """

        let values =
            try GetSongBPMParser
                .parse(
                    data:
                        Data(
                            json.utf8
                        )
                )

        XCTAssertEqual(
            values.first?
                .artist,
            "Artist"
        )
        XCTAssertEqual(
            values.first?
                .bpm,
            96
        )
    }
}
