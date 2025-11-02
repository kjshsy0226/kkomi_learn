# 이미지 전용

final seqCtrl = SequenceController();
final frames = List.generate(100, (i) => 'assets/images/kkomi*game_base/kkomi_game_base*${i.toString().padLeft(3, '0')}.png');

SequenceSprite(
controller: seqCtrl,
assetPaths: frames,
fps: 24,
loop: true,
autoplay: true,
holdLastFrameWhenFinished: true,
precache: true,
);

# 이미지+사운드

final audioCtrl = SequenceAudioController();
SequenceSpriteAudio(
controller: audioCtrl,
assetPaths: frames,
audioAsset: 'assets/audio/bgm/game_theme.wav',
audioSyncMode: AudioSyncMode.followImageLoopRestart, // 또는 independentLoop/oneShotPerPlay/none
fps: 24,
loop: true,
autoplay: true,
autoplayAudio: true,
holdLastFrameWhenFinished: true,
precache: true,
);

# 재생/정지: await audioCtrl.start();, await audioCtrl.stop();

# 배치 (센터 기준)

Stack(
children: [
AnchoredBox(
position: const Offset(960, 540), // 부모(1920x1080)의 중앙
anchor: Anchor.center,
size: const Size(640, 360),
child: SequenceSprite(controller: seqCtrl, assetPaths: frames, autoplay: true, loop: true),
),
],
);
