// lib/core/bgm_tracks.dart
export 'global_bgm.dart'; // ✅ re-export: GlobalBgm 심볼도 외부에 노출

import 'global_bgm.dart';

/// 논리 키(트랙 식별용)
const kBgmStoryKey = 'story_theme';
const kBgmGameKey = 'game_theme';

/// 에셋 경로(확장자 프로젝트에 맞게 통일하세요: mp3/wav)
/// 현재 mp3 기준 — wav이면 파일명만 바꾸면 됨.
const kBgmStoryAsset = 'audio/bgm/story_theme.mp3';
const kBgmGameAsset = 'audio/bgm/game_theme.wav';

extension BgmShortcuts on GlobalBgm {
  /// 스토리 BGM 보장 재생
  Future<void> ensureStory({double? volume, bool restart = false}) => ensure(
    asset: kBgmStoryAsset,
    key: kBgmStoryKey,
    loop: true,
    volume: volume,
    restart: restart,
  );

  /// 현재 스토리 BGM이 재생 중일 때만 정지 (다른 트랙은 방해 X)
  Future<void> stopStory() => stopIfKey(kBgmStoryKey);

  /// 게임 BGM 보장 재생
  Future<void> ensureGame({double? volume, bool restart = false}) => ensure(
    asset: kBgmGameAsset,
    key: kBgmGameKey,
    loop: true,
    volume: volume,
    restart: restart,
  );

  /// 현재 게임 BGM이 재생 중일 때만 정지
  Future<void> stopGame() => stopIfKey(kBgmGameKey);

  /// 현재 어떤 프리셋이냐 (헬퍼)
  bool get isStory => isKey(kBgmStoryKey);
  bool get isGame => isKey(kBgmGameKey);
}

// // lib/core/bgm_tracks.dart
// export 'global_bgm.dart'; // ✅ re-export: GlobalBgm 심볼도 함께 외부로 노출

// import 'global_bgm.dart';

// const kBgmStoryKey = 'story_theme';
// const kBgmStoryAsset = 'audio/bgm/story_theme.mp3';

// extension BgmShortcuts on GlobalBgm {
//   Future<void> ensureStory({double? volume, bool restart = false}) => ensure(
//     asset: kBgmStoryAsset,
//     key: kBgmStoryKey,
//     loop: true,
//     volume: volume,
//     restart: restart,
//   );

//   Future<void> stopStory() => stop();
// }
