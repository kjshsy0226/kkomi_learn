// lib/core/global_sfx.dart
import 'package:audioplayers/audioplayers.dart';

class GlobalSfx {
  GlobalSfx._();
  static final GlobalSfx instance = GlobalSfx._();

  final Map<String, AudioPlayer> _players = {};

  /// 데스크톱(macOS/Windows)에서는 AudioContext 설정 불필요.
  Future<void> preload(String key, String asset, {double volume = 0.9}) async {
    final p = AudioPlayer()
      ..setPlayerMode(PlayerMode.lowLatency)
      ..setReleaseMode(ReleaseMode.stop)
      ..setVolume(volume);

    await p.setSourceAsset(asset); // 미리 로드
    _players[key] = p;
  }

  Future<void> play(String key) async {
    final p = _players[key];
    if (p == null) return;
    // 항상 처음부터
    await p.seek(Duration.zero);
    await p.resume();
  }

  Future<void> disposeAll() async {
    for (final p in _players.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}
