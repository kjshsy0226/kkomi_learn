// lib/utils/sfx_pool.dart
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

class SfxPool {
  SfxPool._();
  static final SfxPool I = SfxPool._();

  final int _poolSize = 4; // 동시재생 여유
  final List<AudioPlayer> _pool = [];
  int _idx = 0;

  Uint8List? _tapBytes;

  bool get _ready => _tapBytes != null && _pool.isNotEmpty;

  Future<void> ensureLoaded() async {
    if (_ready) return;

    // 1) 버튼음 파일을 메모리에 올려둠 (파일 I/O 제거 → 첫 탭 지연/누락 방지)
    final data = await rootBundle.load('assets/audio/sfx/btn_tap.mp3');
    _tapBytes = data.buffer.asUint8List();

    // 2) 저지연 플레이어 풀 구성
    for (int i = 0; i < _poolSize; i++) {
      final p = AudioPlayer()
        ..setPlayerMode(PlayerMode.lowLatency)
        ..setReleaseMode(ReleaseMode.stop)
        ..setVolume(0.9);
      _pool.add(p);
    }
  }

  Future<void> tap() async {
    // 게으른 초기화: 혹시 ensureLoaded()를 안 불렀어도 안전하게
    if (!_ready) {
      try {
        await ensureLoaded();
      } catch (_) {
        /* ignore */
      }
    }
    if (!_ready) return;

    final p = _pool[_idx++ % _pool.length];
    try {
      await p.play(BytesSource(_tapBytes!)); // 파일 대신 메모리에서 즉시 재생
    } catch (_) {
      // 실패해도 앱 흐름 방해하지 않음
    }
  }

  Future<void> dispose() async {
    for (final p in _pool) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _pool.clear();
    _tapBytes = null;
  }
}
