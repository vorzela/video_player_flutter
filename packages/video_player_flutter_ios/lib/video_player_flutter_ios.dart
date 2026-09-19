import 'package:video_player_flutter_platform_interface/video_player_flutter_platform_interface.dart';

class VideoPlayerFlutterIOS {
  static void registerWith() {
    MethodChannelVideoPlayer.registerWith();
  }
}
