// lib/widgets/fruit_play_stage.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/learn_fruit.dart';
import '../widgets/shine_emphasis.dart';

class FruitPlayStage extends StatefulWidget {
  const FruitPlayStage({
    super.key,
    required this.fruit,
    required this.isSlice,
    required this.isLikeVideo,
    required this.onCanvasTap,
  });

  final LearnFruit fruit;
  final bool isSlice; // false: whole, true: slice
  final bool isLikeVideo; // false: curious, true: like(끝나면 like_loop)
  final VoidCallback onCanvasTap;

  @override
  State<FruitPlayStage> createState() => _FruitPlayStageState();
}

enum _ActiveLayer { curious, like, likeLoop }

class _FruitPlayStageState extends State<FruitPlayStage> {
  // ── 튜닝 포인트: 엔드 감지 여유(플랫폼별 position/duration 엣지 보정)
  static const Duration _kEndSlack = Duration(milliseconds: 160);

  final ShineEmphasisController _shine = ShineEmphasisController();

  // videos(현재 세트)
  VideoPlayerController? _curiousC;
  VideoPlayerController? _likeC;
  VideoPlayerController? _likeLoopC;

  // 다음 세트 준비용
  VideoPlayerController? _nextCuriousC;
  VideoPlayerController? _nextLikeC;
  VideoPlayerController? _nextLikeLoopC;

  Future<void>? _initFuture;
  VoidCallback? _likeEndListener;
  Timer? _likeEndTimer; // ✅ 플랫폼 보정용 타임아웃

  _ActiveLayer _active = _ActiveLayer.curious;
  bool _ready = false;

  // 세트 스왑 중 레이어 전환 차단 가드
  bool _swappingSet = false;

  // images
  ImageProvider _bgImage = const AssetImage('');
  ImageProvider? _trayImage;
  ImageProvider? _wholeImage;
  ImageProvider? _sliceImage;

  // 🔸 initState에서는 precache를 호출하지 않는다!
  @override
  void initState() {
    super.initState();
    _replayShine();
  }

  // 🔸 MediaQuery 의존이 가능한 시점에서 최초 프리캐시 + 세트 준비
  bool _bootstrapped = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      _prepareSetAndImages(
        widget.fruit,
        jumpTo: widget.isLikeVideo ? _ActiveLayer.like : _ActiveLayer.curious,
      );
    }
  }

  @override
  void didUpdateWidget(covariant FruitPlayStage old) {
    super.didUpdateWidget(old);

    // ✅ 1) 과일 변경을 "먼저" 처리
    if (old.fruit != widget.fruit) {
      _swappingSet = true; // 전환 중에는 레이어 스위치 막기
      _prepareSetAndImages(
        widget.fruit,
        jumpTo: widget.isLikeVideo ? _ActiveLayer.like : _ActiveLayer.curious,
      ).whenComplete(() {
        _swappingSet = false; // 스왑 완료 후 해제
      });

      // 과일이 바뀌는 프레임에 isLikeVideo 변경이 와도 무시(깜빡임 방지)
      return;
    }

    // ✅ 2) 같은 과일 내 curious ↔ like 전환만 처리 (스왑 중이면 무시)
    if (!_swappingSet && old.isLikeVideo != widget.isLikeVideo && _ready) {
      _switchActive(
        widget.isLikeVideo ? _ActiveLayer.like : _ActiveLayer.curious,
      );
    }

    // 시각(whole/slice) 변경 시 샤인 재생
    if (old.isSlice != widget.isSlice) {
      _replayShine();
    }
  }

  @override
  void dispose() {
    _cancelLikeTimer();
    _removeLikeListener();
    _disposeSet(_curiousC, _likeC, _likeLoopC);
    _disposeSet(_nextCuriousC, _nextLikeC, _nextLikeLoopC);
    super.dispose();
  }

  // ───────── images: precache helpers ─────────
  Future<void> _precacheFruitImages(BuildContext ctx, LearnFruit f) async {
    final bg = AssetImage(learnbackgroundPath(f));
    final tray = AssetImage(learnTrayPath(f));
    final whole = AssetImage(learnNormalPath(f));
    final slice = AssetImage(learnHalfPath(f));

    await Future.wait([
      precacheImage(bg, ctx),
      precacheImage(tray, ctx),
      precacheImage(whole, ctx),
      precacheImage(slice, ctx),
    ]);

    _bgImage = bg;
    _trayImage = tray;
    _wholeImage = whole;
    _sliceImage = slice;
  }

  // ───────── videos: lifecycle ─────────
  void _disposeSet(
    VideoPlayerController? a,
    VideoPlayerController? b,
    VideoPlayerController? c,
  ) {
    a?.dispose();
    b?.dispose();
    c?.dispose();
  }

  void _removeLikeListener() {
    if (_likeC != null && _likeEndListener != null) {
      _likeC!.removeListener(_likeEndListener!);
      _likeEndListener = null;
    }
  }

  void _cancelLikeTimer() {
    _likeEndTimer?.cancel();
    _likeEndTimer = null;
  }

  Future<void> _prepareSetAndImages(
    LearnFruit f, {
    required _ActiveLayer jumpTo,
  }) async {
    // 1) 이미지 선로딩 (didChangeDependencies 이후라 MediaQuery OK)
    await _precacheFruitImages(context, f);

    // 2) 다음 비디오 컨트롤러 생성
    _disposeSet(_nextCuriousC, _nextLikeC, _nextLikeLoopC);
    _nextCuriousC = VideoPlayerController.asset(learnCuriousVideo(f));
    _nextLikeC = VideoPlayerController.asset(learnLikeVideo(f));
    _nextLikeLoopC = VideoPlayerController.asset(learnLikeLoopVideo(f));

    // 3) 비디오 3종 initialize + 텍스처 워밍업
    _initFuture =
        Future.wait([
          _nextCuriousC!.initialize(),
          _nextLikeC!.initialize(),
          _nextLikeLoopC!.initialize(),
        ]).then((_) async {
          if (!mounted) return;

          _nextCuriousC!
            ..setLooping(true)
            ..play()
            ..pause()
            ..seekTo(Duration.zero);
          _nextLikeC!
            ..setLooping(false)
            ..play()
            ..pause()
            ..seekTo(Duration.zero);
          _nextLikeLoopC!
            ..setLooping(true)
            ..play()
            ..pause()
            ..seekTo(Duration.zero);

          // 4) 기존 세트 보존 상태에서 스왑
          final oldCur = _curiousC;
          final oldLike = _likeC;
          final oldLoop = _likeLoopC;

          _cancelLikeTimer();
          _removeLikeListener();

          _curiousC = _nextCuriousC;
          _likeC = _nextLikeC;
          _likeLoopC = _nextLikeLoopC;

          _nextCuriousC = null;
          _nextLikeC = null;
          _nextLikeLoopC = null;

          _ready = true;

          // like 종료 감지: (1) 리스너 + slack, (2) 보조 타임아웃
          _likeEndListener = () {
            final v = _likeC?.value;
            if (v == null || !v.isInitialized) return;

            final dur = v.duration;
            final pos = v.position;

            // 일부 플랫폼에서 isPlaying 이 끝 직전에 true 유지되는 경우가 있어 pos 기준으로만 판정
            final bool reachedEnd =
                dur > Duration.zero && (dur - pos) <= _kEndSlack;

            if (reachedEnd && _active == _ActiveLayer.like) {
              _switchActive(_ActiveLayer.likeLoop);
            }
          };
          _likeC!.addListener(_likeEndListener!);

          // 5) 점프 레이어로 전환(재생 포함)
          _switchActive(jumpTo);

          // 6) 기존 세트 정리
          _disposeSet(oldCur, oldLike, oldLoop);

          if (mounted) setState(() {});
        });

    return _initFuture!;
  }

  Future<void> _playOnly(VideoPlayerController? target) async {
    if (target == null) return;
    final all = <VideoPlayerController?>[_curiousC, _likeC, _likeLoopC];
    for (final c in all) {
      if (c == null) continue;
      if (c == target) {
        // ✅ 타깃은 항상 0초부터 재생(플랫폼별 워밍업 상태 차단)
        if (c.value.position != Duration.zero) {
          await c.seekTo(Duration.zero);
        }
        if (!c.value.isPlaying) await c.play();
      } else {
        if (c.value.isPlaying) await c.pause();
        if (c.value.position != Duration.zero) {
          await c.seekTo(Duration.zero);
        }
      }
    }
  }

  void _armLikeTimeout() {
    _cancelLikeTimer();
    final likeV = _likeC?.value;
    if (likeV == null || !likeV.isInitialized) return;

    // duration 기반 보조 타임아웃(여유 슬랙 포함)
    final dur = likeV.duration;
    if (dur <= Duration.zero) return;

    final timeout = dur - _kEndSlack;
    final fireAfter = timeout.isNegative ? Duration.zero : timeout;

    _likeEndTimer = Timer(fireAfter, () {
      // 여전히 like 레이어면 강제 전환
      if (!mounted) return;
      if (_active == _ActiveLayer.like) {
        _switchActive(_ActiveLayer.likeLoop);
      }
    });
  }

  void _switchActive(_ActiveLayer layer) async {
    _active = layer;
    if (!mounted || !_ready) {
      setState(() {});
      return;
    }

    switch (layer) {
      case _ActiveLayer.curious:
        _cancelLikeTimer();
        await _playOnly(_curiousC);
        break;

      case _ActiveLayer.like:
        await _playOnly(_likeC);
        // ✅ like 시작 시 타임아웃 무장(윈도우 등 엔드 이벤트 부정확 보정)
        _armLikeTimeout();
        break;

      case _ActiveLayer.likeLoop:
        _cancelLikeTimer();
        await _playOnly(_likeLoopC);
        break;
    }
    if (mounted) setState(() {});
  }

  void _replayShine() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shine.replay();
    });
  }

  @override
  Widget build(BuildContext context) {
    const baseW = 1920.0, baseH = 1080.0;
    final sz = MediaQuery.of(context).size;
    final scale = (sz.width / baseW).clamp(0.0, sz.height / baseH);
    final canvas = Size(baseW * scale, baseH * scale);
    final left = (sz.width - canvas.width) / 2;
    final top = (sz.height - canvas.height) / 2;

    Widget videoBox(VideoPlayerController? c) {
      if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      );
    }

    final ready =
        _ready &&
        _curiousC?.value.isInitialized == true &&
        _likeC?.value.isInitialized == true &&
        _likeLoopC?.value.isInitialized == true &&
        _trayImage != null &&
        _wholeImage != null &&
        _sliceImage != null &&
        (_bgImage is AssetImage);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onCanvasTap,
      child: Stack(
        children: [
          // BG
          if (ready)
            Positioned.fill(
              child: Image(image: _bgImage, fit: BoxFit.cover),
            )
          else
            const Positioned.fill(child: ColoredBox(color: Colors.black)),

          if (!ready)
            const Center(child: CircularProgressIndicator())
          else ...[
            // like_loop(하단) → like(중단) → curious(상단)
            Positioned.fromRect(
              rect: Rect.fromLTWH(left, top, canvas.width, canvas.height),
              child: Visibility(
                visible: _active == _ActiveLayer.likeLoop,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: videoBox(_likeLoopC),
              ),
            ),
            Positioned.fromRect(
              rect: Rect.fromLTWH(left, top, canvas.width, canvas.height),
              child: Visibility(
                visible: _active == _ActiveLayer.like,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: videoBox(_likeC),
              ),
            ),
            Positioned.fromRect(
              rect: Rect.fromLTWH(left, top, canvas.width, canvas.height),
              child: Visibility(
                visible: _active == _ActiveLayer.curious,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: videoBox(_curiousC),
              ),
            ),
          ],

          // 트레이
          if (ready)
            Positioned.fill(
              child: Image(image: _trayImage!, fit: BoxFit.cover),
            ),

          // 샤인 + 과일
          if (ready)
            ShineEmphasis(
              controller: _shine,
              imagePath: widget.isSlice
                  ? learnHalfPath(widget.fruit)
                  : learnNormalPath(widget.fruit),
              framesBasePath: 'assets/images/effects/shine_seq/shine_',
              frameDigits: 3,
              frameCount: 4,
              fps: 12,
              shineLoops: 3,
              fxDuration: const Duration(milliseconds: 900),
              autoplay: true,
            ),
        ],
      ),
    );
  }
}
