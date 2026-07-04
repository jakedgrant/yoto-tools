# Future Work

Deferred features and ideas, roughly in priority order. Pick items up here rather than
re-deriving scope. See `CLAUDE.md` for current architecture and
[`ROADMAP.md`](./ROADMAP.md) for the sequenced release plan (which phase each of these
lands in) and the monetization strategy.

## Pixel Art tool

- **Animated GIF icons (multi-frame).** Yoto track icons may be animated GIFs. Add
  multi-frame editing (frame timeline, per-frame canvas, playback preview) and export an
  animated GIF instead of a single PNG. Touches:
  - `PixelArt` model → store an ordered list of frames + per-frame duration (CloudKit-safe:
    model frames as a separate `@Model` with a relationship, or an encoded blob).
  - `PixelGrid` → add a `gifData(frames:durations:)` exporter (ImageIO supports
    `kUTTypeGIF` with `kCGImagePropertyGIFDictionary`).
  - `IconAssignmentService` / `uploadIcon` → send `image/gif`; the `display.icon16x16`
    reference mechanism is unchanged.
  - Editor UI → frame strip, add/duplicate/delete/reorder frames, onion-skinning.
- **Reuse already-uploaded icons.** Call `GET /media/displayIcons/user/me` to show the
  user's previously uploaded icons and skip re-uploading unchanged art (we already cache
  `PixelArt.lastUploadedMediaId`).
- **Browse/import the public Yoto icon library** as starting points.
- **More editor tools:** line/rectangle/ellipse shapes, mirror/symmetry drawing, move/shift
  canvas, color replace, larger configurable brush.
- **Per-track assignment polish:** assign to a whole chapter at once; show which local art
  is already assigned to which track; unassign/reset to default.

## App / platform

- **Additional Yoto tools in the host** (the `Tool` enum + split-view shell are built to
  extend): player control via MQTT, text-to-speech content creation, cover-image editor.
- **Device-code auth fallback.** Only the PKCE public-client flow is implemented. If a Yoto
  app can't be registered as a native/public client, add the device-code flow (same token
  endpoint, no redirect URI).
- **App icon + launch assets.** `AppIcon` is an empty placeholder.
- **CloudKit provisioning.** The container falls back to a local store when iCloud is
  unavailable; verify sync on real devices with a configured iCloud container + team.
- **Sign-in UX:** surface auth errors more richly; optional ephemeral session is wired but
  could be exposed more prominently.

## Testing / tooling

- **Snapshot tests** for key screens (editor, gallery, assign list).
