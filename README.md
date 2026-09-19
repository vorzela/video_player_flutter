# video_player_flutter

Federated Flutter **HLS** player built for low memory and fast start.

| Platform | Engine | Notes |
|----------|--------|--------|
| Android | AndroidX **Media3 ExoPlayer** + HLS | Tight `DefaultLoadControl` (2–10s buffers) |
| iOS | **AVPlayer** + `AVPlayerItemVideoOutput` | Peak bitrate caps; Flutter **Texture** (not PlatformView) |

- Position / buffer events throttled to **250ms**
- `fastStart`: start low, then let ABR climb
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
            aspectRatio: 16 / 9,
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

---

## License

MIT — see [LICENSE](LICENSE).
