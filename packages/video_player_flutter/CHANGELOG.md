# Changelog

## 0.0.8

### Added
- **Seek / progress chrome kit** — `VorzelaSeekBar` (drag + buffered trail),
  `VorzelaProgressBar`, `VorzelaTimeLabel`, `VorzelaPlayPauseButton`,
  `VorzelaMuteButton` for composing custom controls with
  [VorzelaPlayer.controlsBuilder].
- **Playlist** — `VorzelaPlaylistController`, `VorzelaMediaItem`,
  `VorzelaRepeatMode`, optional `VorzelaPlaylistView`; single shared native
  player, auto-advance on completed.

## 0.0.7

### Added
- **Player customizability** — `controlsBuilder`, `overlayBuilder`,
  `bufferingBuilder`, `posterBuilder`, `VorzelaPlayerStyle`, `chromeHideAfter`,
  `onTap`; same builders on `VorzelaFullscreen.open`.
- **Hover customizability** — `posterBuilder`, `overlayBuilder`, `frameBuilder`,
  `enableDefaultGestures`, hover/tap callbacks, `semanticLabel`.
- **Semantics** on default chrome (play/mute/seek/fullscreen, buffering live
  region, player status).
- Posters via **`vorzela_image`** (decode caps) instead of raw `Image.network`.

## 0.0.6

### Added
- **Memory contract tests** — fake-platform checks that reload / preview
  session never stack native players; idle dispose; decode size + quality caps
  (`test/vorzela_memory_contract_test.dart`).
- **`packages/video_player_flutter_lint`** — `custom_lint` rules for controller
  lifecycle, HTTPS HLS, and shared hover preview usage.

## 0.0.5

See git history for earlier notes.
