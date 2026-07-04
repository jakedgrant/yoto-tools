# Yoto Tools

An iOS app that hosts utilities for Yoto players. The first tool is a **16×16 pixel-art
editor** whose drawings can be uploaded to Yoto and assigned as the display icon of an
individual track.

- Modern SwiftUI + Swift 6 strict concurrency (`@Observable` view models, actors for the
  token store and API client).
- Adaptive navigation (`NavigationSplitView` + per-tool `NavigationStack`) for iPhone and iPad.
- SwiftData + CloudKit gallery (falls back to a local store when iCloud is unavailable).
- OAuth2 (Auth0) with PKCE via `ASWebAuthenticationSession`; tokens in the Keychain.

## Requirements

- Xcode 26+ / iOS 26 SDK
- [XcodeGen](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`)

## Getting started

```bash
xcodegen generate        # creates YotoTools.xcodeproj from project.yml
open YotoTools.xcodeproj
```

Or from the command line:

```bash
xcodebuild build -scheme YotoTools \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO

xcodebuild test -scheme YotoTools \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO
```

## Connecting to Yoto (one-time setup)

The app needs a Yoto **Client ID**. Native apps use PKCE and do **not** need a client secret.

1. Sign in at <https://dashboard.yoto.dev>.
2. Create an app as a **Native / public client** (PKCE).
3. Add the redirect URI **`yototools://callback`**.
4. Enable scopes: `user:content:view`, `user:content:manage`, `user:icons:manage`,
   and `offline_access`.
5. Launch the app → **Settings** (gear icon) → paste the Client ID → **Save**, then
   **Sign In with Yoto**.

## How it works

1. **Draw** a 16×16 icon in the editor (pencil/eraser/fill/eyedropper, line/rectangle/
   ellipse shapes, mirror drawing, palette + custom color, undo/redo, import-from-Photos,
   share as PNG).
2. **Save** it to your gallery. Editing an existing drawing prompts to *overwrite* or
   *save a copy*.
3. **Assign**: choose one of your Yoto playlists, pick a track, and the app uploads the
   art (`POST /media/displayIcons/user/me/upload`) and points the track's
   `display.icon16x16` at the new media id while preserving the rest of the card.

## Project layout

| Path | Contents |
| --- | --- |
| `YotoTools/Core/` | Auth (PKCE, token store, `AuthService`), networking (`YotoAPIClient`), models, support types |
| `YotoTools/Features/PixelArt/` | Pixel model, editor, gallery, and assign-to-track flow |
| `YotoTools/Features/Home`, `…/Settings` | Tool host (split view) and settings |
| `YotoToolsTests/` | Swift Testing suites (78 tests) |
| `TestSupport/` | Mocks, URL-protocol stub, fixtures |
