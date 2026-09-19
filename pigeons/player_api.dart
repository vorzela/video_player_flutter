// Pigeon API — regenerate with tool/generate_pigeon.sh (pin same pigeon version).
// Generated Dart + Kotlin + Swift must stay in sync; do not edit outputs by hand
// without regenerating all three packages together.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'packages/video_player_flutter/lib/src/messages.g.dart',
  kotlinOut:
      'packages/video_player_flutter_android/android/src/main/kotlin/com/vorzela/video_player_flutter/Messages.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.vorzela.video_player_flutter'),
  swiftOut:
      'packages/video_player_flutter_ios/ios/Classes/Messages.g.swift',
  dartPackageName: 'video_player_flutter',
))
class LoadRequest {
  late int playerId;
  late String uri;
  String? poster;
  bool? autoPlay;
  bool? fastStart;
  bool? capToPlayerSize;
  int? viewWidth;
  int? viewHeight;
}

class QualityLevelMsg {
  late int index;
  late int height;
  late int bitrate;
  late String label;
}

@HostApi()
abstract class PlayerHostApi {
  int create();
  void load(LoadRequest request);
  void play(int playerId);
  void pause(int playerId);
  void seek(int playerId, int positionMs);
  void setVolume(int playerId, double volume);
  void setQuality(int playerId, String quality);
  List<QualityLevelMsg> getLevels(int playerId);
  void dispose(int playerId);
}
