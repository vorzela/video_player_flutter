#!/usr/bin/env bash
# Regenerate Pigeon bindings for all packages with one pinned version.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
dart pub global activate pigeon 22.7.0 >/dev/null
dart run pigeon --input pigeons/player_api.dart
echo "Pigeon outputs refreshed. Commit Dart + Kotlin + Swift together."
