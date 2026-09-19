# video_player_flutter

Federated Flutter HLS player built for **low memory** and fast start:

- **Android:** AndroidX Media3 ExoPlayer + HLS, tight `DefaultLoadControl`, Flutter **Texture** (not PlatformView)
- **iOS:** AVPlayer + `AVPlayerItemVideoOutput` texture, peak bitrate caps
- Position events throttled to **250ms**
- `fastStart`: begin on the lowest rung / capped bitrate, then allow ABR to climb

Pairs with the Go [`video`](https://github.com/vorzela/video) + [`hlsstore`](https://github.com/vorzela/hlsstore) pipeline (`master.m3u8`).

## Layout

```
packages/
  video_player_flutter/                      # app-facing API + VorzelaPlayerView
  video_player_flutter_platform_interface/   # abstract platform + MethodChannel
  video_player_flutter_android/              # Media3
  video_player_flutter_ios/                  # AVPlayer
pigeons/player_api.dart                      # Pigeon HostApi (regenerate together)
tool/generate_pigeon.sh
example/
```

Today the live bridge is **MethodChannel / EventChannel** (`com.vorzela.video_player_flutter/...`) matching the Pigeon surface. Run `tool/generate_pigeon.sh` when evolving the API so Dart, Kotlin, and Swift stay on the same Pigeon version (do not split generated halves across mismatched versions).

## Use in an app

```yaml
dependencies:
  video_player_flutter:
    path: path/to/video_player_flutter/packages/video_player_flutter
```

```dart
final c = VorzelaPlayerController();
await c.load(
  'https://cdn.example.com/media/42/master.m3u8',
  poster: 'https://cdn.example.com/media/42/poster.jpg',
  fastStart: true,
  autoPlay: true,
);
// VorzelaPlayerView(controller: c)
await c.setQuality('480p'); // or 'auto'
c.dispose();
```

## Thin Go-video client

See [`video/frontend/flutter.dart`](https://github.com/vorzela/video/blob/main/frontend/flutter.dart) for upload + status poll + `VideoHlsPlayer`.

## Tests

```bash
cd packages/video_player_flutter_platform_interface && flutter test
cd ../video_player_flutter && flutter test
```
