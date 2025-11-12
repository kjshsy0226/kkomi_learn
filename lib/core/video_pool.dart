// lib/core/video_pool.dart
import 'package:video_player/video_player.dart';

class VideoPair {
  final VideoPlayerController intro;
  final VideoPlayerController loop;
  VideoPair(this.intro, this.loop);

  Future<void> dispose() async {
    try {
      intro.removeListener(() {});
      await intro.dispose();
    } catch (_) {}
    try {
      await loop.dispose();
    } catch (_) {}
  }
}

class VideoPool {
  VideoPool._();
  static final VideoPool I = VideoPool._();

  /// 진행 중/완료된 프리로드 태스크
  final Map<String, Future<VideoPair>> _tasks = {};

  /// 같은 key에 대해 한 번만 초기화/워밍업 수행
  Future<VideoPair> preloadAssetPair({
    required String key,
    required String introPath,
    required String loopPath,
  }) {
    return _tasks.putIfAbsent(key, () async {
      final intro = VideoPlayerController.asset(introPath)..setLooping(false);
      final loop  = VideoPlayerController.asset(loopPath)..setLooping(true);

      // 초기화
      await Future.wait([intro.initialize(), loop.initialize()]);

      // 워밍업(첫 프레임/디코더 깨우기)
      await intro.play(); await intro.pause();
      await loop.play();  await loop.pause();

      return VideoPair(intro, loop);
    });
  }

  /// 프리로드가 끝난 쌍을 가져오고 풀에서는 제거.
  /// (가져간 쪽이 dispose 책임)
  Future<VideoPair?> take(String key) async {
    final task = _tasks.remove(key);
    return task == null ? null : await task;
  }

  /// 필요 시 특정 key의 프리로드 취소/정리
  Future<void> cancel(String key) async {
    final task = _tasks.remove(key);
    if (task != null) {
      try {
        final pair = await task;
        await pair.dispose();
      } catch (_) {}
    }
  }

  /// 전체 정리
  Future<void> clear() async {
    final tasks = _tasks.values.toList();
    _tasks.clear();
    for (final t in tasks) {
      try {
        final p = await t;
        await p.dispose();
      } catch (_) {}
    }
  }
}
