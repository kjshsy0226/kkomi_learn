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
  final bool isSlice;        // false: whole, true: slice
  final bool isLikeVideo;    // false: curious, true: like(끝나면 like_loop)
  final VoidCallback onCanvasTap;

  @override
  FruitPlayStageState createState() => FruitPlayStageState();
}

class FruitPlayStageState extends State<FruitPlayStage> {
  // ── 엔드 감지 여유(플랫폼별 position/duration 엣지 보정)
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

  // ---------- 외부에서 전환 직전에 호출: 즉시 정지→0초→해제 ----------
  Future<void> haltAndRelease() async {
    _cancelLikeTimer();
    _removeLikeListener();

    // 즉시 정지 & 0초로 이동
    for (final c in <VideoPlayerController?>[_curiousC, _likeC, _likeLoopC]) {
      try {
        await c?.pause();
        await c?.seekTo(Duration.zero);
      } catch (_) {}
    }

    // 화면에서 더 이상 그리지 않도록 내려두기
    _ready = false;
    _active = _ActiveLayer.curious;
    if (mounted) setState(() {});

    // 완전 해제
    await _disposeSet(_curiousC, _likeC, _likeLoopC);
    _curiousC = null;
    _likeC = null;
    _likeLoopC = null;

    // 다음 세트 준비물도 정리
    await _disposeSet(_nextCuriousC, _nextLikeC, _nextLikeLoopC);
    _nextCuriousC = null;
    _nextLikeC = null;
    _nextLikeLoopC = null;
  }

  // ---------- lifecycle ----------
  @override
  void initState() {
    super.initState();
    _replayShine();
  }

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
  void didUpdateWidget(covariant FruitPlayStage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ 과일 변경: 즉시 종료 → 새로 준비 (잔프레임 원천 차단)
    if (oldWidget.fruit != widget.fruit) {
      _swappingSet = true;
      unawaited(haltAndRelease().then((_) async {
        await _prepareSetAndImages(
          widget.fruit,
          jumpTo: widget.isLikeVideo ? _ActiveLayer.like : _ActiveLayer.curious,
        );
        _swappingSet = false;
      }));
      return;
    }

    // 같은 과일 내 curious ↔ like 전환만 처리 (스왑 중이면 무시)
    if (!_swappingSet && oldWidget.isLikeVideo != widget.isLikeVideo && _ready) {
      _switchActive(widget.isLikeVideo ? _ActiveLayer.like : _ActiveLayer.curious);
    }

    // 시각(whole/slice) 변경 시 샤인 재생
    if (oldWidget.isSlice != widget.isSlice) {
      _replayShine();
    }
  }

  @override
  void dispose() {
    _cancelLikeTimer();
    _removeLikeListener();
    unawaited(_disposeSet(_curiousC, _likeC, _likeLoopC));
    unawaited(_disposeSet(_nextCuriousC, _nextLikeC, _nextLikeLoopC));
    super.dispose();
  }

  // ───────── images: precache helpers ─────────
  Future<void> _precacheFruitImages(BuildContext ctx, LearnFruit f) async {
    final bg    = AssetImage(learnbackgroundPath(f));
    final tray  = AssetImage(learnTrayPath(f));
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

  // ───────── videos: lifecycle helpers ─────────
  Future<void> _disposeSet(
    VideoPlayerController? a,
    VideoPlayerController? b,
    VideoPlayerController? c,
  ) async {
    Future<void> safeDispose(VideoPlayerController? x) async {
      if (x == null) return;
      try {
        await x.dispose();
      } catch (_) {}
    }

    await Future.wait([
      safeDispose(a),
      safeDispose(b),
      safeDispose(c),
    ]);
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
    // 1) 이미지 선로딩
    await _precacheFruitImages(context, f);

    // 2) 다음 비디오 컨트롤러 생성
    await _disposeSet(_nextCuriousC, _nextLikeC, _nextLikeLoopC);
    _nextCuriousC   = VideoPlayerController.asset(learnCuriousVideo(f))..setLooping(true);
    _nextLikeC      = VideoPlayerController.asset(learnLikeVideo(f))..setLooping(false);
    _nextLikeLoopC  = VideoPlayerController.asset(learnLikeLoopVideo(f))..setLooping(true);

    // 3) initialize + 워밍업
    _initFuture = Future.wait([
      _nextCuriousC!.initialize(),
      _nextLikeC!.initialize(),
      _nextLikeLoopC!.initialize(),
    ]).then((_) async {
      if (!mounted) return;

      // 워밍업(첫 프레임/디코더 깨우기)
      await _nextCuriousC!.play();   await _nextCuriousC!.pause();   await _nextCuriousC!.seekTo(Duration.zero);
      await _nextLikeC!.play();      await _nextLikeC!.pause();      await _nextLikeC!.seekTo(Duration.zero);
      await _nextLikeLoopC!.play();  await _nextLikeLoopC!.pause();  await _nextLikeLoopC!.seekTo(Duration.zero);

      // 4) 새 세트 장착
      _curiousC   = _nextCuriousC;   _nextCuriousC = null;
      _likeC      = _nextLikeC;      _nextLikeC = null;
      _likeLoopC  = _nextLikeLoopC;  _nextLikeLoopC = null;

      _ready = true;

      // like 종료 감지(리스너 + slack)
      _likeEndListener = () {
        final v = _likeC?.value;
        if (v == null || !v.isInitialized) return;

        final dur = v.duration;
        final pos = v.position;
        final bool reachedEnd = dur > Duration.zero && (dur - pos) <= _kEndSlack;

        if (reachedEnd && _active == _ActiveLayer.like) {
          _switchActive(_ActiveLayer.likeLoop);
        }
      };
      _likeC!.addListener(_likeEndListener!);

      // 5) 목표 레이어로 전환(재생 포함)
      _switchActive(jumpTo);
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

    final dur = likeV.duration;
    if (dur <= Duration.zero) return;

    final timeout = dur - _kEndSlack;
    final fireAfter = timeout.isNegative ? Duration.zero : timeout;

    _likeEndTimer = Timer(fireAfter, () {
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
        _armLikeTimeout(); // 종료 타임아웃 무장
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
      // UniqueKey로 텍스처 재사용에 따른 드문 잔상 방지
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          key: UniqueKey(),
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
            const Positioned.fill(child: ColoredBox(color: Colors.white)), // 배경 레이어가 실제 배경 이미지 위층을 덮지 않게 조정하고 싶다면 수정
          if (ready)
            Positioned.fill(child: Image(image: _bgImage, fit: BoxFit.cover))
          else
            const Positioned.fill(child: ColoredBox(color: Colors.white)),

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
            Positioned.fill(child: Image(image: _trayImage!, fit: BoxFit.cover)),

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

enum _ActiveLayer { curious, like, likeLoop }
