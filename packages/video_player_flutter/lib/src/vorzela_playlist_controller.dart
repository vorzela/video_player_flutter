import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player_flutter_platform_interface/video_player_flutter_platform_interface.dart';

import 'vorzela_player_controller.dart';

/// One entry in a [VorzelaPlaylistController] queue.
@immutable
class VorzelaMediaItem {
  const VorzelaMediaItem({
    required this.uri,
    this.title,
    this.poster,
  });

  final String uri;
  final String? title;
  final String? poster;
}

enum VorzelaRepeatMode { off, one, all }

class _PlaylistEventPlatform extends VideoPlayerPlatform {
  _PlaylistEventPlatform(this._delegate);

  final VideoPlayerPlatform _delegate;
  void Function(PlayerEvent event)? onEvent;

  @override
  Future<int> create() => _delegate.create();

  @override
  Future<void> load(
    int playerId, {
    required String uri,
    String? poster,
    bool autoPlay = false,
    bool fastStart = true,
    bool capToPlayerSize = true,
    int? viewWidth,
    int? viewHeight,
  }) =>
      _delegate.load(
        playerId,
        uri: uri,
        poster: poster,
        autoPlay: autoPlay,
        fastStart: fastStart,
        capToPlayerSize: capToPlayerSize,
        viewWidth: viewWidth,
        viewHeight: viewHeight,
      );

  @override
  Future<void> play(int playerId) => _delegate.play(playerId);

  @override
  Future<void> pause(int playerId) => _delegate.pause(playerId);

  @override
  Future<void> seek(int playerId, int positionMs) =>
      _delegate.seek(playerId, positionMs);

  @override
  Future<void> setVolume(int playerId, double volume) =>
      _delegate.setVolume(playerId, volume);

  @override
  Future<void> setQuality(int playerId, String quality) =>
      _delegate.setQuality(playerId, quality);

  @override
  Future<List<QualityLevel>> getLevels(int playerId) =>
      _delegate.getLevels(playerId);

  @override
  Future<void> disposePlayer(int playerId) =>
      _delegate.disposePlayer(playerId);

  @override
  Future<bool> enterPictureInPicture(int playerId) =>
      _delegate.enterPictureInPicture(playerId);

  @override
  Future<bool> isPictureInPictureSupported() =>
      _delegate.isPictureInPictureSupported();

  @override
  Stream<PlayerEvent> eventsFor(int playerId) {
    return _delegate.eventsFor(playerId).map((event) {
      onEvent?.call(event);
      return event;
    });
  }
}

/// Queue navigation around a single shared [VorzelaPlayerController].
///
/// Only one native player exists at a time — each track change calls
/// [VorzelaPlayerController.load], which disposes the previous player.
class VorzelaPlaylistController extends ChangeNotifier {
  VorzelaPlaylistController({
    VorzelaPlayerController? player,
    VideoPlayerPlatform? platform,
    this.pauseOnBackground = true,
    this.allowsPictureInPicture = false,
  }) : _ownsPlayer = player == null {
    _playerListener = _onPlayerUpdate;
    if (player != null) {
      this.player = player;
    } else {
      _eventPlatform = _PlaylistEventPlatform(
        platform ?? VideoPlayerPlatform.instance,
      )..onEvent = _onPlatformEvent;
      this.player = VorzelaPlayerController(
        platform: _eventPlatform,
        pauseOnBackground: pauseOnBackground,
        allowsPictureInPicture: allowsPictureInPicture,
      );
    }
    this.player.addListener(_playerListener);
  }

  VorzelaPlaylistController._wrap(this.player)
      : _ownsPlayer = false,
        pauseOnBackground = player.pauseOnBackground,
        allowsPictureInPicture = player.allowsPictureInPicture {
    _playerListener = _onPlayerUpdate;
    player.addListener(_playerListener);
  }

  /// Wrap an existing controller (playlist does not dispose it).
  factory VorzelaPlaylistController.wrap(VorzelaPlayerController player) {
    return VorzelaPlaylistController._wrap(player);
  }

  late final VorzelaPlayerController player;
  _PlaylistEventPlatform? _eventPlatform;
  final bool pauseOnBackground;
  final bool allowsPictureInPicture;
  final bool _ownsPlayer;

  final List<VorzelaMediaItem> _queue = [];
  List<int> _order = [];
  int _orderIndex = 0;
  VorzelaRepeatMode _repeatMode = VorzelaRepeatMode.off;
  bool _shuffle = false;
  bool _completedHandled = true;
  bool _advancing = false;
  late final VoidCallback _playerListener;

  void _onPlatformEvent(PlayerEvent event) {
    if (event is PlayerCompletedEvent) {
      if (!_completedHandled && !_advancing) {
        _completedHandled = true;
        unawaited(_handleTrackCompleted());
      }
    }
  }

  List<VorzelaMediaItem> get queue => List.unmodifiable(_queue);

  int get currentIndex =>
      _order.isEmpty ? -1 : _order[_orderIndex.clamp(0, _order.length - 1)];

  VorzelaMediaItem? get currentItem {
    final i = currentIndex;
    if (i < 0 || i >= _queue.length) return null;
    return _queue[i];
  }

  VorzelaRepeatMode get repeatMode => _repeatMode;

  set repeatMode(VorzelaRepeatMode value) {
    if (_repeatMode == value) return;
    _repeatMode = value;
    notifyListeners();
  }

  bool get shuffle => _shuffle;

  set shuffle(bool value) {
    if (_shuffle == value) return;
    _shuffle = value;
    _rebuildOrder(keepCurrent: true);
    notifyListeners();
  }

  /// Replace the queue and optionally start at [startIndex].
  Future<void> setQueue(
    List<VorzelaMediaItem> items, {
    int startIndex = 0,
  }) async {
    _queue
      ..clear()
      ..addAll(items);
    _rebuildOrder(startIndex: startIndex.clamp(0, max(0, items.length - 1)));
    if (_queue.isEmpty) {
      await player.disposePlayer();
      notifyListeners();
      return;
    }
    await playAt(currentIndex, autoPlay: true);
  }

  Future<void> playAt(int index, {bool autoPlay = true}) async {
    if (index < 0 || index >= _queue.length) return;
    _orderIndex = _order.indexOf(index);
    if (_orderIndex < 0) {
      _rebuildOrder(startIndex: index);
      _orderIndex = _order.indexOf(index);
    }
    final item = _queue[index];
    _completedHandled = false;
    await player.load(
      item.uri,
      poster: item.poster,
      autoPlay: autoPlay,
    );
    notifyListeners();
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_orderIndex < _order.length - 1) {
      _orderIndex++;
      await playAt(_order[_orderIndex]);
      return;
    }
    if (_repeatMode == VorzelaRepeatMode.all) {
      _orderIndex = 0;
      await playAt(_order[_orderIndex]);
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (player.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
      return;
    }
    if (_orderIndex > 0) {
      _orderIndex--;
      await playAt(_order[_orderIndex]);
      return;
    }
    if (_repeatMode == VorzelaRepeatMode.all) {
      _orderIndex = _order.length - 1;
      await playAt(_order[_orderIndex]);
    }
  }

  void _rebuildOrder({int startIndex = 0, bool keepCurrent = false}) {
    final n = _queue.length;
    if (n == 0) {
      _order = [];
      _orderIndex = 0;
      return;
    }
    final current = keepCurrent ? currentIndex : startIndex;
    _order = List.generate(n, (i) => i);
    if (_shuffle && n > 1) {
      _order.shuffle(Random());
      if (current >= 0 && current < n) {
        _order.remove(current);
        _order.insert(0, current);
      }
    }
    _orderIndex = current >= 0 ? _order.indexOf(current) : 0;
    if (_orderIndex < 0) _orderIndex = 0;
  }

  void _onPlayerUpdate() {
    notifyListeners();
  }

  Future<void> _handleTrackCompleted() async {
    if (_advancing) return;
    _advancing = true;
    try {
      switch (_repeatMode) {
        case VorzelaRepeatMode.one:
          _completedHandled = false;
          await player.seek(Duration.zero);
          await player.play();
        case VorzelaRepeatMode.all:
          _completedHandled = false;
          await next();
        case VorzelaRepeatMode.off:
          if (_orderIndex < _order.length - 1) {
            _completedHandled = false;
            await next();
          }
      }
    } finally {
      _advancing = false;
    }
  }

  @override
  void dispose() {
    player.removeListener(_playerListener);
    if (_ownsPlayer) {
      player.dispose();
    }
    super.dispose();
  }
}

typedef VorzelaPlaylistItemBuilder = Widget Function(
  BuildContext context,
  VorzelaMediaItem item,
  int index,
  bool isCurrent,
);

/// Simple selectable list bound to [VorzelaPlaylistController].
class VorzelaPlaylistView extends StatelessWidget {
  const VorzelaPlaylistView({
    super.key,
    required this.controller,
    required this.itemBuilder,
  });

  final VorzelaPlaylistController controller;
  final VorzelaPlaylistItemBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final current = controller.currentIndex;
        return ListView.builder(
          itemCount: controller.queue.length,
          itemBuilder: (context, index) {
            final item = controller.queue[index];
            return InkWell(
              onTap: () => unawaited(controller.playAt(index)),
              child: itemBuilder(
                context,
                item,
                index,
                index == current,
              ),
            );
          },
        );
      },
    );
  }
}
