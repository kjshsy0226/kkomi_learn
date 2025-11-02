// lib/core/bgm_tracks.dart
export 'global_bgm.dart'; // ✅ re-export: GlobalBgm 심볼도 함께 외부로 노출

import 'global_bgm.dart';

const kBgmStoryKey = 'story_theme';
const kBgmStoryAsset = 'audio/bgm/story_theme.mp3';

extension BgmShortcuts on GlobalBgm {
  Future<void> ensureStory({double? volume, bool restart = false}) => ensure(
    asset: kBgmStoryAsset,
    key: kBgmStoryKey,
    loop: true,
    volume: volume,
    restart: restart,
  );

  Future<void> stopStory() => stop();
}
