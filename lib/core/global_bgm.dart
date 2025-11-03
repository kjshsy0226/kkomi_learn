// lib/core/global_bgm.dart
import 'package:audioplayers/audioplayers.dart';

/// 앱 전역 BGM(루프 재생) 매니저 - 단일 API로 통일
class GlobalBgm {
  GlobalBgm._();
  static final GlobalBgm instance = GlobalBgm._();

  final AudioPlayer _player = AudioPlayer();
  String? _currentKey; // 논리 키(동일 트랙 判定용)
  String? _currentAsset; // 실제 asset 경로
  bool _ready = false;

  Future<void> _bootstrap({double? volume, bool loop = true}) async {
    if (!_ready) {
      await _player.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release,
      );
      if (volume != null) await _player.setVolume(volume);
      _ready = true;
    } else {
      await _player.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release,
      );
      if (volume != null) await _player.setVolume(volume);
    }
  }

  /// ✅ 유일한 진입점
  ///
  /// - [asset]: mp3/wav asset 경로
  /// - [key]: 논리 키(미지정 시 asset == key)
  /// - [loop]: 기본 true
  /// - [volume]: 0.0~1.0, 지정 시 반영
  /// - [restart]: 같은 트랙이어도 처음부터 다시 재생할지
  Future<void> ensure({
    required String asset,
    String? key,
    bool loop = true,
    double? volume,
    bool restart = false,
  }) async {
    final resolvedKey = key ?? asset;
    await _bootstrap(volume: volume, loop: loop);

    final same = (_currentKey == resolvedKey && _currentAsset == asset);
    if (same && !restart) {
      if (_player.state != PlayerState.playing) {
        await _player.resume();
      }
      return;
    }

    try {
      await _player.stop();
    } catch (_) {}

    _currentKey = resolvedKey;
    _currentAsset = asset;
    await _player.play(AssetSource(asset)); // loop/releaseMode는 위에서 반영됨
  }

  /// 선택: 앱 시작시 미리 호출하고 싶으면 사용
  Future<void> init({double volume = 0.0, bool loop = true}) async {
    await _bootstrap(volume: volume, loop: loop);
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      await _player.resume();
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    _currentKey = null;
    _currentAsset = null;
  }

  /// 현재 재생 키가 [key]와 같으면 정지
  Future<void> stopIfKey(String key) async {
    if (_currentKey == key) {
      await stop();
    }
  }

  /// 현재 트랙이 특정 키인지
  bool isKey(String key) => _currentKey == key;

  Future<void> setVolume(double volume) async =>
      _player.setVolume(volume.clamp(0.0, 1.0));

  bool get isPlaying => _player.state == PlayerState.playing;
  String? get currentKey => _currentKey;
  String? get currentAsset => _currentAsset;
}

// // lib/core/global_bgm.dart
// import 'package:audioplayers/audioplayers.dart';

// /// 앱 전역 BGM(루프 재생) 매니저 - 단일 API로 통일
// class GlobalBgm {
//   GlobalBgm._();
//   static final GlobalBgm instance = GlobalBgm._();

//   final AudioPlayer _player = AudioPlayer();
//   String? _currentKey; // 논리 키(동일 트랙 判定용)
//   String? _currentAsset; // 실제 asset 경로
//   bool _ready = false;

//   Future<void> _bootstrap({double? volume, bool loop = true}) async {
//     if (!_ready) {
//       await _player.setReleaseMode(
//         loop ? ReleaseMode.loop : ReleaseMode.release,
//       );
//       if (volume != null) await _player.setVolume(volume);
//       _ready = true;
//     } else {
//       await _player.setReleaseMode(
//         loop ? ReleaseMode.loop : ReleaseMode.release,
//       );
//       if (volume != null) await _player.setVolume(volume);
//     }
//   }

//   /// ✅ 유일한 진입점
//   ///
//   /// - [asset]: mp3 asset 경로
//   /// - [key]: 논리 키(미지정 시 asset == key)
//   /// - [loop]: 기본 true
//   /// - [volume]: 0.0~1.0, 지정 시 반영
//   /// - [restart]: 같은 트랙이어도 처음부터 다시 재생할지
//   Future<void> ensure({
//     required String asset,
//     String? key,
//     bool loop = true,
//     double? volume,
//     bool restart = false,
//   }) async {
//     final resolvedKey = key ?? asset;
//     await _bootstrap(volume: volume, loop: loop);

//     final same = (_currentKey == resolvedKey && _currentAsset == asset);
//     if (same && !restart) {
//       if (_player.state != PlayerState.playing) {
//         await _player.resume();
//       }
//       return;
//     }

//     try {
//       await _player.stop();
//     } catch (_) {}

//     _currentKey = resolvedKey;
//     _currentAsset = asset;
//     await _player.play(AssetSource(asset)); // loop/releaseMode는 위에서 반영됨
//   }

//   /// 선택: 앱 시작시 미리 호출하고 싶으면 사용
//   Future<void> init({double volume = 1.0, bool loop = true}) async {
//     await _bootstrap(volume: volume, loop: loop);
//   }

//   Future<void> pause() async {
//     try {
//       await _player.pause();
//     } catch (_) {}
//   }

//   Future<void> resume() async {
//     try {
//       await _player.resume();
//     } catch (_) {}
//   }

//   Future<void> stop() async {
//     try {
//       await _player.stop();
//     } catch (_) {}
//     _currentKey = null;
//     _currentAsset = null;
//   }

//   Future<void> setVolume(double volume) async =>
//       _player.setVolume(volume.clamp(0.0, 1.0));

//   bool get isPlaying => _player.state == PlayerState.playing;
//   String? get currentKey => _currentKey;
//   String? get currentAsset => _currentAsset;
// }
