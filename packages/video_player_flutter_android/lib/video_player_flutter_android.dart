import 'package:video_player_flutter_platform_interface/video_player_flutter_platform_interface.dart';

class VideoPlayerFlutterAndroid {
  static void registerWith() {
    MethodChannelVideoPlayer.registerWith();
  }
}
