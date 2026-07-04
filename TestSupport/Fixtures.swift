import Foundation
@testable import YotoTools

enum Fixtures {
    /// A two-track card where track one already has an icon and track two has none.
    static let cardJSON = """
    {
      "cardId": "CARD1",
      "title": "Bedtime Stories",
      "createdAt": "2025-09-09T13:10:00.000Z",
      "userId": "user-123",
      "metadata": {
        "author": "Jane",
        "cover": { "imageL": "https://example.com/cover.png" }
      },
      "content": {
        "playbackType": "linear",
        "config": { "resumeTimeout": 2592000 },
        "chapters": [
          {
            "key": "ch1",
            "title": "Chapter One",
            "tracks": [
              {
                "key": "t1",
                "title": "The Moon",
                "trackUrl": "yoto:#abc",
                "display": { "icon16x16": "yoto:#OLDICON" }
              },
              {
                "key": "t2",
                "title": "The Stars",
                "trackUrl": "yoto:#def",
                "display": {}
              }
            ]
          }
        ]
      }
    }
    """

    static func card() -> CardDetail {
        try! CardDetail.decode(from: Data(cardJSON.utf8))
    }

    static func myContent() -> [String: Any] {
        [
            "cards": [
                [
                    "cardId": "CARD1",
                    "title": "Bedtime Stories",
                    "metadata": ["cover": ["imageL": "https://example.com/cover.png"]],
                ],
            ],
        ]
    }

    /// User icons listing response, one entry per media id, matching the server's shape.
    static func userIcons(_ mediaIds: [String]) -> [String: Any] {
        [
            "displayIcons": mediaIds.map { mediaId in
                [
                    "displayIconId": "display-\(mediaId)",
                    "mediaId": mediaId,
                    "userId": "user-123",
                    "createdAt": "2025-05-28T16:16:06.451Z",
                    "url": "https://example.com/icons/\(mediaId).png",
                    "public": false,
                ] as [String: Any]
            },
        ]
    }

    static func tokenResponse(
        accessToken: String,
        refreshToken: String?,
        expiresIn: Double = 3600
    ) -> [String: Any] {
        var object: [String: Any] = [
            "access_token": accessToken,
            "expires_in": expiresIn,
            "token_type": "Bearer",
            "scope": "user:content:view",
        ]
        if let refreshToken { object["refresh_token"] = refreshToken }
        return object
    }
}
