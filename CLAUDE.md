# CLAUDE.md

Guidance for working in this repo. Keep this file current as the app evolves.
For deferred features and ideas, see [`FUTURE_WORK.md`](./FUTURE_WORK.md); for the
sequenced release plan and monetization strategy, see [`ROADMAP.md`](./ROADMAP.md).

## What this is

**Yoto Tools** — an iOS app that hosts utilities for Yoto players. The first (and currently
only) tool is a **16×16 pixel-art editor** whose drawings can be uploaded to Yoto and
assigned as the display icon of an individual track. The host shell is built to grow more
tools over time.

Goal of v1 (done): authenticate with Yoto → create pixel art → upload it as a track image.

## Build & test

XcodeGen owns the project; `YotoTools.xcodeproj` is generated and git-ignored.
Run `xcodegen generate` whenever you add/remove source files.

**Preferred: the Makefile toolkit** (`xcode-makefiles`). Auto-resolves a simulator
destination and writes per-agent artifacts under `build/` (`build/DerivedData/<AGENT_NAME>`,
`build/logs/<AGENT_NAME>`). Override the agent with `AGENT_NAME=…`.

```bash
make diagnose          # environment + destination sanity check
make build             # build for an auto-selected iOS simulator
make test              # build + run all tests (59 unit + 1 UI smoke)
make run               # build, install, and launch in the simulator
make build-and-run     # default target
make lint              # SwiftFormat --lint + SwiftLint --strict (CI runs this)
make format            # apply SwiftFormat
make clean
```

CI (`.github/workflows/test.yml`) runs `make lint` + `make test` on every push/PR.
Lint configs: `.swiftformat` and `.swiftlint.yml` (nested test-dir configs relax
test-only rules). Keep both clean — CI treats warnings as failures.

Build logs/result bundles: `build/logs/<AGENT_NAME>/build.log` and `build.xcresult`.
Optional pretty-printer: `brew install xcbeautify`.

**Direct xcodebuild** (equivalent, explicit):

```bash
xcodebuild test -scheme YotoTools \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO
```

Notes:
- Target is **iOS 26+**, built with **Xcode 26 / Swift 6** (strict concurrency = complete).
- **`make build` treats deprecation warnings as errors.** Keep code deprecation-clean — e.g.
  on iOS 26 `UIWindow()`/`UIWindow(frame:)` are deprecated; construct windows via
  `UIWindow(windowScene:)` or reuse an existing scene window.
- `CODE_SIGNING_ALLOWED=NO` is used for direct simulator builds (the iCloud entitlement
  otherwise wants signing).

## Architecture

Layered, protocol-seam DI, with all logic in testable view models / services and thin views.

```
YotoTools/
  App/            YotoToolsApp (entry, ModelContainer), AppEnvironment (composition root)
  Core/
    Auth/         OAuthConfig, PKCE, Tokens, TokenStore (Keychain + InMemory), WebAuthenticating, AuthService
    Networking/   YotoAPI (protocol), YotoAPIClient (actor), APIError, APIErrorFormatter
    Models/       Card (CardSummary, CardDetail, Chapter/TrackView, UploadIconResponse)
    Support/      JSONValue (loss-preserving), DateProvider/UUIDProvider
  Features/
    Home/         Tool (enum), ToolsHomeView (NavigationSplitView shell)
    Settings/     SettingsView (client ID, sign in/out, options, setup guidance)
    PixelArt/
      Model/      PixelColor, PixelGrid (16×16, PNG export, flood fill, downscale), PixelArt (@Model)
      Editor/     EditorViewModel, PixelArtEditorView, PixelCanvasView, ColorPaletteView,
                  DrawingTool, ExportablePNG, PixelColor+SwiftUI
      Gallery/    GalleryViewModel, PixelArtGalleryView, PixelThumbnail
      Assign/     IconAssignmentService, CardListView(+VM), CardDetailView(+VM)
      PixelArtNavigator (routes)
YotoToolsTests/   Swift Testing suites
YotoToolsUITests/ launch smoke test
TestSupport/      Mocks (MockYotoAPI, MockWebAuthenticator, MockAuthProvider), StubURLProtocol, Fixtures
```

### Conventions
- **Concurrency:** `@Observable @MainActor` view models; `actor` for shared mutable state
  (`KeychainTokenStore`, `YotoAPIClient`). No singletons or global mutable state.
- **DI:** every external dependency is a protocol with a live + mock implementation, injected
  from `AppEnvironment` via the SwiftUI `Environment`. Inject `DateProvider`/`UUIDProvider`
  for determinism.
- **Views are thin.** Business logic lives in view models / services so it's unit-tested
  without rendering UI. SwiftData logic is tested against an in-memory `ModelContainer`.
- **Navigation:** value-based routes (`PixelArtRoute`) carrying `PersistentIdentifier`; a
  `NavigationSplitView` host + per-tool `NavigationStack` so iPhone/iPad share code.
- When adding a tool, extend the `Tool` enum and give it its own navigator + feature folder.

## Yoto API (verified against yoto.dev)

- **Auth (Auth0 @ `login.yotoplay.com`), PKCE public client (no secret):**
  `/authorize` then `POST /oauth/token`. `audience=https://api.yotoplay.com`,
  scopes `user:content:view user:content:manage user:icons:manage offline_access`.
  Refresh tokens are **single-use/rotating** — always persist the new one.
- **Content (`https://api.yotoplay.com`, Bearer):** `GET /content/mine` (summaries, no
  chapters) → `GET /content/{cardId}` (full) → `POST /content` (create/update; send the full
  card mutated in place — `CardDetail`/`JSONValue` preserve unmodelled fields).
- **Icons:** `POST /media/displayIcons/user/me/upload?autoConvert=false&filename=…` with
  `Content-Type: image/png` → `{ displayIcon: { mediaId } }`. Reference on a track as
  `display.icon16x16 = "yoto:#<mediaId>"`. We use `autoConvert=false` because we already
  render exact 16×16 PNGs.

## Key decisions

| Decision | Choice & why |
| --- | --- |
| Min iOS | **26+** — latest SwiftUI/SwiftData/Observation, newest design language. |
| UI / nav | SwiftUI only; `NavigationSplitView` + `NavigationStack` for iPhone/iPad parity. |
| Concurrency | Swift 6 strict; actors for token store + API client; `@MainActor` view models. |
| Persistence | **SwiftData + CloudKit** (`cloudKitDatabase: .automatic`), falls back to local store when iCloud is unavailable. `PixelArt` is CloudKit-safe (defaults/optionals, no unique). |
| Auth | OAuth2 **PKCE public client** via `ASWebAuthenticationSession`; tokens in Keychain. Device-code flow deferred ([`FUTURE_WORK.md`](./FUTURE_WORK.md)). |
| Icon upload | `autoConvert=false` to preserve exact pixels (we emit exact 16×16). |
| Card updates | Decode the whole card into `JSONValue`, mutate one path, re-POST writable fields (`cardId/title/content/metadata`) — avoids dropping server data. |
| Project | **XcodeGen** (`project.yml`); `.xcodeproj` generated and git-ignored. |
| Editor v1 scope | Core tools + undo/redo + Photos import + PNG export. **Animated GIF deferred** ([`FUTURE_WORK.md`](./FUTURE_WORK.md)). |
| Info.plist | `GENERATE_INFOPLIST_FILE: NO`; standard `CFBundle*` keys are set manually — **don't remove them** or the app fails to install. |
| Monetization | Free core + one-time **Pro unlock** (StoreKit 2 non-consumable) + tip jar; no subscription. Ship 1.0 under a "… for Yoto" name with animated GIF icons as the Pro headline. Plan: [`ROADMAP.md`](./ROADMAP.md). |

## Setup to connect to Yoto

Register a **Native/public** app at <https://dashboard.yoto.dev>, add redirect URI
`yototools://callback`, enable the scopes above, then paste the Client ID into the app's
**Settings**. Full steps in `README.md` and the in-app Settings screen.

## Testing

Swift Testing (`import Testing`, `#expect`/`#require`). Network tests use `StubURLProtocol`
(grouped in `@Suite(.serialized)` because the handler is static). SwiftData tests use an
in-memory `ModelContainer`. Mocks and fixtures live in `TestSupport/`. Add tests alongside
any new view model or service — keep logic out of views so it stays unit-testable.
