# video_player_flutter

Low-memory HLS player for Flutter — see the [repo README](../../README.md) for install, API, and examples.

## Chrome kit (0.0.8+)

Compose custom controls with `VorzelaSeekBar`, `VorzelaProgressBar`, `VorzelaTimeLabel`, `VorzelaPlayPauseButton`, and `VorzelaMuteButton` via `VorzelaPlayer.controlsBuilder` or a `Stack` around `VorzelaPlayerView`.

## Playlist (0.0.8+)

`VorzelaPlaylistController` queues `VorzelaMediaItem`s on one `VorzelaPlayerController`, auto-advances on completion, and supports repeat / shuffle. Example app: **Queue** icon on the home screen.
