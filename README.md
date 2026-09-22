# video_player_flutter

Federated Flutter **HLS** player built for low memory and fast start.

| Platform | Engine | Notes |
|----------|--------|--------|
| Android | AndroidX **Media3 ExoPlayer** + HLS | Tight `DefaultLoadControl` (2–10s buffers) |
| iOS | **AVPlayer** + `AVPlayerItemVideoOutput` | Peak bitrate caps; Flutter **Texture** (not PlatformView) |
| Web / desktop | — | **Not shipped** — use the platform’s usual players on web |

- Position / buffer events throttled to **250ms**
- `fastStart`: start low, then let ABR climb
- `VorzelaPlayer` — tap play/pause, fullscreen + auto-rotate, mute chrome
- Pauses in background by default; **opt-in** Android PiP to play over other apps
- `VorzelaHoverPreview` — one shared low-res player, mute/unmute, Android/iOS
- Pairs with Go [`video`](https://github.com/vorzela/video) + [`hlsstore`](https://github.com/vorzela/hlsstore) (`master.m3u8`)

**License:** MIT  
**Repo:** https://github.com/vorzela/video_player_flutter

---

## Install

```yaml
dependencies:
  video_player_flutter:
    git:
      url: https://github.com/vorzela/video_player_flutter.git
      path: packages/video_player_flutter
    # or local:
    # path: ../video_player_flutter/packages/video_player_flutter
```

```dart
import 'package:video_player_flutter/video_player_flutter.dart';
```

---

## Quick start

```dart
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.hlsUrl, this.poster});
  final String hlsUrl;
  final String? poster;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final controller = VorzelaPlayerController();

  @override
  void initState() {
    super.initState();
    controller.load(
      widget.hlsUrl,
      poster: widget.poster,
      fastStart: true,
      autoPlay: true,
    );
  }

  @override
  void dispose() {
    controller.dispose(); // releases native ExoPlayer / AVPlayer + texture
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        children: [
          AspectRatio(
            // Uses decoded size once ready; falls back until then.
            aspectRatio: controller.videoAspectRatio ?? 1,
            child: VorzelaPlayerView(controller: controller),
          ),
          if (controller.isBuffering) const LinearProgressIndicator(),
          Text('${controller.position} / ${controller.duration}'),
          Wrap(
            children: [
              for (final level in controller.levels)
                TextButton(
                  onPressed: () => controller.setQuality(level.label),
                  child: Text(level.label),
                ),
              TextButton(
                onPressed: () => controller.setQuality('auto'),
                child: const Text('auto'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

Always call `controller.dispose()` (or `disposePlayer()`) when leaving the screen — same pattern as disposing a `TextEditingController`.

### Full player chrome

```dart
final controller = VorzelaPlayerController(
  pauseOnBackground: true,       // default — stop when app backgrounds
  allowsPictureInPicture: false, // opt-in Android PiP over other apps
);

// Tap = play/pause (YouTube). Fullscreen button unlocks auto-rotate.
VorzelaPlayer(
  controller: controller,
  tapAction: VorzelaTapAction.playPause,
  autoRotateInFullscreen: true,
);

// Or open fullscreen yourself:
await VorzelaFullscreen.open(context, controller: controller);
```

| Tap action | Behavior |
|------------|----------|
| `playPause` (default) | Toggle play / pause |
| `toggleMute` | Mute / unmute |
| `fullscreen` | Enter fullscreen |
| `none` | Host handles gestures |

**PiP (opt-in):** set `allowsPictureInPicture: true`. On Android, backgrounding may enter Activity PiP instead of pausing. Declare on your app `Activity`:

```xml
android:supportsPictureInPicture="true"
```

iOS texture PiP is not implemented (returns unsupported). No floating “draw over other apps” overlay permission is required unless you add that yourself.

---

## Package layout

```
packages/
  video_player_flutter/                      # app-facing API + VorzelaPlayerView
  video_player_flutter_platform_interface/   # DTOs + MethodChannel bridge
  video_player_flutter_android/              # Media3
  video_player_flutter_ios/                  # AVPlayer
pigeons/player_api.dart
tool/generate_pigeon.sh
example/
```

Channels: `com.vorzela.video_player_flutter/player` and `…/events`.  
Regenerate Pigeon with `tool/generate_pigeon.sh` (keep Dart + Kotlin + Swift on the **same** Pigeon version).

---

## API reference

### `VorzelaPlayerController`

| Member | Type | Description |
|--------|------|-------------|
| `VorzelaPlayerController({VideoPlayerPlatform? platform})` | constructor | Uses platform instance; inject fake platform in tests |
| `load(uri, {poster, autoPlay, fastStart, capToPlayerSize, viewWidth, viewHeight})` | `Future<void>` | Create native player, load **https** HLS master URL (errors → `error` field) |
| `play()` | `Future<void>` | Resume playback |
| `pause()` | `Future<void>` | Pause playback |
| `seek(Duration to)` | `Future<void>` | Seek |
| `setVolume(double volume)` | `Future<void>` | `0.0`–`1.0` |
| `setQuality(String quality)` | `Future<void>` | `"auto"` or label like `"480p"` |
| `disposePlayer()` | `Future<void>` | Tear down native player; safe to call before `load` again |
| `dispose()` | `void` | `ChangeNotifier.dispose` + `disposePlayer()` |
| `videoAspectRatio` | `double?` | Real width/height once known (portrait, landscape, square) |
| `videoWidth` / `videoHeight` | `int` | Decoded frame size |

**Observable fields** (via `Listenable` / `ListenableBuilder`):

| Field | Type | Description |
|-------|------|-------------|
| `textureId` | `int?` | Flutter texture id when ready |
| `isReady` | `bool` | Manifest loaded / first frame path ready |
| `isBuffering` | `bool` | Stalled for data |
| `isPlaying` | `bool` | Play-when-ready / playing |
| `position` | `Duration` | Current position (≈250ms updates) |
| `duration` | `Duration` | Media duration |
| `buffered` | `Duration` | Buffered ahead |
| `levels` | `List<QualityLevel>` | ABR rungs from master playlist |
| `currentQuality` | `String` | Last `setQuality` value (`auto` default) |
| `error` | `String?` | Fatal / load error message |
| `poster` | `String?` | Poster URL passed to `load` |
| `videoAspectRatio` | `double?` | From native `videoWidth`/`videoHeight` |

### `VorzelaPlayerView`

| Member | Description |
|--------|-------------|
| `VorzelaPlayerView({required controller, fit})` | Texture view sized to **real** video aspect (not fixed 16:9); poster until ready |
| `controller` | `VorzelaPlayerController` |
| `fit` | `BoxFit` (default `contain`) |

### `VorzelaHoverPreview`

YouTube-style thumbnail preview on **hover** (or **long-press** on touch).  
**Android/iOS only** — on web use another player.

```dart
VorzelaHoverPreview(
  uri: 'https://cdn.example.com/v/123/preview.m3u8', // short clip
  poster: 'https://cdn.example.com/v/123/poster.jpg',
  muted: true,          // default — tap to unmute while previewing
  volume: 1.0,
  maxDecodeHeight: 360, // keep RAM low
  lowQuality: true,     // pin lowest HLS rung
  previewDuration: const Duration(seconds: 5),
)
```

| Member | Default | Description |
|--------|---------|-------------|
| `muted` | `true` | Start silent (tap toggles if `tapTogglesMute`) |
| `volume` | `1.0` | Level when unmuted |
| `tapTogglesMute` | `true` | Tap preview to mute/unmute |
| `maxDecodeHeight` | `360` | Cap decode / ABR for previews |
| `lowQuality` | `true` | Stay on cheapest ladder rung |
| `startDelay` | `280ms` | Debounce mouse sweeps |
| `loop` | `true` | Loop first `previewDuration` |
| `onMuteChanged` | — | `(bool muted)` callback |

**Memory:** all tiles share **one** [VorzelaPreviewSession] native player. Exit → pause; idle ~800ms → full dispose. Prefer short preview assets, not the full feature master.

For TikTok-style feeds, drive play/pause from scroll visibility on a single full player — don’t spawn a hover player per row.

### `QualityLevel` (platform interface)

| Field | Type | Description |
|-------|------|-------------|
| `index` | `int` | Ladder index |
| `height` | `int` | e.g. `480` |
| `bitrate` | `int` | bits/s |
| `label` | `String` | e.g. `"480p"` |
| `toMap()` / `fromMap()` | | Channel serialization |

### Player events (platform interface)

| Type | Fields | When |
|------|--------|------|
| `PlayerReadyEvent` | `textureId`, `durationMs`, `levels`, `videoWidth`, `videoHeight` | Ready / size update |
| `PlayerBufferingEvent` | `isBuffering` | Buffer state change |
| `PlayerPositionEvent` | `positionMs`, `bufferedMs` | Throttled progress |
| `PlayerErrorEvent` | `message` | Fatal error |
| `PlayerCompletedEvent` | — | End of stream |

Events from **all** players share one EventChannel; Dart filters by `playerId` so feeds with multiple preloaded players work.

**URI policy:** native `load` accepts **https:// only**.

### `VideoPlayerPlatform` (for tests / custom hosts)

| Method | Description |
|--------|-------------|
| `create()` → `int` | Allocate player id |
| `load(playerId, {uri, …})` | Load media |
| `play` / `pause` / `seek` / `setVolume` / `setQuality` | Control |
| `getLevels(playerId)` | Quality list |
| `disposePlayer(playerId)` | Release |
| `eventsFor(playerId)` | `Stream<PlayerEvent>` |
| `VideoPlayerPlatform.instance` | Override with a fake in unit tests |

### Constants

| Name | Value |
|------|--------|
| `kVorzelaPlayerChannel` | `com.vorzela.video_player_flutter/player` |
| `kVorzelaPlayerEventsChannel` | `com.vorzela.video_player_flutter/events` |
| `kPositionEventThrottleMs` | `250` |

---

## Backend pairing

Upload / job polling helpers live in the Go video package’s Flutter client:

https://github.com/vorzela/video/blob/main/frontend/flutter.dart  
(`VideoUploadClient`, `VideoStatusClient`, `VideoHlsPlayer`)

---

## Example app

```bash
cd example && flutter run
```

Default stream: Mux public HLS test URL (see `example/lib/main.dart`).

---

## Tests

```bash
cd packages/video_player_flutter_platform_interface && flutter test
cd ../video_player_flutter && flutter test
```

Memory **contracts** (fake platform — no device): reload never stacks native
players; preview session stays at ≤1 active player; idle ~800ms dispose;
decode capped to preview size / lowest quality.

```bash
cd packages/video_player_flutter && flutter test test/vorzela_memory_contract_test.dart
```

---

## Linter (best practices)

Use [`video_player_flutter_lint`](packages/video_player_flutter_lint) with
`custom_lint` ^0.8.1:

- no `VorzelaPlayerController()` inside `build`
- dispose the controller in `State.dispose`
- HTTPS-only HLS `load`
- no `VorzelaHoverPreview` inside ListView/GridView `itemBuilder`

See [packages/video_player_flutter_lint/README.md](packages/video_player_flutter_lint/README.md).

---

## License

MIT — see [LICENSE](LICENSE).
