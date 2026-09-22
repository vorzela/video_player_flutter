# video_player_flutter_lint

[`custom_lint`](https://pub.dev/packages/custom_lint) rules for
[video_player_flutter](https://github.com/vorzela/video_player_flutter).

## Install

```yaml
dev_dependencies:
  custom_lint: ^0.8.1
  video_player_flutter_lint:
    path: packages/video_player_flutter_lint
```

```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    - avoid_vorzela_player_controller_in_build
    - prefer_dispose_vorzela_player_controller
    - avoid_http_hls_load
    - avoid_hover_preview_per_list_item
```

```bash
dart run custom_lint
```

## Rules

| Rule | What it catches |
|------|-----------------|
| `avoid_vorzela_player_controller_in_build` | `VorzelaPlayerController()` inside `build` |
| `prefer_dispose_vorzela_player_controller` | `State` with controller field but no `dispose` / `disposePlayer` |
| `avoid_http_hls_load` | `load('http://…')` (plain HTTP HLS) |
| `avoid_hover_preview_per_list_item` | `VorzelaHoverPreview` inside list `itemBuilder` |

## License

MIT
