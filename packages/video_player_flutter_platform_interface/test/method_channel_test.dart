import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_flutter_platform_interface/video_player_flutter_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MethodChannelVideoPlayer create/load/dispose', () async {
    final log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(kVorzelaPlayerChannel),
      (call) async {
        log.add(call);
        if (call.method == 'create') return 7;
        return null;
      },
    );

    final platform = MethodChannelVideoPlayer();
    final id = await platform.create();
    expect(id, 7);
    await platform.load(id, uri: 'https://cdn.example/master.m3u8', fastStart: true);
    await platform.disposePlayer(id);

    expect(log.map((c) => c.method), ['create', 'load', 'dispose']);
    final loadArgs = log[1].arguments as Map;
    expect(loadArgs['uri'], 'https://cdn.example/master.m3u8');
    expect(loadArgs['fastStart'], true);
  });

  test('QualityLevel map round-trip', () {
    const q = QualityLevel(index: 1, height: 480, bitrate: 900000, label: '480p');
    expect(QualityLevel.fromMap(q.toMap()), q);
  });
}
