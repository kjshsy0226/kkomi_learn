// lib/core/bgm_tracks.dart
export 'global_bgm.dart'; // ✅ re-export: GlobalBgm 외부 노출

import 'global_bgm.dart';

/// 논리 키(트랙 식별용)
const kBgmIntroKey = 'intro_theme';
const kBgmStoryKey = 'story_theme';
const kBgmGameKey = 'game_theme';

/// 에셋 경로
const kBgmIntroAsset = 'audio/bgm/intro_theme.mp3';
const kBgmStoryAsset = 'audio/bgm/story_theme.mp3';
const kBgmGameAsset = 'audio/bgm/game_theme.wav';

extension BgmShortcuts on GlobalBgm {
  /// ───── 인트로 ─────
  Future<void> ensureIntro({
    double? volume,
    bool restart = false,
    bool loop = true,
  }) => ensure(
    asset: kBgmIntroAsset,
    key: kBgmIntroKey,
    loop: loop,
    volume: volume ?? 0.4,
    restart: restart,
  );
  Future<void> stopIntro() => stopIfKey(kBgmIntroKey);
  bool get isIntro => isKey(kBgmIntroKey);

  /// ───── 스토리 ─────
  Future<void> ensureStory({
    double? volume,
    bool restart = false,
    bool loop = true,
  }) => ensure(
    asset: kBgmStoryAsset,
    key: kBgmStoryKey,
    loop: loop,
    volume: volume ?? 0.4,
    restart: restart,
  );
  Future<void> stopStory() => stopIfKey(kBgmStoryKey);
  bool get isStory => isKey(kBgmStoryKey);

  /// ───── 게임 ─────
  Future<void> ensureGame({
    double? volume,
    bool restart = false,
    bool loop = true,
  }) => ensure(
    asset: kBgmGameAsset,
    key: kBgmGameKey,
    loop: loop,
    volume: volume ?? 0.4,
    restart: restart,
  );
  Future<void> stopGame() => stopIfKey(kBgmGameKey);
  bool get isGame => isKey(kBgmGameKey);
}
