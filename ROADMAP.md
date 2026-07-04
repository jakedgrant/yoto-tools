# Roadmap

The sequenced plan for taking Yoto Tools from working-v1 to a shipped, monetized App Store
app. [`FUTURE_WORK.md`](./FUTURE_WORK.md) holds the detailed per-feature notes; this file
says what order to do them in and why. Check items off as they land.

## Product & monetization decisions

- **Model: free core + one-time Pro unlock** (StoreKit 2 non-consumable, target **$4.99**,
  Family Sharing on) plus a small tip jar. **No subscription** — the app has zero server
  costs (it talks directly to Yoto's API with the user's token), and the Yoto community's
  precedent is goodwill-driven freemium (MYO Studio, yotoicons.com).
- **Release strategy: build features first, launch once.** Hold release until the animated
  GIF editor is done, then launch 1.0 already monetized with GIFs as the Pro headline.
- **Rename before launch** to a "… for Yoto" name (Apple's convention for third-party
  companion apps; Yoto's API terms reserve their branding). Candidates: *Icon Studio for
  Yoto*, *Pixel Icons for Yoto*, *Track Icons for Yoto*. The bundle ID, iCloud container,
  and URL scheme get finalized at the same time — none can change casually after the first
  App Store Connect upload.

| Tier | Contents |
| --- | --- |
| **Free — the full v1 promise, forever** | Single-frame editor (pencil/eraser/fill/eyedropper, undo/redo, palette + custom color, Photos import, PNG share) · gallery with CloudKit sync · upload + assign to any track · reuse already-uploaded icons · browse the public Yoto icon library |
| **Pro — one-time unlock** | Animated GIF icons (multi-frame editor + GIF upload) · shape tools (line/rect/ellipse) + mirror drawing · whole-chapter batch assignment · import public-library icons into the editor · future premium tools at no extra charge |
| **Tip jar** | Three consumables ($1.99 / $4.99 / $9.99) in Settings |

Compliance notes for launch: parent-facing utility, **not** Kids category. Privacy label
should be "Data Not Collected" (tokens stay in the Keychain, no analytics) — verify before
claiming, and ship a privacy manifest + hosted privacy policy. App Review needs a demo Yoto
account and review notes, since reviewers won't own a Yoto player.

## Phase 0 — Groundwork & tooling

- [ ] Email developers@yotoplay.com: confirm commercial use is acceptable and ask about
      "for Yoto" naming. Send early so the answer arrives before launch prep.
- [x] Initial git commit
- [x] CI: GitHub Actions workflow running lint + `make test` (needs a GitHub remote)
- [x] SwiftFormat + SwiftLint configs matching existing conventions
- [ ] Pick the final app name; register the production client at dashboard.yoto.dev

## Phase 1 — Editor & assignment quick wins

Each lands independently, in this order:

- [x] **Reuse already-uploaded icons**: `getUserIcons()` on the `YotoAPI` protocol
      (`GET /media/displayIcons/user/me`); assigning reuses `PixelArt.lastUploadedMediaId`
      when the server still lists it (verified per assign, falls back to a fresh upload),
      so assigning one drawing to several tracks uploads once.
- [x] **Per-track assignment polish**: the assign screen marks tracks already showing the
      art in hand, tracks can be unassigned (swipe or context menu), and a chapter header
      button assigns every track at once with a single upload + card update. (A
      gallery-wide "where is this art used" map would need to scan every card — deferred
      unless it proves needed.)
- [ ] **Shape tools + mirror drawing**: new `DrawingTool` cases with stroke
      start → preview → commit; mirrored coordinate writes in `draw()`.
- [ ] **Browse icons**: one screen for the public Yoto icon library and the user's own
      uploads (`getUserIcons()` already exists); "import as starting point" ships later,
      Pro-gated.
- [ ] Tests alongside each item; add the create → save → (mocked) assign UI happy path once
      the assign UI stabilizes.

## Phase 2 — Animated GIF icons (the marquee)

- [ ] **API spike first, before any UI**: hand-build a 2-frame GIF, upload with
      `Content-Type: image/gif` + `autoConvert=false`, assign it, and confirm it animates on
      a real player. If Yoto rejects GIFs, learn it cheap.
- [ ] Frame storage on `PixelArt` (ordered encoded blob or child `@Model` + relationship —
      CloudKit-safe either way); existing art migrates as frame 1.
- [ ] `gifData(frames:durations:)` exporter via ImageIO, alongside the existing `pngData()`.
- [ ] Editor UI: frame strip (add/duplicate/delete/reorder), onion-skinning, playback
      preview. Canvas stays logic-free; state lives in `EditorViewModel`.
- [ ] Upload path: extend `uploadIcon` for GIF data (`YotoAPIClient` currently hardcodes
      `image/png`).

## Phase 3 — StoreKit 2 + Pro gating

- [ ] `EntitlementService` protocol + live StoreKit 2 actor (`Transaction.currentEntitlements`)
      + mock, injected via `AppEnvironment` like every other dependency.
- [ ] `.storekit` configuration file so purchases are testable locally and in CI.
- [ ] Gate at the feature seams only (GIF export/upload, shape/mirror selection, chapter
      batch assign, library import). Free features never check.
- [ ] Paywall screen ("future tools included" stated explicitly) + tip jar in Settings +
      Family Sharing enabled.
- [ ] Unit tests for gating with the mock entitlement service.

## Phase 4 — App Store launch prep → 1.0

- [ ] Apply the final name: display name, bundle ID, iCloud container, URL scheme in
      `project.yml`; regenerate.
- [ ] **Embedded default client ID** so users just tap "Sign In" (PKCE public client — no
      secret to protect); keep the Settings override for developers.
- [ ] App icon + launch assets (the current `AppIcon` placeholder blocks install).
- [ ] Sign-in UX polish: richer auth error surfacing.
- [ ] CloudKit verification on real devices (set `DEVELOPMENT_TEAM`, provision the
      container, sync between two devices).
- [ ] Store package: privacy manifest, hosted privacy policy, screenshots, App Store
      Connect products (Pro + tips), demo Yoto account + review notes.
- [ ] TestFlight beta via the community (yoto.space, r/yotoplayer, Facebook groups) — this
      doubles as launch marketing. Iterate, then ship 1.0.

## Phase 5 — Post-launch

- [ ] Second tool (candidates: text-to-speech content creation, cover-image editor, MQTT
      player control); new premium tools join the existing Pro unlock.
- [ ] Device-code auth fallback only if client registration proves problematic.
- [ ] Snapshot tests for stabilized screens.

## Risks

| Risk | Mitigation |
| --- | --- |
| No real-user feedback until late (cost of features-first) | Use the app on family devices throughout; keep every phase shippable so scope can be cut and TestFlight moved earlier if momentum stalls |
| Yoto never answers on commercial use | Terms don't prohibit it and paid precedents exist; worst case, launch tip-jar-only and add the Pro unlock once confirmed |
| Yoto API rejects GIF uploads | Phase 2 starts with a throwaway spike before any editor UI work |
| Trademark flag at App Review | "for Yoto" naming + review notes; name finalized before any Connect upload |
